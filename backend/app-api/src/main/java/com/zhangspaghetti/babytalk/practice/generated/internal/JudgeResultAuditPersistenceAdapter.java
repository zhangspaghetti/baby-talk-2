package com.zhangspaghetti.babytalk.practice.generated.internal;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeJudgeResultEntity;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeResultAuditPort;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

@Service
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
class JudgeResultAuditPersistenceAdapter implements JudgeResultAuditPort {

    private final PracticeGenerationAuditMapper auditMapper;
    private final Clock clock;
    private final ObjectMapper objectMapper;

    JudgeResultAuditPersistenceAdapter(PracticeGenerationAuditMapper auditMapper) {
        this(auditMapper, Clock.systemUTC());
    }

    JudgeResultAuditPersistenceAdapter(PracticeGenerationAuditMapper auditMapper, Clock clock) {
        this.auditMapper = auditMapper;
        this.clock = clock;
        this.objectMapper = new ObjectMapper();
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void persist(JudgeAuditRecord record) {
        var dimensions = new LinkedHashMap<String, String>();
        for (var dimension : JudgeDimension.values()) {
            dimensions.put(
                    dimension.rubricKey(),
                    record.suggested().dimensionResults().get(dimension).name().toLowerCase(Locale.ROOT));
        }
        auditMapper.insertJudgeResult(new PracticeJudgeResultEntity(
                UUID.randomUUID(),
                record.providerCallId(),
                record.suggested().suggestedVerdict().name().toLowerCase(Locale.ROOT),
                record.effective().effectiveVerdict().name().toLowerCase(Locale.ROOT),
                record.effective().verdictConsistency().name().toLowerCase(Locale.ROOT),
                objectMapper.writeValueAsString(dimensions),
                record.suggested().violationCodes(),
                record.suggested().repairDirectives().stream().map(Enum::name).toList(),
                record.suggested().evidenceGapCodes().stream().map(Enum::name).toList(),
                BigDecimal.valueOf(record.suggested().confidence()),
                record.rubric().version(),
                record.rubric().contentHash(),
                OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)));
    }
}
