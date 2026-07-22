package com.zhangspaghetti.babytalk.practice.generated.evidence;

import java.util.Comparator;
import java.util.Objects;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * Deterministic, network-free evidence adapter for the development and test fake provider.
 */
@Component
@Primary
@Profile({"dev", "test"})
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "fake"
)
public class FakeCustomSceneEvidenceRetriever implements CustomSceneEvidenceRetriever {

    private static final String SOURCE_VERSION = "fake-custom-scene-evidence-v1";
    private static final String SUMMARY =
            "Use one calm, familiar phrase during an ordinary care moment without pressure.";

    @Override
    public EvidenceRetrievalResult retrieve(EvidenceRetrievalRequest request) {
        Objects.requireNonNull(request, "request");
        var items = request.requestedClaimTypes().stream()
                .sorted(Comparator.naturalOrder())
                .map(claimType -> new EvidenceItem(
                        "fake-custom-scene-" + claimType + "-v1",
                        ReplayMode.REFERENCE,
                        "strategy_pack",
                        SOURCE_VERSION,
                        "fake-custom-scene-strategy-v1",
                        claimType,
                        SUMMARY,
                        EvidenceSanitizer.sha256(SUMMARY),
                        1.0d))
                .toList();
        return new EvidenceRetrievalResult(items, request.retrievalTraceId(), RetrievalStatus.INITIAL);
    }
}
