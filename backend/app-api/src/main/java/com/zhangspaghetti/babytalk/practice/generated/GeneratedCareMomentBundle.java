package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Bounded response for one care moment.  A reaction never opens another generation request.
 */
public record GeneratedCareMomentBundle(
        GeneratedPracticeContentCandidate starter,
        Map<ReactionType, GeneratedCareUtterance> reactionSupports
) {
    public static final int UTTERANCE_COUNT = 6;

    public GeneratedCareMomentBundle {
        Objects.requireNonNull(starter, "starter");
        var copy = new EnumMap<ReactionType, GeneratedCareUtterance>(ReactionType.class);
        copy.putAll(Objects.requireNonNull(reactionSupports, "reactionSupports"));
        reactionSupports = Map.copyOf(copy);
    }

    public static GeneratedCareMomentBundle fromStarter(GeneratedPracticeContentCandidate starter) {
        return new GeneratedCareMomentBundle(starter, Map.of(
                ReactionType.COOPERATING, support("Let's do it together.", "我们一起试试。", "lets do it together", "一起做动作。", "语速放慢，给宝宝等候。"),
                ReactionType.HESITANT, support("You can try when ready.", "准备好再试也可以。", "you can try when ready", "把物品放近。", "轻声邀请，不催促。"),
                ReactionType.RESISTING, support("It's okay to say no.", "不想做也没关系。", "its okay to say no", "手掌向外停一停。", "先接住拒绝，再给选择。"),
                ReactionType.NO_RESPONSE, support("I will wait with you.", "我会陪你等一等。", "i will wait with you", "安静停留。", "留出安静时间，不重复追问。"),
                ReactionType.OTHER, support("Let's take a small pause.", "我们先停一小会儿。", "lets take a small pause", "做深呼吸动作。", "平静收束，稍后再试。")));
    }

    public GeneratedCareMomentBundle withStarter(GeneratedPracticeContentCandidate normalizedStarter) {
        return new GeneratedCareMomentBundle(normalizedStarter, reactionSupports);
    }

    public List<String> structuralViolationCodes() {
        if (reactionSupports.size() != ReactionType.values().length
                || !reactionSupports.keySet().containsAll(List.of(ReactionType.values()))
                || reactionSupports.values().stream().anyMatch(Objects::isNull)) {
            return List.of("MISSING_REACTION_SUPPORT");
        }
        return List.of();
    }

    public List<String> deterministicViolationCodes(CustomSceneGenerator.ContentConstraints constraints) {
        var violations = new java.util.ArrayList<>(structuralViolationCodes());
        if (!violations.isEmpty()) {
            return List.copyOf(violations);
        }
        for (var support : reactionSupports.values()) {
            if (englishWordCount(support.englishText()) > constraints.maxEnglishWords()
                    || support.englishText().length() > constraints.maxEnglishChars()
                    || support.chineseText().length() > constraints.maxChineseChars()
                    || !constraints.allowedDifficulties().contains(support.difficulty())) {
                violations.add("INVALID_REACTION_SUPPORT");
            }
        }
        return violations.stream().distinct().sorted().toList();
    }

    private static GeneratedCareUtterance support(
            String english,
            String chinese,
            String pronunciation,
            String tprAction,
            String delivery
    ) {
        return new GeneratedCareUtterance(english, chinese, pronunciation, tprAction, delivery, "starter");
    }

    private static int englishWordCount(String value) {
        return value.trim().split("\\s+").length;
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
