package com.zhangspaghetti.babytalk.practice.generated.evidence;

import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import java.util.Objects;
import org.springframework.stereotype.Component;

@Component
public class BaselineFamilyEnglishEvidenceSource implements CustomSceneEvidenceRetriever {

    private final VersionedResourceRegistry registry;
    private final EvidenceSanitizer sanitizer;

    public BaselineFamilyEnglishEvidenceSource(
            VersionedResourceRegistry registry,
            EvidenceSanitizer sanitizer
    ) {
        this.registry = registry;
        this.sanitizer = sanitizer;
    }

    @Override
    public EvidenceRetrievalResult retrieve(EvidenceRetrievalRequest request) {
        Objects.requireNonNull(request, "request");
        var items = registry.baselineEvidence().stream()
                .map(definition -> sanitizer.sanitize(definition.summary())
                        .map(summary -> new EvidenceItem(
                                definition.evidenceId(),
                                ReplayMode.REFERENCE,
                                "strategy_pack",
                                definition.sourceVersion(),
                                definition.strategyId(),
                                definition.claimType(),
                                summary.sanitizedSummary(),
                                summary.sanitizedSummaryHash(),
                                definition.confidence()))
                        .orElse(null))
                .filter(Objects::nonNull)
                .toList();
        return new EvidenceRetrievalResult(items, request.retrievalTraceId(), RetrievalStatus.INITIAL);
    }
}
