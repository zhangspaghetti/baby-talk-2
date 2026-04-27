package com.zhangspaghetti.babytalk.admin.distribution;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.springframework.transaction.annotation.Transactional;

public class AdminDistributionStatsReadRepository {

    private final AdminDistributionStatsReadMapper adminDistributionStatsReadMapper;

    public AdminDistributionStatsReadRepository(AdminDistributionStatsReadMapper adminDistributionStatsReadMapper) {
        this.adminDistributionStatsReadMapper = adminDistributionStatsReadMapper;
    }

    public SectionSummaryRow fetchReleaseOverview(Instant windowStart, String releaseChannel) {
        return adminDistributionStatsReadMapper.fetchReleaseOverview(windowStart, releaseChannel);
    }

    public List<TrendRow> listReleaseTrend(Instant windowStart, String releaseChannel) {
        return adminDistributionStatsReadMapper.listReleaseTrend(windowStart, releaseChannel);
    }

    public SectionSummaryRow fetchShareOverview(Instant windowStart) {
        return adminDistributionStatsReadMapper.fetchShareOverview(windowStart);
    }

    @Transactional(readOnly = true)
    public OverviewSummaryRow fetchOverviewSummary(Instant windowStart) {
        adminDistributionStatsReadMapper.applyStatementTimeout();
        return adminDistributionStatsReadMapper.fetchOverviewSummary(windowStart);
    }

    public List<TrendRow> listShareTrend(Instant windowStart) {
        return adminDistributionStatsReadMapper.listShareTrend(windowStart);
    }

    public List<FunnelRow> listShareFunnel(Instant windowStart) {
        return adminDistributionStatsReadMapper.listShareFunnel(windowStart);
    }

    public HandoffSummaryRow fetchShareHandoffSummary(Instant windowStart, String releaseChannel) {
        return adminDistributionStatsReadMapper.fetchShareHandoffSummary(windowStart, releaseChannel);
    }

    public List<HandoffTrendRow> listShareHandoffTrend(Instant windowStart, String releaseChannel) {
        return adminDistributionStatsReadMapper.listShareHandoffTrend(windowStart, releaseChannel);
    }

    public List<DetailRow> listRecentDetailRows(Instant windowStart, String releaseChannel, int limit) {
        return adminDistributionStatsReadMapper.listRecentDetailRows(windowStart, releaseChannel, limit);
    }

    public record SectionSummaryRow(
            long totalEvents,
            long successfulEvents,
            long failureEvents,
            Instant lastSeenAt
    ) {
    }

    public record OverviewSummaryRow(
            long releaseTotalEvents,
            long releaseFailureEvents,
            long shareTotalEvents,
            long shareFailureEvents,
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
