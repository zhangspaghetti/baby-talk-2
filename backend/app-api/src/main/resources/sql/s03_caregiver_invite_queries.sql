-- S03 caregiver invite query pack
-- 只查询 coarse-grained diagnostics：token / result / source / role / platform / route-arg / household_shared_context。
-- 不要在这里扩展 child nickname、installationId、sessionId 或原始 interaction payload。

-- 1) 最近 invite 链路事件（create / landing / open-app / download / accept / revoke）
select event_id,
       created_at,
       entrypoint,
       source,
       requested_role,
       platform,
       result,
       failure_reason,
       token
from caregiver_invite_events
order by event_id desc
limit 50;

-- 2) 日维度 result 概览
select cast(created_at as date) as day,
       result,
       count(*) as total
from caregiver_invite_events
group by cast(created_at as date), result
order by day desc, result;

-- 3) source + platform + result 聚合（public traffic / fallback / failure 热点）
select coalesce(source, 'unknown') as source,
       coalesce(platform, 'unknown') as platform,
       result,
       count(*) as total
from caregiver_invite_events
group by coalesce(source, 'unknown'), coalesce(platform, 'unknown'), result
order by total desc, source, platform, result;

-- 4) entrypoint 漏斗（哪一段断了）
select entrypoint,
       result,
       count(*) as total
from caregiver_invite_events
group by entrypoint, result
order by entrypoint, result;

-- 5) 失败原因热点（invalid / expired / already_used / revoked / unavailable / role_not_allowed）
select result,
       coalesce(failure_reason, 'none') as failure_reason,
       count(*) as total
from caregiver_invite_events
where result in ('invalid', 'expired', 'already_used', 'revoked', 'unavailable', 'role_not_allowed', 'shared_context_unavailable')
group by result, coalesce(failure_reason, 'none')
order by total desc, result, failure_reason;

-- 6) 单 token 时间线（将 :token_lookup_ref 替换成应用生成的 HMAC lookup ref；禁止填 raw token）
select event_id,
       created_at,
       entrypoint,
       source,
       requested_role,
       platform,
       result,
       failure_reason
from caregiver_invite_events
where token = :token_lookup_ref
order by event_id asc;

-- 7) 当前 invite 状态快照（将 :token_lookup_ref 替换成应用生成的 HMAC lookup ref；禁止填 raw token）
select token,
       household_id,
       source,
       target_role,
       status,
       created_at,
       expires_at,
       accepted_at,
       revoked_at,
       failure_reason
from caregiver_invites
where token = :token_lookup_ref;

-- 8) household shared context 当前投影（确认 shared baby profile / continuity / garden 摘要与安全 route args）
select household_id,
       baby_profile_summary,
       continuity_summary,
       garden_summary,
       space_id,
       activity_id,
       latest_interaction_at,
       updated_at
from household_shared_context
order by updated_at desc;

-- 9) 最近 membership 快照（只看 household / role / acceptedAt，不看 account 维度 payload）
select household_id,
       role,
       status,
       joined_at,
       last_accepted_at
from household_members
order by joined_at desc
limit 50;

-- 10) invite download fallback 是否真正串到 S01 distribution surface
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

-- 11) invite download_fallback ↔ S01 distribution bridge 对照（按平台 + 时间窗做 coarse-grained bridge）
with invite_download as (
    select platform,
           count(*) as invite_downloads,
           min(created_at) as first_seen_at,
           max(created_at) as last_seen_at
    from caregiver_invite_events
    where entrypoint = 'download'
      and result = 'download_fallback'
    group by platform
),
distribution_download as (
    select platform,
           count(*) as distribution_hits,
           min(created_at) as first_seen_at,
           max(created_at) as last_seen_at
    from release_distribution_events
    where source = 'caregiver_invite'
    group by platform
)
select coalesce(i.platform, d.platform, 'unknown') as platform,
       coalesce(i.invite_downloads, 0) as invite_downloads,
       coalesce(d.distribution_hits, 0) as distribution_hits,
       i.first_seen_at as invite_first_seen_at,
       i.last_seen_at as invite_last_seen_at,
       d.first_seen_at as distribution_first_seen_at,
       d.last_seen_at as distribution_last_seen_at
from invite_download i
full outer join distribution_download d on d.platform = i.platform
order by platform;
