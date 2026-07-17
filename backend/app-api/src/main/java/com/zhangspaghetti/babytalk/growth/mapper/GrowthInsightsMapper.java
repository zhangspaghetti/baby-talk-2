package com.zhangspaghetti.babytalk.growth.mapper;

import com.zhangspaghetti.babytalk.growth.model.GrowthInsightsProjections.BarBucket;
import com.zhangspaghetti.babytalk.growth.model.GrowthInsightsProjections.RecentActivity;
import com.zhangspaghetti.babytalk.growth.model.GrowthInsightsProjections.Scene;
import com.zhangspaghetti.babytalk.growth.model.GrowthInsightsProjections.Stats;
import com.zhangspaghetti.babytalk.growth.model.GrowthInsightsProjections.Suggestion;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface GrowthInsightsMapper {

    Stats loadStats(
            @Param("accountId") String accountId,
            @Param("windowStart") Instant windowStart,
            @Param("windowEnd") Instant windowEnd
    );

    List<LocalDate> listPracticeDates(
            @Param("accountId") String accountId,
            @Param("since") Instant since
    );

    List<BarBucket> listBars(
            @Param("truncUnit") String truncUnit,
            @Param("accountId") String accountId,
            @Param("windowStart") Instant windowStart,
            @Param("windowEnd") Instant windowEnd
    );

    List<Scene> listScenes(
            @Param("accountId") String accountId,
            @Param("windowStart") Instant windowStart,
            @Param("windowEnd") Instant windowEnd
    );

    RecentActivity loadRecentActivity(
            @Param("accountId") String accountId,
            @Param("thisWeekStart") Instant thisWeekStart,
            @Param("now") Instant now,
            @Param("lastWeekStart") Instant lastWeekStart
    );

    Suggestion findSuggestion(
            @Param("accountId") String accountId,
            @Param("windowStart") Instant windowStart,
            @Param("windowEnd") Instant windowEnd
    );
}
