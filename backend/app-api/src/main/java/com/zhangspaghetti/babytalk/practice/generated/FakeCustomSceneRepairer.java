package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.util.Objects;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile({"dev", "test"})
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "fake"
)
public class FakeCustomSceneRepairer implements CustomSceneRepairer {

    private static final String FALLBACK_TPR_ACTION = "停一下，给宝宝一点时间。";
    private static final String FALLBACK_DELIVERY_GUIDANCE = "轻声说短句，等宝宝看过来再重复。";

    @Override
    public GeneratedCareMomentBundle repairCareMoment(RepairRequest request) {
        Objects.requireNonNull(request, "request");
        var repaired = request.repairPackage().previousBundle().utterances().stream()
                .map(utterance -> new CompleteGeneratedBundle.Utterance(
                        utterance.role(),
                        utterance.reaction(),
                        utterance.englishText(),
                        utterance.chineseText(),
                        utterance.pronunciationHint(),
                        required(utterance.tprActionZh(), FALLBACK_TPR_ACTION),
                        required(utterance.deliveryGuidanceZh(), FALLBACK_DELIVERY_GUIDANCE),
                        utterance.difficulty(),
                        utterance.displayOrder(),
                        new CompleteGeneratedBundle.ProviderProvenance(
                                CompleteGeneratedBundle.ProviderOrigin.PROVIDER_REPAIRED,
                                "fake",
                                "deterministic",
                                request.attemptNumber())))
                .toList();
        return GeneratedCareMomentBundle.fromCompleteBundle(new CompleteGeneratedBundle(
                request.repairPackage().previousBundle().schemaVersion(),
                request.repairPackage().previousBundle().scene(),
                repaired));
    }

    private String required(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }
}
