-- S04 caregiver practice query pack
-- 只查询 coarse-grained diagnostics：role-level actor attribution、safe activity route args、projection freshness、invite/download bridge。
-- 不要在这里扩展 child name、installationId、sessionId、raw interaction payload、provider raw output。

-- 1) 最近 practice 真相源事件（append-only interaction_events，只保留 role-level 归因）
select ie.client_timestamp,
       hm.household_id,
       hm.role as actor_role,
       ie.space_id,
       ie.activity_id,
       ie.reaction_type,
       ie.received_at
from interaction_events ie
join household_members hm
  on hm.account_id = ie.account_id
 and hm.status = 'active'
order by ie.client_timestamp desc
limit 50;

-- 2) household 级 practice 概览（证明 interaction_events 仍是原始事实来源）
select hm.household_id,
       count(*) as total_events,
       count(distinct ie.account_id) as actor_count,
       count(distinct ie.installation_id) as installation_count,
       max(ie.client_timestamp) as latest_event_at,
       min(ie.client_timestamp) as first_event_at
from interaction_events ie
join household_members hm
  on hm.account_id = ie.account_id
 and hm.status = 'active'
group by hm.household_id
order by latest_event_at desc;

-- 3) role + activity 聚合（谁在做什么，只保留角色级 attribution）
select hm.role as actor_role,
       ie.space_id,
       ie.activity_id,
       ie.reaction_type,
       count(*) as total_events,
       max(ie.client_timestamp) as latest_event_at
from interaction_events ie
join household_members hm
  on hm.account_id = ie.account_id
 and hm.status = 'active'
group by hm.role, ie.space_id, ie.activity_id, ie.reaction_type
order by latest_event_at desc, total_events desc;

-- 4) household_shared_context 当前投影（结构化 actor / next-step + safe route args）
select household_id,
       latest_actor_role,
       latest_actor_source,
       latest_actor_result,
       space_id,
       activity_id,
       next_step_space_id,
       next_step_activity_id,
       next_step_reason,
       latest_interaction_at,
       updated_at,
       baby_profile_summary,
       continuity_summary,
       garden_summary
from household_shared_context
order by updated_at desc;

-- 5) projection freshness 审计（找出 stale / missing projection）
with latest_household_events as (
    select hm.household_id,
           max(ie.client_timestamp) as latest_event_at,
           count(*) as total_events
    from interaction_events ie
    join household_members hm
      on hm.account_id = ie.account_id
     and hm.status = 'active'
    group by hm.household_id
)
select e.household_id,
       e.total_events,
       e.latest_event_at,
       hsc.latest_interaction_at as projection_latest_interaction_at,
       hsc.updated_at as projection_updated_at,
       case
           when hsc.household_id is null then 'projection_missing'
           when e.latest_event_at > hsc.latest_interaction_at then 'projection_stale'
           else 'projection_in_sync'
       end as projection_state
from latest_household_events e
left join household_shared_context hsc on hsc.household_id = e.household_id
order by e.latest_event_at desc;

-- 6) projection contract gaps（shared actor / next-step 何处 malformed）
select household_id,
       case
           when latest_actor_role is null then 'actor_missing'
           when latest_actor_role not in ('primary_caregiver', 'caregiver') then 'actor_unknown'
           when next_step_space_id is null or next_step_activity_id is null then 'next_step_missing'
           else 'contract_ready'
       end as contract_state,
       latest_actor_role,
       next_step_reason,
       updated_at
from household_shared_context
order by updated_at desc;

-- 7) caregiver invite 审计漏斗（create / accept / shared_context / download）
select entrypoint,
       coalesce(source, 'unknown') as source,
       coalesce(platform, 'unknown') as platform,
       result,
       coalesce(failure_reason, 'none') as failure_reason,
       count(*) as total,
       max(created_at) as latest_seen_at
from caregiver_invite_events
where entrypoint in ('create', 'accept', 'shared_context', 'download')
group by entrypoint, coalesce(source, 'unknown'), coalesce(platform, 'unknown'), result, coalesce(failure_reason, 'none')
order by latest_seen_at desc, entrypoint, result;

-- 8) 单 token 时间线（将 :token_lookup_ref 替换成应用生成的 HMAC lookup ref；禁止填 raw token）
select created_at,
       entrypoint,
       source,
       requested_role,
       platform,
       result,
       failure_reason
from caregiver_invite_events
where token = :token_lookup_ref
order by created_at asc;

-- 9) 单 token 当前 invite 状态（将 :token_lookup_ref 替换成应用生成的 HMAC lookup ref；禁止填 raw token）
select token,
       status,
       target_role,
       source,
       created_at,
       expires_at,
       accepted_at,
       revoked_at,
       failure_reason
from caregiver_invites
where token = :token_lookup_ref;

-- 10) invite download fallback 是否继续承接到 S01 public distribution surface
select event_id,
       created_at,
       entrypoint,
       release_channel,
       source,
       platform,
       result,
       failure_reason
from release_distribution_events
where source = 'caregiver_invite'
order by event_id desc
limit 50;

-- 11) invite download_fallback ↔ S01 distribution bridge 对照（按平台做 coarse-grained bridge）
with invite_download as (
    select platform,
           count(*) as invite_downloads,
           min(created_at) as invite_first_seen_at,
           max(created_at) as invite_last_seen_at
    from caregiver_invite_events
    where entrypoint = 'download'
      and result = 'download_fallback'
    group by platform
),
distribution_download as (
    select platform,
           count(*) as distribution_hits,
           min(created_at) as distribution_first_seen_at,
           max(created_at) as distribution_last_seen_at
    from release_distribution_events
    where source = 'caregiver_invite'
    group by platform
)
select coalesce(i.platform, d.platform, 'unknown') as platform,
       coalesce(i.invite_downloads, 0) as invite_downloads,
       coalesce(d.distribution_hits, 0) as distribution_hits,
       i.invite_first_seen_at,
       i.invite_last_seen_at,
       d.distribution_first_seen_at,
       d.distribution_last_seen_at
from invite_download i
full outer join distribution_download d on d.platform = i.platform
order by platform;

-- 12) shared_context API / projector 最近是否真正刷新
select household_id,
       updated_at,
       latest_interaction_at,
       case
           when updated_at < latest_interaction_at then 'updated_before_latest_interaction'
           when updated_at >= latest_interaction_at then 'refresh_visible'
           else 'unknown'
       end as refresh_visibility
from household_shared_context
order by updated_at desc;
