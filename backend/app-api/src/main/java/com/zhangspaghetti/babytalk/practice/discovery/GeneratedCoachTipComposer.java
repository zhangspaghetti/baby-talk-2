package com.zhangspaghetti.babytalk.practice.discovery;

import java.util.List;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public final class GeneratedCoachTipComposer {

    private static final Pattern GRAPHEME = Pattern.compile("\\X");

    public CompositionPolicy compositionPolicy(int maxCombinedGraphemes) {
        return new CompositionPolicy(
                maxCombinedGraphemes,
                List.of(
                        "trim both fields",
                        "omit missing fields",
                        "deduplicate equal fields",
                        "otherwise join with one space"),
                "grapheme",
                true);
    }

    public String compose(String tprActionZh, String deliveryGuidanceZh) {
        var action = trimToNull(tprActionZh);
        var guidance = trimToNull(deliveryGuidanceZh);
        if (action == null) {
            return guidance;
        }
        if (guidance == null || action.equals(guidance)) {
            return action;
        }
        return action + " " + guidance;
    }

    public int graphemeLength(String tprActionZh, String deliveryGuidanceZh) {
        var composed = compose(tprActionZh, deliveryGuidanceZh);
        if (composed == null) {
            return 0;
        }
        var matcher = GRAPHEME.matcher(composed);
        var count = 0;
        while (matcher.find()) {
            count++;
        }
        return count;
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        var trimmed = value.strip();
        return trimmed.isEmpty() ? null : trimmed;
    }

    public record CompositionPolicy(
            int maxCombinedGraphemes,
            List<String> compositionRules,
            String lengthUnit,
            boolean preserveMeaningWithoutTruncation
    ) {
    }
}
