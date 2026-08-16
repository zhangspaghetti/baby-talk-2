package com.zhangspaghetti.babytalk.garden.mapper;

import com.zhangspaghetti.babytalk.garden.model.GardenFertilizerStateProjection;
import java.time.Instant;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface GardenFertilizerMapper {

    int ensureStateRow(@Param("userId") String userId);

    int countClaimsByRequestId(
            @Param("userId") String userId,
            @Param("requestId") String requestId
    );

    int insertClaim(
            @Param("userId") String userId,
            @Param("eventKey") String eventKey,
            @Param("requestId") String requestId,
            @Param("claimedAt") Instant claimedAt
    );

    int updateLastClaimed(
            @Param("userId") String userId,
            @Param("claimedAt") Instant claimedAt
    );

    int insertApply(
            @Param("userId") String userId,
            @Param("requestId") String requestId,
            @Param("appliedAt") Instant appliedAt
    );

    int applyOne(
            @Param("userId") String userId,
            @Param("appliedAt") Instant appliedAt
    );

    GardenFertilizerStateProjection findState(@Param("userId") String userId);

    int countClaims(@Param("userId") String userId);

    List<String> listClaimedEventKeys(@Param("userId") String userId);
}
