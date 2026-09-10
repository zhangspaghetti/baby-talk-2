package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.agentic.config.VersionedRef;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.RepairDirective;
import com.zhangspaghetti.babytalk.practice.generated.quality.TypedRepairPackage;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class FakeCustomSceneRepairerTest {

    @Test
    void preservesCompleteBundleAndRecordsFakeRepairProvenance() {
        var previous = new SceneContentGenerator.GeneratedPracticeContentCandidate(
                "日常照护", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说一遍。", "Shoes on.", "穿鞋出门。",
                "shoes on", "starter", "agentic_search");
        var previousBundle = GeneratedCareMomentBundle.fakeFixture(previous).completeBundle();
        var request = new CustomSceneRepairer.RepairRequest(
                "pgc_fake_repair", 2, UUID.randomUUID(), "zh-CN",
                SceneContentGenerator.ContentConstraints.fakeProviderDefaults(),
                new TypedRepairPackage(
                        "给宝宝穿鞋", "m7_11", "calmer_care", previousBundle, JudgeVerdict.REPAIR,
                        List.of(JudgeDimension.TPR_QUALITY, JudgeDimension.DELIVERY_GUIDANCE_QUALITY),
                        List.of("MISSING_TPR_ACTION", "MISSING_DELIVERY_GUIDANCE"),
                        List.of(),
                        List.of(RepairDirective.REPAIR_TPR_QUALITY, RepairDirective.REPAIR_DELIVERY_GUIDANCE_QUALITY),
                        List.of(), profile()));

        var repairedBundle = new FakeCustomSceneRepairer().repairCareMoment(request);
        var repaired = repairedBundle.starter();
        var repairedStarter = repairedBundle.starterUtterance();

        assertThat(repaired.spaceTitleZh()).isEqualTo(previous.spaceTitleZh());
        assertThat(repaired.englishText()).isEqualTo(previous.englishText());
        assertThat(repaired.tprActionZh()).isNotBlank();
        assertThat(repaired.deliveryGuidanceZh()).isNotBlank();
        assertThat(repaired.generationSource()).isEqualTo("fake");
        assertThat(repairedStarter.providerProvenance().origin().wireValue()).isEqualTo("provider_repaired");
        assertThat(repairedStarter.providerProvenance().providerName()).isEqualTo("fake");
    }

    private static GenerationProfile profile() {
        return new GenerationProfile(
                "profile-v1", "p".repeat(64),
                new VersionedRef("generator-v1", "a".repeat(64), "generator.txt"),
                new VersionedRef("judge-v1", "c".repeat(64), "judge.txt"),
                new VersionedRef("repair-v1", "d".repeat(64), "repair.txt"),
                new VersionedRef("rubric-v1", "r".repeat(64), "rubric.yml"),
                new VersionedRef("evidence-v1", "e".repeat(64), "evidence.yml"),
                new VersionedRef("baseline-v1", "b".repeat(64), "baseline.yml"),
                "strategy-v1", "safety-v1", "schema-v1");
    }
}
