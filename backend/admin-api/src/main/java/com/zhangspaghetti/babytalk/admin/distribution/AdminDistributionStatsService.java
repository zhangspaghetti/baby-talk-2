package com.zhangspaghetti.babytalk.admin.distribution;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminDistributionStatsService {

    private static final List<String> ALLOWED_RANGES = List.of("7d", "30d", "90d");
    private static final Set<String> ALLOWED_RANGE_SET = Set.copyOf(ALLOWED_RANGES);
    private static final List<String> ALLOWED_CHANNELS = List.of("all", "stable", "beta");
    private static final Set<String> ALLOWED_CHANNEL_SET = Set.copyOf(ALLOWED_CHANNELS);
    private static final String CHANNEL_SCOPE_NOTE = "channel 只作用于 release_distribution_events 与 source=share_card 的 handoff；share_landing_events 原始 section 不带 channel。";

    private final AdminDistributionStatsReadRepository repository;
    private final AdminDistributionStatsProperties properties;
    private final Clock clock;

    public AdminDistributionStatsService(
            AdminDistributionStatsReadRepository repository,
            AdminDistributionStatsProperties properties,
            Clock clock
    ) {
        this.repository = repository;
        this.properties = properties;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public DistributionStatsView getStats(String range, String channel) {
        var normalizedRange = normalizeRange(range);
        var normalizedChannel = normalizeChannel(channel);
        var now = Instant.now(clock);
        var windowStart = now.minus(normalizedRange.window());

        var releaseOverview = repository.fetchReleaseOverview(windowStart, normalizedChannel.releaseChannel());
        var releaseTrend = repository.listReleaseTrend(windowStart, normalizedChannel.releaseChannel()).stream()
                .map(row -> new TrendPointView(row.eventDay(), row.entrypoint(), row.result(), row.eventCount()))
                .toList();
        var shareOverview = repository.fetchShareOverview(windowStart);
        var shareTrend = repository.listShareTrend(windowStart).stream()
                .map(row -> new TrendPointView(row.eventDay(), row.entrypoint(), row.result(), row.eventCount()))
                .toList();
        var shareFunnel = repository.listShareFunnel(windowStart).stream()
                .map(row -> new FunnelPointView(
                        row.entrypoint(),
                        row.totalEvents(),
                        row.successfulEvents(),
                        row.failureEvents(),
                        row.successRatePct(),
                        row.lastSeenAt()))
                .toList();
        var shareHandoffSummary = repository.fetchShareHandoffSummary(windowStart, normalizedChannel.releaseChannel());
        var shareHandoffTrend = repository.listShareHandoffTrend(windowStart, normalizedChannel.releaseChannel()).stream()
                .map(row -> new HandoffTrendPointView(
                        row.eventDay(),
                        row.platform(),
                        row.shareDownloadFallbackCount(),
                        row.releaseShareCardCount(),
                        row.releaseMinusShare()))
                .toList();
        var detailRows = repository.listRecentDetailRows(
                        windowStart,
                        normalizedChannel.releaseChannel(),
                        properties.detailLimit())
                .stream()
                .map(row -> new DetailRowView(
                        row.surface(),
                        row.createdAt(),
                        row.channel(),
                        row.source(),
                        row.entrypoint(),
                        row.platform(),
                        row.result(),
                        row.failureReason()))
                .toList();

        return new DistributionStatsView(
                new AppliedFiltersView(
                        normalizedRange.value(),
                        normalizedChannel.value(),
                        properties.detailLimit(),
                        windowStart),
                CHANNEL_SCOPE_NOTE,
                new SectionOverviewView(
                        releaseOverview.totalEvents(),
                        releaseOverview.successfulEvents(),
                        releaseOverview.failureEvents(),
                        releaseOverview.lastSeenAt()),
                releaseTrend,
                new SectionOverviewView(
                        shareOverview.totalEvents(),
                        shareOverview.successfulEvents(),
                        shareOverview.failureEvents(),
                        shareOverview.lastSeenAt()),
                shareTrend,
                shareFunnel,
                new ShareHandoffView(
                        shareHandoffSummary.totalShareDownloadFallbackEvents(),
                        shareHandoffSummary.totalReleaseShareCardEvents(),
                        shareHandoffSummary.totalReleaseShareCardEvents() - shareHandoffSummary.totalShareDownloadFallbackEvents(),
                        latestOf(shareHandoffSummary.shareLastSeenAt(), shareHandoffSummary.releaseLastSeenAt()),
                        shareHandoffSummary.shareLastSeenAt(),
                        shareHandoffSummary.releaseLastSeenAt(),
                        shareHandoffTrend),
                detailRows
        );
    }

    private RangeSelection normalizeRange(String range) {
        if (range == null) {
            return rangeSelection(properties.defaultRange());
        }
        if (range.isBlank()) {
            throw invalidRange();
        }
        return rangeSelection(range.trim().toLowerCase(Locale.ROOT));
    }

    private RangeSelection rangeSelection(String value) {
        if (!ALLOWED_RANGE_SET.contains(value)) {
            throw invalidRange();
        }
        return switch (value) {
            case "7d" -> new RangeSelection(value, Duration.ofDays(7));
            case "30d" -> new RangeSelection(value, Duration.ofDays(30));
            case "90d" -> new RangeSelection(value, Duration.ofDays(90));
            default -> throw invalidRange();
        };
    }

    private ChannelSelection normalizeChannel(String channel) {
        if (channel == null) {
            return new ChannelSelection("all", null);
        }
        if (channel.isBlank()) {
            throw invalidChannel();
        }
        var normalized = channel.trim().toLowerCase(Locale.ROOT);
        if (!ALLOWED_CHANNEL_SET.contains(normalized)) {
            throw invalidChannel();
        }
        return "all".equals(normalized)
                ? new ChannelSelection(normalized, null)
                : new ChannelSelection(normalized, normalized);
    }

    private AdminApiContractException invalidRange() {
        return new AdminApiContractException(
                HttpStatus.BAD_REQUEST,
                "invalid_distribution_stats_range",
                "range 只支持固定预设窗口。",
                Map.of("allowedRanges", ALLOWED_RANGES));
    }

    private AdminApiContractException invalidChannel() {
        return new AdminApiContractException(
                HttpStatus.BAD_REQUEST,
                "invalid_distribution_stats_channel",
                "channel 只支持固定枚举。",
                Map.of("allowedChannels", ALLOWED_CHANNELS));
    }

    private Instant latestOf(Instant left, Instant right) {
        if (left == null) {
            return right;
        }
        if (right == null) {
            return left;
        }
        return left.isAfter(right) ? left : right;
    }

    private record RangeSelection(String value, Duration window) {
    }

    private record ChannelSelection(String value, String releaseChannel) {
    }

    public record DistributionStatsView(
            AppliedFiltersView applied,
            String channelScopeNote,
            SectionOverviewView releaseOverview,
            List<TrendPointView> releaseTrend,
            SectionOverviewView shareOverview,
            List<TrendPointView> shareTrend,
            List<FunnelPointView> shareFunnel,
            ShareHandoffView shareHandoff,
            List<DetailRowView> detailRows
    ) {
    }

    public record AppliedFiltersView(
            String range,
            String channel,
            int detailLimit,
            Instant windowStartedAt
    ) {
    }

    public record SectionOverviewView(
            long totalEvents,
            long successfulEvents,
            long failureEvents,
            Instant lastSeenAt
    ) {
    }

    public record TrendPointView(
            LocalDate eventDay,
            String entrypoint,
            String result,
            long eventCount
    ) {
    }

    public record FunnelPointView(
            String entrypoint,
            long totalEvents,
            long successfulEvents,
            long failureEvents,
            java.math.BigDecimal successRatePct,
            Instant lastSeenAt
    ) {
    }

    public record ShareHandoffView(
            long totalShareDownloadFallbackEvents,
            long totalReleaseShareCardEvents,
            long releaseMinusShare,
            Instant lastSeenAt,
            Instant shareLastSeenAt,
            Instant releaseLastSeenAt,
            List<HandoffTrendPointView> trend
    ) {
    }

    public record HandoffTrendPointView(
            LocalDate eventDay,
            String platform,
            long shareDownloadFallbackCount,
            long releaseShareCardCount,
            long releaseMinusShare
    ) {
    }

    public record DetailRowView(
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
