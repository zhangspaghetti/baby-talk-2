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
    public GeneratedCareMomentBundle repairCareMoment(RepairRequest request) {
        throw new SceneContentGenerator.GenerationUnavailableException(
                SceneContentGenerator.GenerationUnavailableReason.PROVIDER_DISABLED);
    }
}
