package com.zhangspaghetti.babytalk.practice.generated.evidence;

import com.zhangspaghetti.babytalk.palace.PalaceHybridRetrievalService;
import com.zhangspaghetti.babytalk.palace.RetrievalRequest;
import java.util.Objects;
import org.springframework.stereotype.Component;

@Component
public class PalaceCustomSceneEvidenceSource implements CustomSceneEvidenceRetriever {

    private static final int MAX_CANDIDATES = 5;
    // PgVector cosine relevance gates whether a bounded candidate is usable; it is not evidence confidence.
    private static final double MINIMUM_RELEVANCE = 0.60d;
    // Current Palace projection membership supplies trusted snapshot provenance after relevance eligibility passes.
    private static final double TRUSTED_CURRENT_PROJECTION_CONFIDENCE = 0.75d;

    private final PalaceHybridRetrievalService palaceRetrievalService;
    private final EvidenceSanitizer sanitizer;

    public PalaceCustomSceneEvidenceSource(
            PalaceHybridRetrievalService palaceRetrievalService,
            EvidenceSanitizer sanitizer
    ) {
        this.palaceRetrievalService = palaceRetrievalService;
        this.sanitizer = sanitizer;
    }

    @Override
    public EvidenceRetrievalResult retrieve(EvidenceRetrievalRequest request) {
        Objects.requireNonNull(request, "request");
        var palaceResult = palaceRetrievalService.retrieve(new RetrievalRequest(
                request.displayText(),
                null,
                null,
                null,
                MAX_CANDIDATES,
                2));
        boolean currentProjectionAvailable = isCurrentProjectionAvailable(
                palaceResult.trace().projectionVersionUsed());
        var items = palaceResult.rankedCandidates().stream()
                .limit(MAX_CANDIDATES)
                .filter(candidate -> isEligibleCurrentProjectionEvidence(candidate, currentProjectionAvailable))
                .map(candidate -> sanitizer.sanitize(candidate.content())
                        .map(summary -> new EvidenceItem(
                                snapshotEvidenceId(candidate.chunkId()),
                                ReplayMode.SNAPSHOT,
                                "approved_external_snapshot",
                                null,
                                null,
                                "scene_support",
                                summary.sanitizedSummary(),
                                summary.sanitizedSummaryHash(),
                                TRUSTED_CURRENT_PROJECTION_CONFIDENCE))
                        .orElse(null))
                .filter(Objects::nonNull)
                .toList();
        var status = items.isEmpty() ? RetrievalStatus.INSUFFICIENT : RetrievalStatus.INITIAL;
        return new EvidenceRetrievalResult(items, request.retrievalTraceId(), status);
    }

    private boolean isEligibleCurrentProjectionEvidence(
            com.zhangspaghetti.babytalk.palace.HybridCandidate candidate,
            boolean currentProjectionAvailable) {
        return currentProjectionAvailable
                && candidate.currentProjectionMember()
                && Double.isFinite(candidate.effectiveScore())
                && candidate.effectiveScore() >= MINIMUM_RELEVANCE;
    }

    private boolean isCurrentProjectionAvailable(String projectionVersion) {
        if (projectionVersion == null || projectionVersion.isBlank()) {
            return false;
        }
        try {
            return Long.parseLong(projectionVersion) > 0;
        } catch (NumberFormatException exception) {
            return false;
        }
    }

    private String snapshotEvidenceId(String chunkId) {
        return "palace-snapshot-" + EvidenceSanitizer.sha256(chunkId == null ? "" : chunkId).substring(0, 24);
    }

}
