package com.zhangspaghetti.babytalk.practice.scene;

import java.time.OffsetDateTime;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface ScenePersonalizationContextMapper {

    WeeklyReactionCounts findWeeklyReactionCounts(
            @Param("householdId") String householdId,
            @Param("ownerAccountId") String ownerAccountId,
            @Param("weekStart") OffsetDateTime weekStart,
            @Param("now") OffsetDateTime now
    );

    List<ActivityCount> findTopWeeklyActivities(
            @Param("householdId") String householdId,
            @Param("ownerAccountId") String ownerAccountId,
            @Param("weekStart") OffsetDateTime weekStart,
            @Param("now") OffsetDateTime now
    );

    record WeeklyReactionCounts(
            int recentPracticeCount,
            int cooperatingCount,
            int hesitantCount,
            int resistingCount,
            int noResponseCount,
            int otherCount
    ) {
    }

    record ActivityCount(
            String spaceId,
            String activityId,
            int eventCount
    ) {
    }
}
