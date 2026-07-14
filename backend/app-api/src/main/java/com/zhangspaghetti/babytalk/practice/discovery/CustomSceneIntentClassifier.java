package com.zhangspaghetti.babytalk.practice.discovery;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class CustomSceneIntentClassifier {

    private final PracticeDiscoveryPolicyProperties policyProperties;
    private final PolicyTextMatcher policyTextMatcher;

    @Autowired
    public CustomSceneIntentClassifier(
            PracticeDiscoveryPolicyProperties policyProperties,
            PolicyTextMatcher policyTextMatcher
    ) {
        this.policyProperties = policyProperties;
        this.policyTextMatcher = policyTextMatcher;
    }

    public CustomSceneIntentClassifier(PracticeDiscoveryPolicyProperties policyProperties) {
        this(policyProperties, new PolicyTextMatcher(new SceneTextCanonicalizer()));
    }

    public List<ClassifiedSceneIntent> classifyAll(String normalizedSceneText) {
        return policyProperties.sceneIntents().entrySet().stream()
                .filter(entry -> policyTextMatcher.containsAny(normalizedSceneText, entry.getValue().requestMarkers()))
                .map(entry -> new ClassifiedSceneIntent(entry.getKey(), entry.getValue().outputMarkers()))
                .toList();
    }

    public boolean matchesOutput(ClassifiedSceneIntent intent, String normalizedOutput) {
        return intent != null && policyTextMatcher.containsAny(normalizedOutput, intent.outputMarkers());
    }

    public record ClassifiedSceneIntent(String key, List<String> outputMarkers) {
    }
}
