package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class HealthSafetyTemplateRegistryTest {

    private final HealthSafetyTemplateRegistry registry = new HealthSafetyTemplateRegistry();

    @Test
    void templatesAreChineseFixedCopyAndContainNoTreatmentFields() {
        var template = registry.template("health-concern-v1");
        assertThat(template.locale()).isEqualTo("zh-CN");
        assertThat(template.titleZh()).isEqualTo("先关注宝宝的身体状况");
        assertThat(template.messageZh()).contains("请联系儿科医生进行评估");
        assertThat(template.messageZh()).doesNotContain("剂量", "服用", "诊断为");
    }

    @Test
    void registryContainsAllApprovedVersionedTemplates() {
        assertThat(registry.templateIds()).containsExactlyInAnyOrder(
                "health-emergency-v1",
                "health-concern-v1",
                "health-prompt-assessment-v1",
                "health-uncertain-v1",
                "health-assessment-unavailable-v1");

        assertThat(registry.template("health-emergency-v1").titleZh())
                .isEqualTo("请立即寻求医疗帮助");
        assertThat(registry.template("health-prompt-assessment-v1").titleZh())
                .isEqualTo("请尽快寻求医疗评估");
        assertThat(registry.template("health-uncertain-v1").titleZh())
                .isEqualTo("目前无法判断宝宝的状况");
        assertThat(registry.template("health-assessment-unavailable-v1").titleZh())
                .isEqualTo("暂时无法判断这段描述");
    }

    @Test
    void registryUsesOnlyApprovedActionsAndExactUnavailableCopy() {
        assertThat(registry.template("health-emergency-v1").action()).isEqualTo("emergency");
        assertThat(registry.template("health-concern-v1").action()).isEqualTo("seek_medical_help");
        assertThat(registry.template("health-prompt-assessment-v1").action()).isEqualTo("seek_medical_help");
        assertThat(registry.template("health-uncertain-v1").action()).isEqualTo("uncertain");
        assertThat(registry.template("health-assessment-unavailable-v1").action()).isEqualTo("uncertain");
        assertThat(registry.template("health-assessment-unavailable-v1").messageZh())
                .isEqualTo("暂时无法完成判断，已暂停生成。如果你正在担心宝宝身体不适，请联系儿科医生；如果情况紧急，请立即联系当地急救服务。");
    }

    @Test
    void registryExposesImmutableTemplateSet() {
        assertThat(registry.templateIds()).isUnmodifiable();
    }
}
