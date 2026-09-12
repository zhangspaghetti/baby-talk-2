package com.zhangspaghetti.babytalk.practice.discovery;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Shared custom-scene input length and intent validation. */
@Component
public final class CustomSceneTextValidator {

    public static final int MIN_CUSTOM_SCENE_GRAPHEMES = 4;
    public static final int MAX_CUSTOM_SCENE_GRAPHEMES = 80;
    public static final int MAX_CUSTOM_SCENE_CODE_POINTS = 160;

    private final SceneTextCanonicalizer canonicalizer;
    private final PolicyTextMatcher policyTextMatcher;
    private final PracticeDiscoveryPolicyProperties policyProperties;

    public CustomSceneTextValidator(
            SceneTextCanonicalizer canonicalizer,
            PolicyTextMatcher policyTextMatcher,
            PracticeDiscoveryPolicyProperties policyProperties
    ) {
        this.canonicalizer = canonicalizer;
        this.policyTextMatcher = policyTextMatcher;
        this.policyProperties = policyProperties;
    }

    public String requireValid(SceneTextForms forms) {
        var displayText = forms == null ? null : forms.displayText();
        if (displayText == null
                || canonicalizer.graphemeLength(displayText) < MIN_CUSTOM_SCENE_GRAPHEMES
                || canonicalizer.graphemeLength(displayText) > MAX_CUSTOM_SCENE_GRAPHEMES
                || canonicalizer.codePointLength(displayText) > MAX_CUSTOM_SCENE_CODE_POINTS) {
            throw invalidCustomSceneText();
        }
        if (policyTextMatcher.containsAny(displayText, policyProperties.unsupportedIntents())) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "unsupported_custom_scene_text",
                    "customSceneText 需要是照护场景。",
                    Map.of("reason", "unsupported_intent"));
        }
        return displayText;
    }

    private ContractException invalidCustomSceneText() {
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                "invalid_custom_scene_text",
                "customSceneText 长度不合法。",
                Map.of(
                        "min", MIN_CUSTOM_SCENE_GRAPHEMES,
                        "max", MAX_CUSTOM_SCENE_GRAPHEMES));
    }
}
