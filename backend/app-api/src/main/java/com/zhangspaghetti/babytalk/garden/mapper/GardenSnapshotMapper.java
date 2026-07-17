package com.zhangspaghetti.babytalk.garden.mapper;

import com.zhangspaghetti.babytalk.garden.model.GardenSnapshotStatsProjection;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface GardenSnapshotMapper {

    GardenSnapshotStatsProjection loadStats(@Param("accountId") String accountId);

    List<LocalDate> listPracticeDates(
            @Param("accountId") String accountId,
            @Param("todayStart") Instant todayStart
    );

    Instant findTenthPhraseAchievedAt(@Param("accountId") String accountId);

    Instant findThirdSpaceAchievedAt(@Param("accountId") String accountId);

    Instant findFiftiethEventAt(@Param("accountId") String accountId);

    List<String> listPendingEventKeys(@Param("accountId") String accountId);
}
