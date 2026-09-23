package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Action.EMERGENCY;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN;
import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class CustomSceneEmergencyRuleClassifierTest {

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();
    private final CustomSceneEmergencyRuleClassifier classifier = new CustomSceneEmergencyRuleClassifier();

    @Test
    void urgentCurrentSymptomsWinEvenAfterRolePlayPrefix() {
        var result = classifier.classify(canonicalizer.derive("玩医生游戏，但宝宝现在喘不过气，嘴唇发青"));
        assertThat(result).contains(new CustomSceneSafetyAssessment(
                REAL_HEALTH_CONCERN, EMERGENCY,
                "health-emergency-v1", "health-safety-v1"));
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "宝宝现在呼吸困难",
            "宝宝喘不过气",
            "宝宝打完预防针后喘不过气",
            "什么是呼吸困难（宝宝现在喘不过气）",
            "没想到宝宝喘不过气",
            "玩医生游戏但宝宝现在喘不过气",
            "故事里宝宝抽搐但现在又抽搐",
            "宝宝嘴唇发青",
            "孩子嘴唇青紫",
            "宝宝现在叫不醒",
            "宝宝刚刚抽搐",
            "宝宝疑似吞服了药物",
            "孩子误食了清洁剂",
            "宝宝吐绿色的东西",
            "儿童绿色呕吐"
    })
    void eachExplicitEmergencySignalReturnsEmergencyAssessment(String text) {
        assertThat(classifier.classify(canonicalizer.derive(text)))
                .contains(new CustomSceneSafetyAssessment(
                        REAL_HEALTH_CONCERN, EMERGENCY,
                        "health-emergency-v1", "health-safety-v1"));
    }

    @Test
    void currentSymptomAfterNegatedEarlierSymptomStillWins() {
        assertThat(classifier.classify(canonicalizer.derive("宝宝没有呼吸困难，但现在又喘不过气")))
                .contains(new CustomSceneSafetyAssessment(
                        REAL_HEALTH_CONCERN, EMERGENCY,
                        "health-emergency-v1", "health-safety-v1"));
    }

    @Test
    void currentSymptomAfterNegatedSymptomWithContrastStillWins() {
        assertThat(classifier.classify(canonicalizer.derive("宝宝没有呼吸困难却喘不过气")))
                .contains(new CustomSceneSafetyAssessment(
                        REAL_HEALTH_CONCERN, EMERGENCY,
                        "health-emergency-v1", "health-safety-v1"));
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "玩医生游戏",
            "已经康复了，想玩积木",
            "宝宝没有呼吸困难",
            "宝宝没有呼吸困难、喘不过气",
            "宝宝不喘不过气",
            "宝宝不再喘不过气了",
            "不知道是不是喘不过气",
            "不知道有没有喘不过气",
            "宝宝有没有呼吸困难？",
            "宝宝是不是喘不过气？",
            "宝宝曾经有过呼吸困难",
            "故事里宝宝抽搐，现实没有",
            "“宝宝呼吸困难”只是故事",
            "宝宝曾经嘴唇发青，现在已经好了",
            "宝宝呼吸困难，现在已经好了",
            "宝宝呼吸困难但现在已经好了",
            "什么是呼吸困难？",
            "如何预防中毒？",
            "宝宝哭闹，要抱抱，没有身体不适"
    })
    void fictionalRecoveredNegatedAndOrdinaryTextDoesNotTriggerHardRule(String text) {
        assertThat(classifier.classify(canonicalizer.derive(text))).isEmpty();
    }

    @Test
    void classifierAssessmentDoesNotExposeInputText() {
        var result = classifier.classify(canonicalizer.derive("宝宝现在呼吸困难，秘密编号-123"));
        assertThat(result).isPresent();
        assertThat(result.orElseThrow().toString()).doesNotContain("秘密编号", "123");
    }
}
