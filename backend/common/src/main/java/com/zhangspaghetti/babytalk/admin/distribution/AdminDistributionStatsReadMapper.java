package com.zhangspaghetti.babytalk.admin.distribution;

import java.time.Instant;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface AdminDistributionStatsReadMapper {

    @Update("set local statement_timeout = '2000ms'")
    void applyStatementTimeout();

    AdminDistributionStatsReadRepository.SectionSummaryRow fetchReleaseOverview(
            @Param("windowStart") Instant windowStart,
            @Param("releaseChannel") String releaseChannel
    );

    List<AdminDistributionStatsReadRepository.TrendRow> listReleaseTrend(
            @Param("windowStart") Instant windowStart,
            @Param("releaseChannel") String releaseChannel
    );

    AdminDistributionStatsReadRepository.SectionSummaryRow fetchShareOverview(@Param("windowStart") Instant windowStart);

    AdminDistributionStatsReadRepository.OverviewSummaryRow fetchOverviewSummary(@Param("windowStart") Instant windowStart);

    List<AdminDistributionStatsReadRepository.TrendRow> listShareTrend(@Param("windowStart") Instant windowStart);

    List<AdminDistributionStatsReadRepository.FunnelRow> listShareFunnel(@Param("windowStart") Instant windowStart);

    AdminDistributionStatsReadRepository.HandoffSummaryRow fetchShareHandoffSummary(
            @Param("windowStart") Instant windowStart,
            @Param("releaseChannel") String releaseChannel
    );

    List<AdminDistributionStatsReadRepository.HandoffTrendRow> listShareHandoffTrend(
            @Param("windowStart") Instant windowStart,
            @Param("releaseChannel") String releaseChannel
    );

    List<AdminDistributionStatsReadRepository.DetailRow> listRecentDetailRows(
            @Param("windowStart") Instant windowStart,
            @Param("releaseChannel") String releaseChannel,
            @Param("limit") int limit
    );
}
