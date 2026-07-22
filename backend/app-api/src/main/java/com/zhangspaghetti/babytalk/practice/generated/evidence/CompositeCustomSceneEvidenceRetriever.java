package com.zhangspaghetti.babytalk.practice.generated.evidence;

import com.zhangspaghetti.babytalk.practice.agentic.config.MinimumEvidencePolicy;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Objects;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;

@Component
public class CompositeCustomSceneEvidenceRetriever implements CustomSceneEvidenceRetriever {

    private static final Comparator<EvidenceItem> ORDER = Comparator
            .comparing(EvidenceItem::claimType)
            .thenComparing(EvidenceItem::confidence, Comparator.reverseOrder())
            .thenComparing(EvidenceItem::evidenceId)
            .thenComparing(item -> item.sourceVersion() == null ? "" : item.sourceVersion())
            .thenComparing(EvidenceItem::sanitizedSummaryHash);

    private final CustomSceneEvidenceRetriever baselineSource;
    private final CustomSceneEvidenceRetriever palaceSource;
    private final MinimumEvidencePolicy policy;

    @Autowired
    public CompositeCustomSceneEvidenceRetriever(
            @Qualifier("baselineFamilyEnglishEvidenceSource") CustomSceneEvidenceRetriever baselineSource,
            @Qualifier("palaceCustomSceneEvidenceSource") CustomSceneEvidenceRetriever palaceSource,
            VersionedResourceRegistry registry
    ) {
        this(baselineSource, palaceSource, registry.minimumEvidencePolicy());
    }

    CompositeCustomSceneEvidenceRetriever(
            CustomSceneEvidenceRetriever baselineSource,
            CustomSceneEvidenceRetriever palaceSource,
            MinimumEvidencePolicy policy
    ) {
        this.baselineSource = baselineSource;
        this.palaceSource = palaceSource;
        this.policy = policy;
    }

    @Override
    public EvidenceRetrievalResult retrieve(EvidenceRetrievalRequest request) {
        Objects.requireNonNull(request, "request");
        var deduplicated = new LinkedHashMap<DeduplicationKey, EvidenceItem>();
        add(deduplicated, baselineSource.retrieve(request).items());
        add(deduplicated, palaceSource.retrieve(request).items());
        var items = deduplicated.values().stream().sorted(ORDER).toList();
        var status = satisfiesPolicy(items) ? RetrievalStatus.INITIAL : RetrievalStatus.INSUFFICIENT;
        return new EvidenceRetrievalResult(items, request.retrievalTraceId(), status);
    }

    private void add(LinkedHashMap<DeduplicationKey, EvidenceItem> target, List<EvidenceItem> items) {
        for (var item : items) {
            target.putIfAbsent(new DeduplicationKey(
                    item.evidenceId(),
                    item.sourceVersion(),
                    item.claimType(),
                    item.sanitizedSummaryHash()), item);
        }
    }

    private boolean satisfiesPolicy(List<EvidenceItem> items) {
        return policy.requiredClaimCoverage().stream().allMatch(requiredClaim -> items.stream().anyMatch(item ->
                requiredClaim.equals(item.claimType())
                        && item.confidence() >= policy.minimumConfidence()
                        && policy.trustedSourceTypes().contains(item.sourceType())));
    }

    private record DeduplicationKey(
            String evidenceId,
            String sourceVersion,
            String claimType,
            String summaryHash
    ) {
    }
}
