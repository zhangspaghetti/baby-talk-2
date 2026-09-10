package com.zhangspaghetti.babytalk.practice.discovery;

import com.zhangspaghetti.babytalk.practice.generated.SceneContentGenerator;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

@Service
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "disabled",
        matchIfMissing = true
)
public class DisabledSceneContentGenerator implements SceneContentGenerator {

    @Override
    public com.zhangspaghetti.babytalk.practice.generated.GeneratedCareMomentBundle generateCareMoment(
            GeneratorRequest request
    ) {
        throw new GenerationUnavailableException(GenerationUnavailableReason.PROVIDER_DISABLED);
    }
}
