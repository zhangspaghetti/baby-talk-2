-- S02 growth share proof pack
-- 只复用现有表：share_landing_events、release_distribution_events
-- 口径说明见 docs/runbooks/s02-growth-share.md
-- redaction 边界：只允许 token / source / entrypoint / platform / result / failure_reason / release_channel / created_at
-- 当前 schema 不含 installation/account/child/eventKey/fallbackReason；不要 invent 新列或 join PII 表

-- ============================================================
-- 0) 最近 share 事件明细
-- 用于快速确认最近是否真的有 create / landing / open_app / download 命中，以及最近失败面是什么
-- ============================================================
select event_id,
       created_at,
       token,
       source,
       entrypoint,
       platform,
       result,
       failure_reason
from share_landing_events
order by created_at desc, event_id desc
limit 200;

-- ============================================================
-- 1) 日维度 share result 总览
-- 回答：最近每天 create / page_view / open_app_redirect / download_fallback / invalid / expired / unavailable 各有多少
-- ============================================================
select cast(created_at as date) as event_day,
       entrypoint,
       result,
       count(*) as event_count
from share_landing_events
group by cast(created_at as date), entrypoint, result
order by event_day desc, entrypoint, result;

-- ============================================================
-- 2) source + platform + result 聚合
-- 回答：哪个 source / platform 被访问最多，哪里失败最多
-- ============================================================
select coalesce(source, 'unknown') as source,
       coalesce(platform, 'unknown') as platform,
       entrypoint,
       result,
       coalesce(failure_reason, '-') as failure_reason,
       count(*) as event_count,
       min(created_at) as first_seen_at,
       max(created_at) as last_seen_at
from share_landing_events
group by coalesce(source, 'unknown'), coalesce(platform, 'unknown'), entrypoint, result, coalesce(failure_reason, '-')
order by last_seen_at desc, source, platform, entrypoint, result, failure_reason;

-- ============================================================
-- 3) share entrypoint 漏斗概览
-- 回答：create 后 landing / open_app / download 哪一段最容易断
-- success 口径：create / page_view / open_app_redirect / download_fallback
-- ============================================================
select entrypoint,
       count(*) as total_events,
       sum(case when result in ('create', 'page_view', 'open_app_redirect', 'download_fallback') then 1 else 0 end) as successful_events,
       sum(case when result not in ('create', 'page_view', 'open_app_redirect', 'download_fallback') then 1 else 0 end) as failure_events,
       round(
           100.0 * sum(case when result in ('create', 'page_view', 'open_app_redirect', 'download_fallback') then 1 else 0 end) / nullif(count(*), 0),
           2
       ) as success_rate_pct,
       max(created_at) as last_seen_at
from share_landing_events
group by entrypoint
order by last_seen_at desc, entrypoint;

-- ============================================================
-- 4) 单 token 时间线（root-cause 用）
-- 回答：同一 token 是否多次 landing、多次 open_app、或多次 download_fallback
-- 将 :token 替换成目标 token
-- ============================================================
select event_id,
       created_at,
       token,
       source,
       entrypoint,
       platform,
       result,
       failure_reason
from share_landing_events
where token = :token
order by created_at asc, event_id asc;

-- ============================================================
-- 5) invalid / expired / unavailable 热点
-- 回答：失败是否集中在 token_not_found / token_expired / platform_target_missing / download_fallback_unconfigured / storage_unavailable
-- ============================================================
select cast(created_at as date) as event_day,
       result,
       coalesce(failure_reason, '-') as failure_reason,
       count(*) as event_count
from share_landing_events
where result in ('invalid', 'expired', 'unavailable')
group by cast(created_at as date), result, coalesce(failure_reason, '-')
order by event_day desc, event_count desc, result, failure_reason;

-- ============================================================
-- 6) source 视角：create / landing / open_app / download 拆分
-- 回答：某个 source 是 create 多、还是 page_view/open_app/download_fallback 少
-- ============================================================
select coalesce(source, 'unknown') as source,
       entrypoint,
       result,
       count(*) as event_count,
       min(created_at) as first_seen_at,
       max(created_at) as last_seen_at
from share_landing_events
group by coalesce(source, 'unknown'), entrypoint, result
order by last_seen_at desc, source, entrypoint, result;

-- ============================================================
-- 7) release fallback 承接面（只看 source=share_card）
-- 回答：S01 public distribution 是否真的承接了 share download fallback
-- ============================================================
select release_channel,
       source,
       coalesce(platform, 'unknown') as platform,
       entrypoint,
       result,
       coalesce(failure_reason, '-') as failure_reason,
       count(*) as event_count,
       min(created_at) as first_seen_at,
       max(created_at) as last_seen_at
from release_distribution_events
where source = 'share_card'
group by release_channel, source, coalesce(platform, 'unknown'), entrypoint, result, coalesce(failure_reason, '-')
order by last_seen_at desc, release_channel, platform, entrypoint, result, failure_reason;

-- ============================================================
-- 8) share ↔ release bridge 对照（日维度）
-- 回答：share 侧 download_fallback 有多少，release 侧 share_card 承接有多少；是否出现明显断层
-- ============================================================
with share_download as (
    select cast(created_at as date) as event_day,
           coalesce(platform, 'unknown') as platform,
           count(*) as share_download_fallback_count
    from share_landing_events
    where entrypoint = 'download'
      and result = 'download_fallback'
    group by cast(created_at as date), coalesce(platform, 'unknown')
),
release_share_card as (
    select cast(created_at as date) as event_day,
           coalesce(platform, 'unknown') as platform,
           count(*) as release_share_card_count
    from release_distribution_events
    where source = 'share_card'
    group by cast(created_at as date), coalesce(platform, 'unknown')
)
select coalesce(sd.event_day, rd.event_day) as event_day,
       coalesce(sd.platform, rd.platform) as platform,
       coalesce(sd.share_download_fallback_count, 0) as share_download_fallback_count,
       coalesce(rd.release_share_card_count, 0) as release_share_card_count,
       coalesce(rd.release_share_card_count, 0) - coalesce(sd.share_download_fallback_count, 0) as release_minus_share
from share_download sd
full outer join release_share_card rd
  on sd.event_day = rd.event_day
 and sd.platform = rd.platform
order by event_day desc, platform;

-- ============================================================
-- 9) share ↔ release bridge 对照（最近 200 条）
-- 回答：最近一次 share download_fallback 之后，release_distribution_events(source=share_card) 有没有按平台承接
-- 注意：当前 redaction 边界下只能按 platform + created_at 时间窗做 coarse-grained 对照，不能按 installation/account/token 串联
-- ============================================================
with recent_share_download as (
    select created_at,
           token,
           coalesce(platform, 'unknown') as platform,
           result,
           failure_reason
    from share_landing_events
    where entrypoint = 'download'
    order by created_at desc
    limit 200
),
recent_release_share_card as (
    select created_at,
           release_channel,
           coalesce(platform, 'unknown') as platform,
           entrypoint,
           result,
           failure_reason
    from release_distribution_events
    where source = 'share_card'
    order by created_at desc
    limit 200
)
select 'share_download' as surface,
       created_at,
       token as token_or_channel,
       platform,
       result,
       failure_reason
from recent_share_download
union all
select 'release_share_card' as surface,
       created_at,
       release_channel as token_or_channel,
       platform,
       result,
       failure_reason
from recent_release_share_card
order by created_at desc, surface;
