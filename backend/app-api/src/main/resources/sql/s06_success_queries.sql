-- S06 continuity / mentor / retention proof pack
-- 仅复用现有表：interaction_events / consent_audit_logs / mentor_audit_logs / mentor_turns
-- 口径说明见 docs/runbooks/s06-success-metrics.md

-- ============================================================
-- 0) First-practice cohort 基表
-- ============================================================
with first_practice as (
    select installation_id,
           min(client_timestamp) as first_practice_at
    from interaction_events
    group by installation_id
)
select installation_id,
       first_practice_at,
       cast(first_practice_at as date) as cohort_day
from first_practice
order by first_practice_at desc;

-- ============================================================
-- 0b) Recent continuity diagnostics
-- SQL 看最近一次 activity_id；UI 应映射到：
--   home-start-practice-<activityId>
--   garden-continue-target-<activityId>
-- ============================================================
with ranked_recent_activity as (
    select installation_id,
           activity_id,
           client_timestamp,
           row_number() over (
               partition by installation_id
               order by client_timestamp desc, activity_id asc
           ) as row_number_in_installation
    from interaction_events
)
select installation_id,
       activity_id as recent_activity_id,
       client_timestamp as recent_activity_at,
       cast(client_timestamp as date) as recent_activity_day
from ranked_recent_activity
where row_number_in_installation = 1
order by recent_activity_at desc;

-- ============================================================
-- 1) D1 / D7 / D30 retention（practice-first cohort）
-- retained_rate_d1_pct / retained_rate_d7_pct / retained_rate_d30_pct
-- ============================================================
with first_practice as (
    select installation_id,
           min(client_timestamp) as first_practice_at
    from interaction_events
    group by installation_id
),
retention_flags as (
    select fp.installation_id,
           cast(fp.first_practice_at as date) as cohort_day,
           case when exists (
               select 1
               from interaction_events e
               where e.installation_id = fp.installation_id
                 and e.client_timestamp >= fp.first_practice_at + interval '1 day'
                 and e.client_timestamp <  fp.first_practice_at + interval '2 day'
           ) then 1 else 0 end as retained_d1,
           case when exists (
               select 1
               from interaction_events e
               where e.installation_id = fp.installation_id
                 and e.client_timestamp >= fp.first_practice_at + interval '7 day'
                 and e.client_timestamp <  fp.first_practice_at + interval '8 day'
           ) then 1 else 0 end as retained_d7,
           case when exists (
               select 1
               from interaction_events e
               where e.installation_id = fp.installation_id
                 and e.client_timestamp >= fp.first_practice_at + interval '30 day'
                 and e.client_timestamp <  fp.first_practice_at + interval '31 day'
           ) then 1 else 0 end as retained_d30
    from first_practice fp
)
select cohort_day,
       count(*) as cohort_size,
       sum(retained_d1) as retained_users_d1,
       round(100.0 * sum(retained_d1) / nullif(count(*), 0), 2) as retained_rate_d1_pct,
       sum(retained_d7) as retained_users_d7,
       round(100.0 * sum(retained_d7) / nullif(count(*), 0), 2) as retained_rate_d7_pct,
       sum(retained_d30) as retained_users_d30,
       round(100.0 * sum(retained_d30) / nullif(count(*), 0), 2) as retained_rate_d30_pct
from retention_flags
group by cohort_day
order by cohort_day desc;

-- ============================================================
-- 2) Sync activation：first practice 后 24h 内完成 consent accept
-- ============================================================
with first_practice as (
    select installation_id,
           min(client_timestamp) as first_practice_at
    from interaction_events
    group by installation_id
),
activation_flags as (
    select fp.installation_id,
           cast(fp.first_practice_at as date) as cohort_day,
           case when exists (
               select 1
               from consent_audit_logs cal
               where cal.installation_id = fp.installation_id
                 and cal.action = 'accept'
                 and cal.result = 'applied'
                 and cal.created_at >= fp.first_practice_at
                 and cal.created_at <  fp.first_practice_at + interval '1 day'
           ) then 1 else 0 end as activated_sync
    from first_practice fp
)
select cohort_day,
       count(*) as cohort_size,
       sum(activated_sync) as activated_sync_users,
       round(100.0 * sum(activated_sync) / nullif(count(*), 0), 2) as activated_sync_rate_pct
from activation_flags
group by cohort_day
order by cohort_day desc;

-- ============================================================
-- 3) Consent 审计总览（accept / revoke / delete）
-- ============================================================
select cast(created_at as date) as audit_day,
       action,
       result,
       count(*) as audit_count
from consent_audit_logs
group by cast(created_at as date), action, result
order by audit_day desc, action, result;

-- ============================================================
-- 4) Mentor help usage：Activated-sync cohort 中 7 天内至少一次 chat_requested
-- ============================================================
with first_practice as (
    select installation_id,
           min(client_timestamp) as first_practice_at
    from interaction_events
    group by installation_id
),
activated_sync as (
    select fp.installation_id,
           fp.first_practice_at
    from first_practice fp
    where exists (
        select 1
        from consent_audit_logs cal
        where cal.installation_id = fp.installation_id
          and cal.action = 'accept'
          and cal.result = 'applied'
          and cal.created_at >= fp.first_practice_at
          and cal.created_at <  fp.first_practice_at + interval '1 day'
    )
),
help_usage as (
    select a.installation_id,
           cast(a.first_practice_at as date) as cohort_day,
           case when exists (
               select 1
               from mentor_audit_logs mal
               where mal.installation_id = a.installation_id
                 and mal.event_type = 'chat_requested'
                 and mal.created_at >= a.first_practice_at
                 and mal.created_at <  a.first_practice_at + interval '7 day'
           ) then 1 else 0 end as used_help_within_7d
    from activated_sync a
)
select cohort_day,
       count(*) as activated_sync_cohort_size,
       sum(used_help_within_7d) as help_users_7d,
       round(100.0 * sum(used_help_within_7d) / nullif(count(*), 0), 2) as help_usage_rate_7d_pct
from help_usage
group by cohort_day
order by cohort_day desc;

-- ============================================================
-- 5) Mentor delivery rate：success + fallback 都算 delivered
-- mentor_delivery_rate_pct 是主要聚合口径
-- ============================================================
with requested as (
    select correlation_id,
           installation_id,
           min(created_at) as requested_at
    from mentor_audit_logs
    where event_type = 'chat_requested'
    group by correlation_id, installation_id
),
delivered as (
    select correlation_id,
           installation_id,
           min(created_at) as delivered_at
    from mentor_turns
    where result in ('success', 'fallback')
    group by correlation_id, installation_id
)
select cast(r.requested_at as date) as request_day,
       count(*) as mentor_requests,
       count(d.correlation_id) as delivered_requests,
       round(100.0 * count(d.correlation_id) / nullif(count(*), 0), 2) as mentor_delivery_rate_pct
from requested r
left join delivered d
  on d.correlation_id = r.correlation_id
 and d.installation_id = r.installation_id
group by cast(r.requested_at as date)
order by request_day desc;

-- ============================================================
-- 6) Mentor failure / fallback breakdown
-- timeout / malformed / rate limit / blocked_fallback 的高层审计入口
-- ============================================================
select cast(created_at as date) as audit_day,
       coalesce(failure_code, phase) as outcome,
       rate_limited,
       retryable,
       count(*) as event_count
from mentor_audit_logs
where event_type <> 'chat_requested'
group by cast(created_at as date), coalesce(failure_code, phase), rate_limited, retryable
order by audit_day desc, outcome;

-- ============================================================
-- 7) blocked_fallback 可见性
-- 这里证明 blocked 请求最终仍形成可交付 fallback，而不是静默失败
-- ============================================================
select cast(created_at as date) as created_day,
       result,
       phase,
       blocked_fallback,
       count(*) as turn_count
from mentor_turns
where phase = 'blocked_fallback'
group by cast(created_at as date), result, phase, blocked_fallback
order by created_day desc;

-- ============================================================
-- 8) 单 installation 诊断：practice + consent + mentor audit + mentor turns timeline
-- 将 :installation_id 替换成目标 installation
-- ============================================================
select 'interaction_events' as source,
       installation_id,
       client_timestamp as happened_at,
       activity_id as detail_a,
       phrase_id as detail_b,
       reaction_type as detail_c
from interaction_events
where installation_id = :installation_id

union all

select 'consent_audit_logs' as source,
       installation_id,
       created_at as happened_at,
       action as detail_a,
       result as detail_b,
       coalesce(reason, '-') as detail_c
from consent_audit_logs
where installation_id = :installation_id

union all

select 'mentor_audit_logs' as source,
       installation_id,
       created_at as happened_at,
       event_type as detail_a,
       phase as detail_b,
       coalesce(failure_code, '-') as detail_c
from mentor_audit_logs
where installation_id = :installation_id

union all

select 'mentor_turns' as source,
       installation_id,
       created_at as happened_at,
       result as detail_a,
       phase as detail_b,
       case when blocked_fallback then 'blocked_fallback' else coalesce(correlation_id, '-') end as detail_c
from mentor_turns
where installation_id = :installation_id

order by happened_at asc;
