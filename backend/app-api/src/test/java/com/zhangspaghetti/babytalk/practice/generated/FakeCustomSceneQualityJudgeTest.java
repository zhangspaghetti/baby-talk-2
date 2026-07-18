package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneQualityJudge.JudgeRequest;
import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import java.lang.reflect.Modifier;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class FakeCustomSceneQualityJudgeTest {

    @Test
    void deterministicFakePassHasNoRunnerAuditOrNetworkDependencies() {
        assertThat(FakeCustomSceneQualityJudge.class.getDeclaredFields())
                .filteredOn(field -> !Modifier.isStatic(field.getModifiers()))
                .isEmpty();
        var judge = new FakeCustomSceneQualityJudge();

        var first = judge.judge(request());
        var second = judge.judge(request());

        assertThat(first).isEqualTo(second);
        assertThat(first.suggestedVerdict()).isEqualTo(JudgeVerdict.PASS);
        assertThat(first.dimensionResults())
                .containsOnlyKeys(JudgeDimension.values())
                .allSatisfy((dimension, result) -> assertThat(result).isEqualTo(DimensionResult.PASS));
        assertThat(first.violationCodes()).isEmpty();
        assertThat(first.repairDirectives()).isEmpty();
        assertThat(first.evidenceGapCodes()).isEmpty();
    }

    private JudgeRequest request() {
        return new JudgeRequest(
                "pgc_fake_judge",
                1,
                UUID.fromString("10000000-0000-0000-0000-000000000001"),
                "给宝宝穿鞋",
                "m7_11",
                "calmer_care",
                new GeneratedPracticeContentCandidate(
                        "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说。",
                        "Shoes on.", "穿鞋出门。", "shoes on", "starter", "fake"),
                List.of("fake-strategy-v1"),
                List.of("joint_attention"),
                List.of("m7_11_short_phrase"),
                List.of("low_pressure"),
                List.of("先轻声说。"),
                "rubric-v1",
                "9".repeat(64));
    }
}
