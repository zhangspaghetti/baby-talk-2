package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.SceneContentGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.UnaryOperator;

/**
 * Application representation of one closed, versioned provider bundle. Production paths can only
 * construct this from {@link CompleteGeneratedBundle}; no starter-only support synthesis exists.
 */
public record GeneratedCareMomentBundle(CompleteGeneratedBundle completeBundle) {
    public static final int UTTERANCE_COUNT = 6;

    public GeneratedCareMomentBundle {
        Objects.requireNonNull(completeBundle, "completeBundle");
        CompleteGeneratedBundle.requireSupportedSchemaVersion(completeBundle.schemaVersion());
    }

    public static GeneratedCareMomentBundle fromCompleteBundle(CompleteGeneratedBundle completeBundle) {
        return new GeneratedCareMomentBundle(completeBundle);
    }

    /** Explicit fake-only fixture helper. Never use for an agentic or persisted production result. */
    public static GeneratedCareMomentBundle fakeFixture(GeneratedPracticeContentCandidate starter) {
        Objects.requireNonNull(starter, "starter");
        var provenance = new CompleteGeneratedBundle.ProviderProvenance(
                CompleteGeneratedBundle.ProviderOrigin.PROVIDER_GENERATED, "fake", "deterministic", 1);
        var utterances = new ArrayList<CompleteGeneratedBundle.Utterance>();
        utterances.add(new CompleteGeneratedBundle.Utterance(
                CompleteGeneratedBundle.UtteranceRole.STARTER, null,
                starter.englishText(), starter.chineseText(), starter.pronunciationHint(),
                starter.tprActionZh(), starter.deliveryGuidanceZh(), starter.difficulty(), 1, provenance));
        for (var reaction : CompleteGeneratedBundle.Reaction.values()) {
            utterances.add(new CompleteGeneratedBundle.Utterance(
                    CompleteGeneratedBundle.UtteranceRole.REACTION_SUPPORT,
                    reaction,
                    fakeSupportEnglish(reaction),
                    fakeSupportChinese(reaction),
                    fakeSupportPronunciation(reaction),
                    fakeSupportTpr(reaction),
                    fakeSupportDelivery(reaction),
                    starter.difficulty(),
                    reaction.ordinal() + 2,
                    provenance));
        }
        return fromCompleteBundle(new CompleteGeneratedBundle(
                CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION,
                new CompleteGeneratedBundle.SceneMetadata(
                        starter.spaceTitleZh(), starter.activityTitleZh(), starter.sceneTagEn()),
                utterances));
    }

    public GeneratedPracticeContentCandidate starter() {
        return candidateFor(toGeneratedUtterance(utterance(1)));
    }

    public GeneratedCareUtterance starterUtterance() {
        return toGeneratedUtterance(utterance(1));
    }

    public Map<ReactionType, GeneratedCareUtterance> reactionSupports() {
        var supports = new EnumMap<ReactionType, GeneratedCareUtterance>(ReactionType.class);
        for (var reaction : ReactionType.values()) {
            supports.put(reaction, toGeneratedUtterance(utterance(reaction.ordinal() + 2)));
        }
        return Map.copyOf(supports);
    }

    public List<GeneratedCareUtterance> utterances() {
        return completeBundle.utterances().stream().map(this::toGeneratedUtterance).toList();
    }

    public GeneratedPracticeContentCandidate candidateFor(GeneratedCareUtterance utterance) {
        Objects.requireNonNull(utterance, "utterance");
        var scene = completeBundle.scene();
        return new GeneratedPracticeContentCandidate(
                scene.spaceTitleZh(), scene.activityTitleZh(), scene.sceneTagEn(),
                utterance.tprActionZh(), utterance.deliveryGuidanceZh(), utterance.englishText(),
                utterance.chineseText(), utterance.pronunciationHint(), utterance.difficulty(),
                sourceFor(utterance.providerProvenance()));
    }

    public List<String> structuralViolationCodes() {
        return List.of();
    }

    public GeneratedCareMomentBundle mapCandidates(UnaryOperator<GeneratedPracticeContentCandidate> normalizer) {
        Objects.requireNonNull(normalizer, "normalizer");
        var normalized = completeBundle.utterances().stream()
                .map(utterance -> new NormalizedUtterance(utterance, normalizer.apply(candidateFor(toGeneratedUtterance(utterance)))))
                .toList();
        var scene = normalized.get(0).candidate();
        if (normalized.stream().map(NormalizedUtterance::candidate).anyMatch(candidate ->
                !scene.spaceTitleZh().equals(candidate.spaceTitleZh())
                        || !scene.activityTitleZh().equals(candidate.activityTitleZh())
                        || !scene.sceneTagEn().equals(candidate.sceneTagEn()))) {
            throw new IllegalArgumentException("normalized bundle must retain shared scene metadata");
        }
        return fromCompleteBundle(new CompleteGeneratedBundle(
                completeBundle.schemaVersion(),
                new CompleteGeneratedBundle.SceneMetadata(
                        scene.spaceTitleZh(), scene.activityTitleZh(), scene.sceneTagEn()),
                normalized.stream().map(this::replaceText).toList()));
    }

    private CompleteGeneratedBundle.Utterance replaceText(NormalizedUtterance normalized) {
        var original = normalized.original();
        var candidate = normalized.candidate();
        return new CompleteGeneratedBundle.Utterance(
                original.role(), original.reaction(), candidate.englishText(), candidate.chineseText(),
                candidate.pronunciationHint(), candidate.tprActionZh(), candidate.deliveryGuidanceZh(),
                candidate.difficulty(), original.displayOrder(), original.providerProvenance());
    }

    private CompleteGeneratedBundle.Utterance utterance(int displayOrder) {
        return completeBundle.utterances().stream()
                .filter(value -> value.displayOrder() == displayOrder)
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("complete bundle is missing canonical display order"));
    }

    private GeneratedCareUtterance toGeneratedUtterance(CompleteGeneratedBundle.Utterance utterance) {
        return new GeneratedCareUtterance(
                utterance.role(), utterance.reaction(), utterance.englishText(), utterance.chineseText(),
                utterance.pronunciationHint(), utterance.tprActionZh(), utterance.deliveryGuidanceZh(),
                utterance.difficulty(), utterance.displayOrder(), utterance.providerProvenance());
    }

    private static String sourceFor(CompleteGeneratedBundle.ProviderProvenance provenance) {
        // Legacy parent field retains its constrained routing classification. Per-utterance
        // provenance is canonical and records generated versus repaired origin.
        return "fake".equals(provenance.providerName()) ? "fake" : "agentic_search";
    }

    private static String fakeSupportEnglish(CompleteGeneratedBundle.Reaction reaction) {
        return switch (reaction) {
            case COOPERATING -> "We do it together.";
            case HESITANT -> "Try when ready.";
            case RESISTING -> "It is okay to pause.";
            case NO_RESPONSE -> "I will wait with you.";
            case OTHER -> "We can take a pause.";
        };
    }

    private static String fakeSupportChinese(CompleteGeneratedBundle.Reaction reaction) {
        return switch (reaction) {
            case COOPERATING -> "我们一起做。";
            case HESITANT -> "准备好再试。";
            case RESISTING -> "可以先停一下。";
            case NO_RESPONSE -> "我陪你等一等。";
            case OTHER -> "我们先停一会儿。";
        };
    }

    private static String fakeSupportPronunciation(CompleteGeneratedBundle.Reaction reaction) {
        return switch (reaction) {
            case COOPERATING -> "we do it together";
            case HESITANT -> "try when ready";
            case RESISTING -> "it is okay to pause";
            case NO_RESPONSE -> "i will wait with you";
            case OTHER -> "we can take a pause";
        };
    }

    private static String fakeSupportTpr(CompleteGeneratedBundle.Reaction reaction) {
        return switch (reaction) {
            case COOPERATING -> "拿起物品，一起做。";
            case HESITANT -> "拿起物品，放在旁边。";
            case RESISTING -> "拿起物品后停一停。";
            case NO_RESPONSE -> "拿起物品，等一等。";
            case OTHER -> "拿起物品，做深呼吸。";
        };
    }

    private static String fakeSupportDelivery(CompleteGeneratedBundle.Reaction reaction) {
        return switch (reaction) {
            case COOPERATING -> "慢慢说，等宝宝回应。";
            case HESITANT -> "慢慢说，等宝宝准备好。";
            case RESISTING -> "慢慢说，等宝宝点头。";
            case NO_RESPONSE -> "慢慢说，等宝宝回应。";
            case OTHER -> "慢慢说，等宝宝再试。";
        };
    }

    private record NormalizedUtterance(
            CompleteGeneratedBundle.Utterance original,
            GeneratedPracticeContentCandidate candidate
    ) {
        private NormalizedUtterance {
            Objects.requireNonNull(candidate, "normalized candidate");
        }
    }

    public enum ReactionType {
        COOPERATING("cooperating"),
        HESITANT("hesitant"),
        RESISTING("resisting"),
        NO_RESPONSE("no_response"),
        OTHER("other");

        private final String wireValue;

        ReactionType(String wireValue) {
            this.wireValue = wireValue;
        }

        public String wireValue() {
            return wireValue;
        }
    }
}
