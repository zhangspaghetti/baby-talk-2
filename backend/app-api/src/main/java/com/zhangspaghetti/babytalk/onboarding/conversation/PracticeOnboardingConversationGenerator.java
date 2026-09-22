package com.zhangspaghetti.babytalk.onboarding.conversation;

import java.util.Map;
import java.util.Objects;
import org.springframework.stereotype.Component;

/**
 * Server-curated onboarding copy. Guest onboarding must remain usable before a profile exists,
 * so it deliberately has no dependency on scene generation or an AI provider.
 */
@Component
public class PracticeOnboardingConversationGenerator implements OnboardingConversationGenerator {

    private static final Map<String, SceneScript> SERVER_SCENES = Map.of(
            "bedtime", new SceneScript("bedtime",
                    "Time for bed.", "该睡觉啦。", "time for bed",
                    Map.of(
                            "cooperating", utterance("Great job together.", "我们一起做得很好。", "great job together"),
                            "hesitant", utterance("You can try slowly.", "你可以慢慢试。", "you can try slowly"),
                            "resisting", utterance("It is okay to pause.", "可以先停一下。", "it is okay to pause"),
                            "no_response", utterance("I will wait with you.", "我陪你等一等。", "i will wait with you"),
                            "other", utterance("We can take a pause.", "我们先停一会儿。", "we can take a pause"))),
            "feeding", new SceneScript("feeding",
                    "Let's eat.", "我们吃饭吧。", "lets eat",
                    commonSupports()),
            "post_cry", new SceneScript("post_cry",
                    "I am here with you.", "我陪着你。", "i am here with you",
                    commonSupports()),
            "diaper_change", new SceneScript("diaper_change",
                    "Let's change your diaper.", "我们换尿布吧。", "lets change your diaper",
                    commonSupports()));

    @Override
    public GeneratedUtterance generate(GenerationRequest request) {
        var scene = scene(request == null ? null : request.sceneKey());
        return scene.starter();
    }

    @Override
    public GeneratedUtterance generateNext(NextGenerationRequest request) {
        var scene = scene(request == null ? null : request.sceneKey());
        var reaction = request != null && request.reactionProvided() && request.reaction() != null
                ? request.reaction()
                : "no_response";
        var selected = scene.supports().get(reaction);
        if (selected == null) {
            throw new IllegalArgumentException("unsupported onboarding reaction");
        }
        return new GeneratedUtterance(
                scene.generatedContentId(),
                scene.generatedContentId() + "_" + reaction,
                selected.englishText(),
                selected.chineseText(),
                selected.pronunciationHint(),
                null);
    }

    private SceneScript scene(String sceneKey) {
        var scene = SERVER_SCENES.get(sceneKey);
        if (scene == null) {
            throw new IllegalArgumentException("unsupported server-owned onboarding scene");
        }
        return scene;
    }

    private static Map<String, CuratedUtterance> commonSupports() {
        return Map.of(
                "cooperating", utterance("Great job together.", "我们一起做得很好。", "great job together"),
                "hesitant", utterance("You can try slowly.", "你可以慢慢试。", "you can try slowly"),
                "resisting", utterance("It is okay to pause.", "可以先停一下。", "it is okay to pause"),
                "no_response", utterance("I will wait with you.", "我陪你等一等。", "i will wait with you"),
                "other", utterance("We can take a pause.", "我们先停一会儿。", "we can take a pause"));
    }

    private static CuratedUtterance utterance(String englishText, String chineseText, String pronunciationHint) {
        return new CuratedUtterance(englishText, chineseText, pronunciationHint);
    }

    private record SceneScript(
            String sceneKey,
            String starterEnglish,
            String starterChinese,
            String starterPronunciation,
            Map<String, CuratedUtterance> supports
    ) {
        private SceneScript {
            Objects.requireNonNull(supports, "supports");
        }

        private String generatedContentId() {
            return "onboarding_" + sceneKey;
        }

        private GeneratedUtterance starter() {
            var generatedContentId = generatedContentId();
            return new GeneratedUtterance(
                    generatedContentId,
                    generatedContentId + "_starter",
                    starterEnglish,
                    starterChinese,
                    starterPronunciation,
                    null);
        }
    }

    private record CuratedUtterance(String englishText, String chineseText, String pronunciationHint) {
    }
}
