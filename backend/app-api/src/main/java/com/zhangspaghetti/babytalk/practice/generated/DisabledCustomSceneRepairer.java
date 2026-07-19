package com.zhangspaghetti.babytalk.practice.generated;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "disabled",
        matchIfMissing = true
)
public class DisabledCustomSceneRepairer implements CustomSceneRepairer {

    @Override
    public CustomSceneGenerator.GeneratedPracticeContentCandidate repair(RepairRequest request) {
        throw new CustomSceneGenerator.GenerationUnavailableException(
                CustomSceneGenerator.GenerationUnavailableReason.PROVIDER_DISABLED);
    }
}
