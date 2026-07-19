package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
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
    public GeneratedPracticeContentCandidate repair(RepairRequest request) {
        Objects.requireNonNull(request, "request");
        var previous = request.repairPackage().previousCandidate();
        return new GeneratedPracticeContentCandidate(
                required(previous.spaceTitleZh(), "日常照护"),
                required(previous.activityTitleZh(), "温和练习"),
                required(previous.sceneTagEn(), "Gentle care"),
                required(previous.tprActionZh(), FALLBACK_TPR_ACTION),
                required(previous.deliveryGuidanceZh(), FALLBACK_DELIVERY_GUIDANCE),
                required(previous.englishText(), "Gentle care."),
                required(previous.chineseText(), "温和照护。"),
                required(previous.pronunciationHint(), "gentle care"),
                required(previous.difficulty(), "starter"),
                "fake");
    }

    private String required(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }
}
