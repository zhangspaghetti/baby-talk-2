package com.zhangspaghetti.babytalk.practice.discovery;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "disabled",
        matchIfMissing = true
)
public class DisabledCustomSceneGenerationService implements CustomSceneGenerationService {

    @Override
    public GeneratedPracticeContentCandidate generateCustomSceneStarter(CustomSceneGenerationRequest request) {
        throw new GenerationUnavailableException(GenerationUnavailableReason.PROVIDER_DISABLED);
    }
}
