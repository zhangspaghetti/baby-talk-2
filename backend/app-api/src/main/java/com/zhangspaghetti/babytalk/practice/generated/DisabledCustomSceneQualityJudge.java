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
public class DisabledCustomSceneQualityJudge implements CustomSceneQualityJudge {

    @Override
    public com.zhangspaghetti.babytalk.practice.generated.quality.SuggestedJudgeResult judge(JudgeRequest request) {
        throw new CustomSceneGenerator.GenerationUnavailableException(
                CustomSceneGenerator.GenerationUnavailableReason.PROVIDER_DISABLED);
    }
}
