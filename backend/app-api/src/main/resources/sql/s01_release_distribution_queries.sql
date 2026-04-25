-- S01 release distribution proof pack
-- 只复用现有表：release_distribution_events
-- 口径说明见 docs/runbooks/s01-release-distribution.md
-- redaction 边界：仅允许 entrypoint / release_channel / source / platform / result / failure_reason / created_at
-- 当前 schema 不含 installation/account/session；不要 invent 新列或 join PII 表

-- ============================================================
-- 0) 最近事件明细
-- 用于快速确认最近是否真的有 /download / /upgrade 命中，以及最近失败面是什么
-- ============================================================
select event_id,
       created_at,
       entrypoint,
       release_channel,
       source,
       platform,
       result,
       failure_reason
from release_distribution_events
order by created_at desc, event_id desc
limit 200;

-- ============================================================
-- 1) 日维度总览
-- 回答：最近每天 /download 与 /upgrade 各有多少 page_view / redirect / unavailable / invalid_*
-- ============================================================
select cast(created_at as date) as event_day,
       entrypoint,
       result,
       count(*) as event_count
from release_distribution_events
group by cast(created_at as date), entrypoint, result
order by event_day desc, entrypoint, result;

-- ============================================================
-- 2) release_channel + source + result 聚合
-- 回答：哪个 channel/source 被访问，哪里失败，是否有 upgrade 命中
-- ============================================================
select release_channel,
       source,
       entrypoint,
       result,
       count(*) as event_count,
       min(created_at) as first_seen_at,
       max(created_at) as last_seen_at
from release_distribution_events
group by release_channel, source, entrypoint, result
order by last_seen_at desc, release_channel, source, entrypoint, result;

-- ============================================================
-- 3) platform + result + failure_reason 聚合
-- 回答：Android / iOS 或未知平台在哪类失败上更集中
-- ============================================================
select coalesce(platform, 'unknown') as platform,
       result,
       coalesce(failure_reason, '-') as failure_reason,
       count(*) as event_count,
       min(created_at) as first_seen_at,
       max(created_at) as last_seen_at
from release_distribution_events
group by coalesce(platform, 'unknown'), result, coalesce(failure_reason, '-')
order by last_seen_at desc, platform, result, failure_reason;

-- ============================================================
-- 4) upgrade 命中聚合
-- 回答：426 / version gate 是否真的进入 /upgrade，以及后续结果是什么
-- ============================================================
select release_channel,
       source,
       coalesce(platform, 'unknown') as platform,
       result,
       coalesce(failure_reason, '-') as failure_reason,
       count(*) as upgrade_event_count,
       max(created_at) as last_upgrade_event_at
from release_distribution_events
where entrypoint = 'upgrade'
group by release_channel, source, coalesce(platform, 'unknown'), result, coalesce(failure_reason, '-')
order by last_upgrade_event_at desc, release_channel, source, platform, result;

-- ============================================================
-- 5) 下载入口命中聚合
-- 回答：公开直达 /download 是否有 page_view / redirect，以及 public_link 的失败面
-- ============================================================
select release_channel,
       source,
       coalesce(platform, 'unknown') as platform,
       result,
       coalesce(failure_reason, '-') as failure_reason,
       count(*) as download_event_count,
       max(created_at) as last_download_event_at
from release_distribution_events
where entrypoint = 'download'
group by release_channel, source, coalesce(platform, 'unknown'), result, coalesce(failure_reason, '-')
order by last_download_event_at desc, release_channel, source, platform, result;

-- ============================================================
-- 6) source 对比：public_link vs version_gate
-- 回答：公开直达与 app 内升级入口在同一 channel 下的 hit/failure 差异
-- 将 :release_channel 替换成目标渠道，例如 stable
-- ============================================================
select source,
       entrypoint,
       result,
       coalesce(failure_reason, '-') as failure_reason,
       count(*) as event_count,
       min(created_at) as first_seen_at,
       max(created_at) as last_seen_at
from release_distribution_events
where release_channel = :release_channel
group by source, entrypoint, result, coalesce(failure_reason, '-')
order by last_seen_at desc, source, entrypoint, result, failure_reason;

-- ============================================================
-- 7) 单 source 诊断时间线（root-cause 用）
-- 当前 schema 故意不含 installation_id；这里按 source + entrypoint + 时间窗诊断，而不是按设备追踪
-- 将 :source / :entrypoint 替换成目标值，例如 version_gate / upgrade
-- ============================================================
select event_id,
       created_at,
       release_channel,
       source,
       platform,
       result,
       failure_reason
from release_distribution_events
where source = :source
  and entrypoint = :entrypoint
order by created_at desc, event_id desc
limit 200;

-- ============================================================
-- 8) failure_reason 热点
-- 回答：最近哪类失败原因在增长，是否集中在 invalid_channel / invalid_source / unknown_platform / platform_target_missing
-- ============================================================
select cast(created_at as date) as event_day,
       result,
       coalesce(failure_reason, '-') as failure_reason,
       count(*) as event_count
from release_distribution_events
where failure_reason is not null
group by cast(created_at as date), result, coalesce(failure_reason, '-')
order by event_day desc, event_count desc, result, failure_reason;

-- ============================================================
-- 9) route 健康度概览
-- page_view / redirect 视为命中，unavailable / invalid_* 视为失败面
-- ============================================================
select entrypoint,
       count(*) as total_events,
       sum(case when result in ('page_view', 'redirect') then 1 else 0 end) as successful_events,
       sum(case when result not in ('page_view', 'redirect') then 1 else 0 end) as failure_events,
       round(
           100.0 * sum(case when result in ('page_view', 'redirect') then 1 else 0 end) / nullif(count(*), 0),
           2
       ) as success_rate_pct,
       max(created_at) as last_seen_at
from release_distribution_events
group by entrypoint
order by last_seen_at desc, entrypoint;
