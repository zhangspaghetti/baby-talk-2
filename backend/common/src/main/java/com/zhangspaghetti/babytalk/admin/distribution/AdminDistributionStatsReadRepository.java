package com.zhangspaghetti.babytalk.admin.distribution;

import java.math.BigDecimal;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;

public class AdminDistributionStatsReadRepository {

    private final JdbcTemplate jdbcTemplate;

    public AdminDistributionStatsReadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public SectionSummaryRow fetchReleaseOverview(Instant windowStart, String releaseChannel) {
        var args = new ArrayList<Object>();
        var sql = new StringBuilder("""
                select count(*) as total_events,
                       coalesce(sum(case when result in ('page_view', 'redirect') then 1 else 0 end), 0) as successful_events,
                       coalesce(sum(case when result not in ('page_view', 'redirect') then 1 else 0 end), 0) as failure_events,
                       max(created_at) as last_seen_at
                from release_distribution_events
                where created_at >= ?
                """);
        args.add(toTimestamp(windowStart));
        appendReleaseChannelFilter(sql, args, releaseChannel);
        return jdbcTemplate.queryForObject(sql.toString(), this::mapSectionSummary, args.toArray());
    }

    public List<TrendRow> listReleaseTrend(Instant windowStart, String releaseChannel) {
        var args = new ArrayList<Object>();
        var sql = new StringBuilder("""
                select cast(created_at as date) as event_day,
                       entrypoint,
                       result,
                       count(*) as event_count
                from release_distribution_events
                where created_at >= ?
                """);
        args.add(toTimestamp(windowStart));
        appendReleaseChannelFilter(sql, args, releaseChannel);
        sql.append(" group by cast(created_at as date), entrypoint, result");
        sql.append(" order by event_day desc, entrypoint, result");
        return jdbcTemplate.query(sql.toString(), this::mapTrend, args.toArray());
    }

    public SectionSummaryRow fetchShareOverview(Instant windowStart) {
        return jdbcTemplate.queryForObject(
                """
                select count(*) as total_events,
                       coalesce(sum(case when result in ('create', 'page_view', 'open_app_redirect', 'download_fallback') then 1 else 0 end), 0) as successful_events,
                       coalesce(sum(case when result not in ('create', 'page_view', 'open_app_redirect', 'download_fallback') then 1 else 0 end), 0) as failure_events,
                       max(created_at) as last_seen_at
                from share_landing_events
                where created_at >= ?
                """,
                this::mapSectionSummary,
                toTimestamp(windowStart)
        );
    }

    public List<TrendRow> listShareTrend(Instant windowStart) {
        return jdbcTemplate.query(
                """
                select cast(created_at as date) as event_day,
                       entrypoint,
                       result,
                       count(*) as event_count
                from share_landing_events
                where created_at >= ?
                group by cast(created_at as date), entrypoint, result
                order by event_day desc, entrypoint, result
                """,
                this::mapTrend,
                toTimestamp(windowStart)
        );
    }

    public List<FunnelRow> listShareFunnel(Instant windowStart) {
        return jdbcTemplate.query(
                """
                select entrypoint,
                       count(*) as total_events,
                       coalesce(sum(case when result in ('create', 'page_view', 'open_app_redirect', 'download_fallback') then 1 else 0 end), 0) as successful_events,
                       coalesce(sum(case when result not in ('create', 'page_view', 'open_app_redirect', 'download_fallback') then 1 else 0 end), 0) as failure_events,
                       round(
                           100.0 * coalesce(sum(case when result in ('create', 'page_view', 'open_app_redirect', 'download_fallback') then 1 else 0 end), 0) / nullif(count(*), 0),
                           2
                       ) as success_rate_pct,
                       max(created_at) as last_seen_at
                from share_landing_events
                where created_at >= ?
                group by entrypoint
                order by last_seen_at desc, entrypoint
                """,
                this::mapFunnel,
                toTimestamp(windowStart)
        );
    }

    public HandoffSummaryRow fetchShareHandoffSummary(Instant windowStart, String releaseChannel) {
        var args = new ArrayList<Object>();
        var sql = new StringBuilder("""
                with share_side as (
                    select count(*) as total_share_download_fallback_events,
                           max(created_at) as share_last_seen_at
                    from share_landing_events
                    where created_at >= ?
                      and entrypoint = 'download'
                      and result = 'download_fallback'
                ),
                release_side as (
                    select count(*) as total_release_share_card_events,
                           max(created_at) as release_last_seen_at
                    from release_distribution_events
                    where created_at >= ?
                      and source = 'share_card'
                """);
        args.add(toTimestamp(windowStart));
        args.add(toTimestamp(windowStart));
        appendReleaseChannelFilter(sql, args, releaseChannel);
        sql.append("""
                )
                select total_share_download_fallback_events,
                       share_last_seen_at,
                       total_release_share_card_events,
                       release_last_seen_at
                from share_side
                cross join release_side
                """);
        return jdbcTemplate.queryForObject(sql.toString(), this::mapHandoffSummary, args.toArray());
    }

    public List<HandoffTrendRow> listShareHandoffTrend(Instant windowStart, String releaseChannel) {
        var args = new ArrayList<Object>();
        var sql = new StringBuilder("""
                with share_download as (
                    select cast(created_at as date) as event_day,
                           coalesce(platform, 'unknown') as platform,
                           count(*) as share_download_fallback_count
                    from share_landing_events
                    where created_at >= ?
                      and entrypoint = 'download'
                      and result = 'download_fallback'
                    group by cast(created_at as date), coalesce(platform, 'unknown')
                ),
                release_share_card as (
                    select cast(created_at as date) as event_day,
                           coalesce(platform, 'unknown') as platform,
                           count(*) as release_share_card_count
                    from release_distribution_events
                    where created_at >= ?
                      and source = 'share_card'
                """);
        args.add(toTimestamp(windowStart));
        args.add(toTimestamp(windowStart));
        appendReleaseChannelFilter(sql, args, releaseChannel);
        sql.append("""
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
                order by event_day desc, platform
                """);
        return jdbcTemplate.query(sql.toString(), this::mapHandoffTrend, args.toArray());
    }

    public List<DetailRow> listRecentDetailRows(Instant windowStart, String releaseChannel, int limit) {
        var args = new ArrayList<Object>();
        var sql = new StringBuilder("""
                with recent_release as (
                    select 'release_distribution' as surface,
                           event_id as sort_id,
                           created_at,
                           release_channel as channel,
                           source,
                           entrypoint,
                           coalesce(platform, 'unknown') as platform,
                           result,
                           failure_reason
                    from release_distribution_events
                    where created_at >= ?
                """);
        args.add(toTimestamp(windowStart));
        appendReleaseChannelFilter(sql, args, releaseChannel);
        sql.append(" order by created_at desc, event_id desc limit ?),");
        args.add(limit);
        sql.append("""
                recent_share as (
                    select 'share_landing' as surface,
                           event_id as sort_id,
                           created_at,
                           cast(null as varchar(32)) as channel,
                           coalesce(source, 'unknown') as source,
                           entrypoint,
                           coalesce(platform, 'unknown') as platform,
                           result,
                           failure_reason
                    from share_landing_events
                    where created_at >= ?
                    order by created_at desc, event_id desc
                    limit ?
                )
                select surface,
                       created_at,
                       channel,
                       source,
                       entrypoint,
                       platform,
                       result,
                       failure_reason,
                       sort_id
                from (
                    select * from recent_release
                    union all
                    select * from recent_share
                ) rows
                order by created_at desc, sort_id desc, surface
                limit ?
                """);
        args.add(toTimestamp(windowStart));
        args.add(limit);
        args.add(limit);
        return jdbcTemplate.query(sql.toString(), this::mapDetail, args.toArray());
    }

    private void appendReleaseChannelFilter(StringBuilder sql, List<Object> args, String releaseChannel) {
        if (releaseChannel == null) {
            return;
        }
        sql.append(" and release_channel = ?");
        args.add(releaseChannel);
    }

    private SectionSummaryRow mapSectionSummary(ResultSet resultSet, int rowNum) throws SQLException {
        return new SectionSummaryRow(
                resultSet.getLong("total_events"),
                resultSet.getLong("successful_events"),
                resultSet.getLong("failure_events"),
                mapInstant(resultSet.getTimestamp("last_seen_at"))
        );
    }

    private TrendRow mapTrend(ResultSet resultSet, int rowNum) throws SQLException {
        return new TrendRow(
                mapDate(resultSet.getDate("event_day")),
                resultSet.getString("entrypoint"),
                resultSet.getString("result"),
                resultSet.getLong("event_count")
        );
    }

    private FunnelRow mapFunnel(ResultSet resultSet, int rowNum) throws SQLException {
        return new FunnelRow(
                resultSet.getString("entrypoint"),
                resultSet.getLong("total_events"),
                resultSet.getLong("successful_events"),
                resultSet.getLong("failure_events"),
                resultSet.getBigDecimal("success_rate_pct"),
                mapInstant(resultSet.getTimestamp("last_seen_at"))
        );
    }

    private HandoffSummaryRow mapHandoffSummary(ResultSet resultSet, int rowNum) throws SQLException {
        return new HandoffSummaryRow(
                resultSet.getLong("total_share_download_fallback_events"),
                mapInstant(resultSet.getTimestamp("share_last_seen_at")),
                resultSet.getLong("total_release_share_card_events"),
                mapInstant(resultSet.getTimestamp("release_last_seen_at"))
        );
    }

    private HandoffTrendRow mapHandoffTrend(ResultSet resultSet, int rowNum) throws SQLException {
        return new HandoffTrendRow(
                mapDate(resultSet.getDate("event_day")),
                resultSet.getString("platform"),
                resultSet.getLong("share_download_fallback_count"),
                resultSet.getLong("release_share_card_count"),
                resultSet.getLong("release_minus_share")
        );
    }

    private DetailRow mapDetail(ResultSet resultSet, int rowNum) throws SQLException {
        return new DetailRow(
                resultSet.getString("surface"),
                mapInstant(resultSet.getTimestamp("created_at")),
                resultSet.getString("channel"),
                resultSet.getString("source"),
                resultSet.getString("entrypoint"),
                resultSet.getString("platform"),
                resultSet.getString("result"),
                resultSet.getString("failure_reason")
        );
    }

    private Timestamp toTimestamp(Instant instant) {
        return Timestamp.from(instant);
    }

    private Instant mapInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    private LocalDate mapDate(Date date) {
        return date == null ? null : date.toLocalDate();
    }

    public record SectionSummaryRow(
            long totalEvents,
            long successfulEvents,
            long failureEvents,
            Instant lastSeenAt
    ) {
    }

    public record TrendRow(
            LocalDate eventDay,
            String entrypoint,
            String result,
            long eventCount
    ) {
    }

    public record FunnelRow(
            String entrypoint,
            long totalEvents,
            long successfulEvents,
            long failureEvents,
            BigDecimal successRatePct,
            Instant lastSeenAt
    ) {
    }

    public record HandoffSummaryRow(
            long totalShareDownloadFallbackEvents,
            Instant shareLastSeenAt,
            long totalReleaseShareCardEvents,
            Instant releaseLastSeenAt
    ) {
    }

    public record HandoffTrendRow(
            LocalDate eventDay,
            String platform,
            long shareDownloadFallbackCount,
            long releaseShareCardCount,
            long releaseMinusShare
    ) {
    }

    public record DetailRow(
            String surface,
            Instant createdAt,
            String channel,
            String source,
            String entrypoint,
            String platform,
            String result,
            String failureReason
    ) {
    }
}
