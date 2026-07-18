package com.zhangspaghetti.babytalk.practice.generated.evidence;

import com.zhangspaghetti.babytalk.practice.agentic.config.MinimumEvidencePolicy;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedResourceRegistry;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceBundleEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceItemEntity;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Supplier;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class EvidenceBundleFactory {

    private final EvidenceBundlePersistencePort persistence;
    private final CustomSceneEvidenceRetriever retriever;
    private final MinimumEvidencePolicy policy;
    private final Clock clock;
    private final Supplier<UUID> uuidSupplier;

    @Autowired
    public EvidenceBundleFactory(
            EvidenceBundlePersistencePort persistence,
            CompositeCustomSceneEvidenceRetriever retriever,
            VersionedResourceRegistry registry
    ) {
        this(persistence, retriever, registry.minimumEvidencePolicy(), Clock.systemUTC(), UUID::randomUUID);
    }

    EvidenceBundleFactory(
            EvidenceBundlePersistencePort persistence,
            CustomSceneEvidenceRetriever retriever,
            MinimumEvidencePolicy policy,
            Clock clock,
            Supplier<UUID> uuidSupplier
    ) {
        this.persistence = Objects.requireNonNull(persistence, "persistence");
        this.retriever = Objects.requireNonNull(retriever, "retriever");
        this.policy = Objects.requireNonNull(policy, "policy");
        this.clock = Objects.requireNonNull(clock, "clock");
        this.uuidSupplier = Objects.requireNonNull(uuidSupplier, "uuidSupplier");
    }

    public FrozenEvidenceBundle createInitial(
            String generatedContentId,
            int attemptNumber,
            EvidenceRetrievalResult retrieval
    ) {
        requireSufficient(retrieval);
        if (retrieval.status() != RetrievalStatus.INITIAL) {
            throw new IllegalArgumentException("initial bundle requires INITIAL retrieval status");
        }
        return create(
                generatedContentId,
                attemptNumber,
                null,
                RetrievalStatus.INITIAL,
                retrieval.retrievalTraceId(),
                retrieval.items());
    }

    public FrozenEvidenceBundle deriveReused(
            String generatedContentId,
            int attemptNumber,
            FrozenEvidenceBundle previousBundle
    ) {
        Objects.requireNonNull(previousBundle, "previousBundle");
        return create(
                generatedContentId,
                attemptNumber,
                previousBundle.evidenceBundleId(),
                RetrievalStatus.REUSED,
                null,
                previousBundle.items());
    }

    public FrozenEvidenceBundle createRefreshed(
            String generatedContentId,
            int attemptNumber,
            EvidenceRetrievalRequest gapRequest
    ) {
        var retrieval = retriever.retrieve(Objects.requireNonNull(gapRequest, "gapRequest"));
        requireSufficient(retrieval);
        return create(
                generatedContentId,
                attemptNumber,
                null,
                RetrievalStatus.REFRESHED,
                retrieval.retrievalTraceId(),
                retrieval.items());
    }

    private FrozenEvidenceBundle create(
            String generatedContentId,
            int attemptNumber,
            UUID derivedFromBundleId,
            RetrievalStatus status,
            UUID retrievalTraceId,
            List<EvidenceItem> items
    ) {
        if (attemptNumber < 1 || attemptNumber > 5) {
            throw new IllegalArgumentException("attemptNumber must be between 1 and 5");
        }
        var frozenItems = List.copyOf(items);
        var bundle = new FrozenEvidenceBundle(
                uuidSupplier.get(),
                Objects.requireNonNull(generatedContentId, "generatedContentId"),
                attemptNumber,
                derivedFromBundleId,
                status,
                retrievalTraceId,
                policy.version(),
                policy.contentHash(),
                EvidenceSanitizer.VERSION,
                bundleHash(frozenItems),
                frozenItems,
                OffsetDateTime.now(clock));
        persist(bundle);
        return bundle;
    }

    private void requireSufficient(EvidenceRetrievalResult retrieval) {
        Objects.requireNonNull(retrieval, "retrieval");
        var sufficient = retrieval.status() != RetrievalStatus.INSUFFICIENT
                && policy.requiredClaimCoverage().stream().allMatch(claim -> retrieval.items().stream().anyMatch(item ->
                        claim.equals(item.claimType())
                                && item.confidence() >= policy.minimumConfidence()
                                && policy.trustedSourceTypes().contains(item.sourceType())));
        if (!sufficient) {
            throw new IllegalStateException("minimum evidence policy is not satisfied");
        }
    }

    private void persist(FrozenEvidenceBundle bundle) {
        var bundleEntity = new PracticeEvidenceBundleEntity(
                bundle.evidenceBundleId(),
                bundle.generatedContentId(),
                bundle.attemptNumber(),
                bundle.derivedFromBundleId(),
                bundle.status().name().toLowerCase(java.util.Locale.ROOT),
                bundle.retrievalTraceId(),
                bundle.evidencePolicyVersion(),
                bundle.evidencePolicyContentHash(),
                bundle.sanitizerVersion(),
                bundle.bundleHash(),
                bundle.items().size(),
                bundle.createdAt());
        var itemEntities = new ArrayList<PracticeEvidenceItemEntity>(bundle.items().size());
        for (var index = 0; index < bundle.items().size(); index++) {
            var item = bundle.items().get(index);
            itemEntities.add(new PracticeEvidenceItemEntity(
                    bundle.evidenceBundleId(),
                    index + 1,
                    item.replayMode().name().toLowerCase(java.util.Locale.ROOT),
                    item.evidenceId(),
                    item.sourceType(),
                    item.sourceVersion(),
                    item.strategyId(),
                    item.claimType(),
                    bundle.sanitizerVersion(),
                    item.sanitizedSummaryHash(),
                    item.replayMode() == ReplayMode.SNAPSHOT ? item.sanitizedSummary() : null,
                    BigDecimal.valueOf(item.confidence()),
                    bundle.createdAt()));
        }
        persistence.persistBundleWithItems(bundleEntity, List.copyOf(itemEntities));
    }

    private String bundleHash(List<EvidenceItem> items) {
        var canonical = new StringBuilder();
        for (var item : items) {
            append(canonical, item.evidenceId());
            append(canonical, item.replayMode().name());
            append(canonical, item.sourceType());
            append(canonical, item.sourceVersion());
            append(canonical, item.strategyId());
            append(canonical, item.claimType());
            append(canonical, item.sanitizedSummaryHash());
            append(canonical, BigDecimal.valueOf(item.confidence()).stripTrailingZeros().toPlainString());
        }
        try {
            var digest = MessageDigest.getInstance("SHA-256")
                    .digest(canonical.toString().getBytes(StandardCharsets.UTF_8));
            var hash = new StringBuilder(digest.length * 2);
            for (byte value : digest) {
                hash.append(String.format("%02x", value));
            }
            return hash.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    private void append(StringBuilder target, String value) {
        var safe = value == null ? "" : value;
        target.append(safe.length()).append(':').append(safe).append(';');
    }
}
