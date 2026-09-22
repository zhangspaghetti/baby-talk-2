package com.zhangspaghetti.babytalk.profile;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zhangspaghetti.babytalk.profile.model.BabyProfilePatch;
import com.zhangspaghetti.babytalk.profile.model.BabyProfileRow;
import java.time.OffsetDateTime;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface BabyProfileMapper extends BaseMapper<BabyProfileRow> {

    BabyProfileRow findByAccountId(@Param("accountId") String accountId);

    /**
     * Resolves the owning account's profile only through an active caregiver
     * membership in that owner's active household.
     */
    BabyProfileRow findSharedByHouseholdMemberAccountId(@Param("accountId") String accountId);

    int updateIfVersionMatches(
            @Param("accountId") String accountId,
            @Param("expectedVersion") int expectedVersion,
            @Param("patch") BabyProfilePatch patch,
            @Param("updatedAt") OffsetDateTime updatedAt
    );

    Integer findVersionByAccountId(@Param("accountId") String accountId);

    int deleteByAccountId(@Param("accountId") String accountId);
}
