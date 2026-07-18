package com.zhangspaghetti.babytalk.practice.generated.evidence;

import com.zhangspaghetti.babytalk.palace.PalaceHybridRetrievalService;
import com.zhangspaghetti.babytalk.palace.RetrievalRequest;
import java.util.Comparator;
import java.util.Objects;
import org.springframework.stereotype.Component;

@Component
public class PalaceCustomSceneEvidenceSource implements CustomSceneEvidenceRetriever {

    private static final int MAX_CANDIDATES = 5;

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
        var claimType = requestedClaimType(request);
        var palaceResult = palaceRetrievalService.retrieve(new RetrievalRequest(
                request.displayText(),
                null,
                null,
                null,
                MAX_CANDIDATES,
                2));
        var items = palaceResult.rankedCandidates().stream()
                .limit(MAX_CANDIDATES)
                .map(candidate -> sanitizer.sanitize(candidate.content())
                        .map(summary -> new EvidenceItem(
                                snapshotEvidenceId(candidate.chunkId()),
                                ReplayMode.SNAPSHOT,
                                "approved_external_snapshot",
                                null,
                                null,
                                claimType,
                                summary.sanitizedSummary(),
                                summary.sanitizedSummaryHash(),
                                clamp(candidate.effectiveScore())))
                        .orElse(null))
                .filter(Objects::nonNull)
                .toList();
        return new EvidenceRetrievalResult(items, request.retrievalTraceId(), RetrievalStatus.INITIAL);
    }

    private String requestedClaimType(EvidenceRetrievalRequest request) {
        if (request.requestedClaimTypes().contains("scene_support")) {
            return "scene_support";
        }
        return request.requestedClaimTypes().stream()
                .sorted(Comparator.naturalOrder())
                .findFirst()
                .orElse("scene_support");
    }

    private String snapshotEvidenceId(String chunkId) {
        return "palace-snapshot-" + EvidenceSanitizer.sha256(chunkId == null ? "" : chunkId).substring(0, 24);
    }

    private double clamp(double confidence) {
        return Math.max(0.0d, Math.min(1.0d, confidence));
    }
}
