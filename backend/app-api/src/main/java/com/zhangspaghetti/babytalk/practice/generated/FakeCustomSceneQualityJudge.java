package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.SuggestedJudgeResult;
import java.util.EnumMap;
import java.util.List;
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
public class FakeCustomSceneQualityJudge implements CustomSceneQualityJudge {

    @Override
    public SuggestedJudgeResult judge(JudgeRequest request) {
        Objects.requireNonNull(request, "request");
        var dimensions = new EnumMap<JudgeDimension, DimensionResult>(JudgeDimension.class);
        for (var dimension : JudgeDimension.values()) {
            dimensions.put(dimension, DimensionResult.PASS);
        }
        return new SuggestedJudgeResult(
                JudgeVerdict.PASS,
                dimensions,
                List.of(),
                List.of(),
                List.of(),
                1.0d);
    }
}
