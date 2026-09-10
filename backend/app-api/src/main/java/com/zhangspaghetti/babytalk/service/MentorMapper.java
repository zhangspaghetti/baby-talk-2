package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface MentorMapper {

    int countRequestsSince(
            @Param("installationReference") String installationReference,
            @Param("legacyInstallationId") String legacyInstallationId,
            @Param("since") Instant since
    );

    void insertTurn(@Param("row") MentorRepository.TurnRow row);

    void insertAudit(@Param("row") MentorRepository.AuditRow row);

    MentorRepository.TurnRow findTurnByCorrelationId(@Param("correlationId") String correlationId);

    List<MentorRepository.AuditRow> listAuditRowsByCorrelationId(@Param("correlationId") String correlationId);

    int countTurns();

    int countAuditRows();
}
