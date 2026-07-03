package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface OnboardingProfileMapper {

    OnboardingProfileRepository.ProfileRow findByAccountId(@Param("accountId") String accountId);

    void insert(@Param("row") OnboardingProfileRepository.ProfileRow row);

    int updateIfVersionMatches(
            @Param("accountId") String accountId,
            @Param("expectedVersion") int expectedVersion,
            @Param("patch") OnboardingProfileRepository.ProfilePatch patch,
            @Param("updatedAt") Instant updatedAt
    );

    Integer findVersionByAccountId(@Param("accountId") String accountId);

    int deleteByAccountId(@Param("accountId") String accountId);
}
