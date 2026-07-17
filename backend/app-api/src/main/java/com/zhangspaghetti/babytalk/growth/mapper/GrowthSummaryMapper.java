package com.zhangspaghetti.babytalk.growth.mapper;

import com.zhangspaghetti.babytalk.growth.model.GrowthSummaryStatsProjection;
import java.time.Instant;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface GrowthSummaryMapper {

    GrowthSummaryStatsProjection loadStats(
            @Param("accountId") String accountId,
            @Param("windowStart") Instant windowStart,
            @Param("windowEnd") Instant windowEnd
    );
}
