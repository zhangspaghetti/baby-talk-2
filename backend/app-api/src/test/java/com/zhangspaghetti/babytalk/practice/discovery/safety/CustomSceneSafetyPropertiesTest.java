package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.core.io.ClassPathResource;

class CustomSceneSafetyPropertiesTest {

    @Test
    void defaultPolicyIsVersionedWithThreeSecondClassifierBudgetAndFiveTemplates() {
        var properties = CustomSceneSafetyProperties.defaults();

        assertThat(properties.policyVersion()).isEqualTo("health-safety-v1");
        assertThat(properties.classifierTimeout()).isEqualTo(Duration.ofSeconds(3));
        assertThat(properties.templates()).hasSize(5);
        assertThat(properties.emergencySignals()).containsKeys(
                "breathing-difficulty",
                "blue-lips",
                "cannot-wake",
                "seizure",
                "suspected-poisoning",
                "child-green-vomit");
    }

    @Test
    void policyValuesAreDefensivelyCopied() {
        var properties = CustomSceneSafetyProperties.defaults();

        assertThat(properties.templates()).isUnmodifiable();
        assertThat(properties.emergencySignals()).isUnmodifiable();
        assertThat(properties.emergencySignals().get("seizure")).isUnmodifiable();
    }

    @Test
    void blankPolicyVersionIsRejected() {
        var defaults = CustomSceneSafetyProperties.defaults();

        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                " ", defaults.classifierTimeout(), defaults.templates(), defaults.emergencySignals()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("policy version");
    }

    @Test
    void nonPositiveClassifierTimeoutIsRejected() {
        var defaults = CustomSceneSafetyProperties.defaults();

        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                defaults.policyVersion(), Duration.ZERO, defaults.templates(), defaults.emergencySignals()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("classifier timeout");
    }

    @Test
    void policyVersionAndApprovedKeysAreLocked() {
        var defaults = CustomSceneSafetyProperties.defaults();

        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                "health-safety-v2", defaults.classifierTimeout(), defaults.templates(), defaults.emergencySignals()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("policy version");

        var unknownTemplate = new LinkedHashMap<>(defaults.templates());
        unknownTemplate.put("health-future-v1", defaults.templates().get("health-concern-v1"));
        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                defaults.policyVersion(), defaults.classifierTimeout(), unknownTemplate, defaults.emergencySignals()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("template");

        var missingTemplate = new LinkedHashMap<>(defaults.templates());
        missingTemplate.remove("health-concern-v1");
        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                defaults.policyVersion(), defaults.classifierTimeout(), missingTemplate, defaults.emergencySignals()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("template");

        var duplicateTemplate = new LinkedHashMap<String, CustomSceneSafetyProperties.Template>();
        duplicateTemplate.put("health-emergency-v1", defaults.templates().get("health-emergency-v1"));
        duplicateTemplate.put(" health-emergency-v1 ", defaults.templates().get("health-emergency-v1"));
        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                defaults.policyVersion(), defaults.classifierTimeout(), duplicateTemplate, defaults.emergencySignals()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("template");

        var unknownSignal = new LinkedHashMap<>(defaults.emergencySignals());
        unknownSignal.put("unknown-signal", List.of("未知信号"));
        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                defaults.policyVersion(), defaults.classifierTimeout(), defaults.templates(), unknownSignal))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("signal");

        var missingSignal = new LinkedHashMap<>(defaults.emergencySignals());
        missingSignal.remove("seizure");
        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                defaults.policyVersion(), defaults.classifierTimeout(), defaults.templates(), missingSignal))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("signal");

        var duplicateSignal = new LinkedHashMap<String, List<String>>();
        duplicateSignal.put("seizure", defaults.emergencySignals().get("seizure"));
        duplicateSignal.put(" seizure ", defaults.emergencySignals().get("seizure"));
        assertThatThrownBy(() -> new CustomSceneSafetyProperties(
                defaults.policyVersion(), defaults.classifierTimeout(), defaults.templates(), duplicateSignal))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("signal");
    }

    @Test
    void templateActionsAreRestrictedToApprovedValues() {
        assertThatThrownBy(() -> new CustomSceneSafetyProperties.Template(
                "unavailable", "zh-CN", "标题", "正文"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("action");
        assertThatThrownBy(() -> new CustomSceneSafetyProperties.Template(
                "safe", "zh-CN", "标题", "正文"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("action");
        assertThatThrownBy(() -> new CustomSceneSafetyProperties.Template(
                "EMERGENCY", "zh-CN", "标题", "正文"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("action");
    }

    @Test
    void approvedPolicyBindsFromProductionYaml() throws Exception {
        var resource = new ClassPathResource("config/practice-health-safety-v1.yml");
        assertThat(resource.exists()).isTrue();

        var environment = new StandardEnvironment();
        var sources = new YamlPropertySourceLoader().load("practice-health-safety-v1", resource);
        for (var source : sources) {
            environment.getPropertySources().addFirst(source);
        }
        var properties = Binder.get(environment)
                .bind("babytalk.practice.health-safety", Bindable.of(CustomSceneSafetyProperties.class))
                .orElseThrow(() -> new AssertionError("health safety policy did not bind"));

        assertThat(properties.policyVersion()).isEqualTo("health-safety-v1");
        assertThat(properties.classifierTimeout()).isEqualTo(Duration.ofSeconds(3));
        assertThat(properties.templates()).containsOnlyKeys(
                "health-emergency-v1",
                "health-concern-v1",
                "health-prompt-assessment-v1",
                "health-uncertain-v1",
                "health-assessment-unavailable-v1");
        assertThat(properties.templates().get("health-emergency-v1").action()).isEqualTo("emergency");
        assertThat(properties.templates().get("health-emergency-v1").titleZh()).isEqualTo("请立即寻求医疗帮助");
        assertThat(properties.templates().get("health-emergency-v1").messageZh())
                .isEqualTo("你描述的情况可能需要紧急处理。请立即联系当地急救服务，或前往急诊。不要等待本应用进一步回复。");
        assertThat(properties.templates().get("health-concern-v1").action()).isEqualTo("seek_medical_help");
        assertThat(properties.templates().get("health-concern-v1").titleZh()).isEqualTo("先关注宝宝的身体状况");
        assertThat(properties.templates().get("health-concern-v1").messageZh())
                .isEqualTo("你描述的是宝宝的健康问题。仅凭这段描述，无法判断原因或严重程度，请联系儿科医生进行评估。如果宝宝出现呼吸困难、叫不醒或抽搐，请立即联系当地急救服务。");
        assertThat(properties.templates().get("health-prompt-assessment-v1").action()).isEqualTo("seek_medical_help");
        assertThat(properties.templates().get("health-prompt-assessment-v1").titleZh()).isEqualTo("请尽快寻求医疗评估");
        assertThat(properties.templates().get("health-prompt-assessment-v1").messageZh())
                .isEqualTo("你描述的情况需要及时由医护人员评估，请现在联系儿科医生或就近医疗机构。如果宝宝出现呼吸困难、叫不醒或抽搐，请立即联系当地急救服务。");
        assertThat(properties.templates().get("health-uncertain-v1").action()).isEqualTo("uncertain");
        assertThat(properties.templates().get("health-uncertain-v1").titleZh()).isEqualTo("目前无法判断宝宝的状况");
        assertThat(properties.templates().get("health-uncertain-v1").messageZh())
                .isEqualTo("现有信息不足以判断宝宝的情况。请联系儿科医生说明你的担忧。如果你认为宝宝情况严重，或出现呼吸困难、叫不醒、抽搐，请立即寻求紧急医疗帮助。");
        assertThat(properties.templates().get("health-assessment-unavailable-v1").action()).isEqualTo("uncertain");
        assertThat(properties.templates().get("health-assessment-unavailable-v1").titleZh()).isEqualTo("暂时无法判断这段描述");
        assertThat(properties.templates().get("health-assessment-unavailable-v1").messageZh())
                .isEqualTo("暂时无法完成判断，已暂停生成。如果你正在担心宝宝身体不适，请联系儿科医生；如果情况紧急，请立即联系当地急救服务。");
        assertThat(properties.emergencySignals()).containsOnlyKeys(
                "breathing-difficulty", "blue-lips", "cannot-wake", "seizure", "suspected-poisoning", "child-green-vomit");
        assertThat(properties.emergencySignals().get("breathing-difficulty")).contains("呼吸困难", "喘不过气");
        assertThat(properties.emergencySignals().get("blue-lips")).contains("嘴唇发青", "嘴唇青紫");
        assertThat(properties.emergencySignals().get("cannot-wake")).contains("叫不醒", "无法唤醒");
        assertThat(properties.emergencySignals().get("seizure")).contains("抽搐");
        assertThat(properties.emergencySignals().get("suspected-poisoning")).contains("疑似吞服", "误食");
        assertThat(properties.emergencySignals().get("child-green-vomit")).contains("绿色呕吐", "吐绿色");
    }
}
