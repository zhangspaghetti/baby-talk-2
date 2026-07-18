package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.env.StandardEnvironment;

class PracticeDiscoveryPolicyPropertiesTest {

    @Test
    void productionPolicyLivesInDedicatedClasspathYamlAndBindsTypedValues() throws Exception {
        var resource = new ClassPathResource("config/practice-discovery-policy.yml");
        assertThat(resource.exists()).isTrue();
        assertThat(Arrays.stream(PracticeDiscoveryPolicyProperties.class.getRecordComponents())
                .map(component -> component.getName()))
                .contains("policyVersion");

        var environment = new StandardEnvironment();
        var sources = new YamlPropertySourceLoader().load("practice-discovery-policy", resource);
        for (var source : sources) {
            environment.getPropertySources().addFirst(source);
        }
        var properties = Binder.get(environment)
                .bind("babytalk.practice.discovery.policy", Bindable.of(PracticeDiscoveryPolicyProperties.class))
                .orElseThrow(() -> new AssertionError("practice discovery policy did not bind"));

        assertThat(properties.policyVersion()).isEqualTo("policy-v2");
        assertThat(properties.promptInjectionMarkers()).contains("system prompt", "系统提示");
        assertThat(properties.validatorPiiMarkers()).contains("微信", "qq", "住址");
        assertThat(properties.validatorDangerousMedicalCommandPatterns())
                .anyMatch(pattern -> pattern.contains("give|giving"))
                .contains("按(?:医生建议|处方|说明书)?(?:的)?剂量");
        assertThat(properties.validatorDangerousMedicalNegationPatterns())
                .anyMatch(pattern -> pattern.contains("do\\s+not"))
                .anyMatch(pattern -> pattern.contains("不要"));
        assertThat(properties.validatorTprActionMarkers()).contains("pick up", "拿起", "坐稳");
        assertThat(properties.validatorDeliveryGuidanceMarkers()).contains("slowly", "慢慢", "等宝宝");
        assertThat(properties.compiledBabyNamePattern().matcher("宝宝名字是小满").find()).isTrue();
        assertThat(properties.compiledPhonePattern().matcher("١٣٨٠٠١٣٨٠٠٠").find()).isTrue();
    }

    @Test
    void missingPolicyListsFailInsteadOfFallingBackToJavaDefaults() {
        assertThatThrownBy(() -> new PracticeDiscoveryPolicyProperties(
                null, null, null, null, null, null, null, null, null,
                null, null, null, null, null, null, null, null, null, null, null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void listsAreTrimmedLowercasedAndInvalidRegexFailsFast() {
        var fixture = PracticeDiscoveryPolicyTestFixture.properties();
        var normalized = new PracticeDiscoveryPolicyProperties(
                " policy-v2 ",
                fixture.babyNamePattern(),
                fixture.phonePattern(),
                fixture.emailPattern(),
                List.of(" PHONE "),
                List.of(" SYSTEM PROMPT "),
                fixture.unsupportedIntents(),
                fixture.careContextMarkers(),
                fixture.generatedCareKeywords(),
                fixture.validatorBlockedFraming(),
                fixture.validatorMedicalLegal(),
                fixture.validatorDangerousMedicalCommandPatterns(),
                fixture.validatorDangerousMedicalNegationPatterns(),
                fixture.validatorAdultViolentSexual(),
                fixture.validatorUnsupportedClaims(),
                fixture.validatorUnsuitable03(),
                fixture.validatorPromptEcho(),
                fixture.validatorTprActionMarkers(),
                fixture.validatorDeliveryGuidanceMarkers(),
                fixture.sceneIntents());

        assertThat(normalized.policyVersion()).isEqualTo("policy-v2");
        assertThat(normalized.piiMarkers()).containsExactly("phone");
        assertThat(normalized.promptInjectionMarkers()).containsExactly("system prompt");
        assertThatThrownBy(() -> new PracticeDiscoveryPolicyProperties(
                "policy-v2", "[", fixture.phonePattern(), fixture.emailPattern(),
                fixture.piiMarkers(), fixture.promptInjectionMarkers(),
                fixture.unsupportedIntents(), fixture.careContextMarkers(), fixture.generatedCareKeywords(),
                fixture.validatorBlockedFraming(), fixture.validatorMedicalLegal(),
                fixture.validatorDangerousMedicalCommandPatterns(),
                fixture.validatorDangerousMedicalNegationPatterns(),
                fixture.validatorAdultViolentSexual(), fixture.validatorUnsupportedClaims(),
                fixture.validatorUnsuitable03(), fixture.validatorPromptEcho(),
                fixture.validatorTprActionMarkers(), fixture.validatorDeliveryGuidanceMarkers(),
                fixture.sceneIntents()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("babyNamePattern");
    }

    @Test
    void policyVersionLongerThanDatabaseColumnFailsFast() {
        var fixture = PracticeDiscoveryPolicyTestFixture.properties();
        assertThatThrownBy(() -> new PracticeDiscoveryPolicyProperties(
                "p".repeat(49),
                fixture.babyNamePattern(), fixture.phonePattern(), fixture.emailPattern(),
                fixture.piiMarkers(), fixture.promptInjectionMarkers(), fixture.unsupportedIntents(),
                fixture.careContextMarkers(), fixture.generatedCareKeywords(), fixture.validatorBlockedFraming(),
                fixture.validatorMedicalLegal(), fixture.validatorDangerousMedicalCommandPatterns(),
                fixture.validatorDangerousMedicalNegationPatterns(),
                fixture.validatorAdultViolentSexual(),
                fixture.validatorUnsupportedClaims(), fixture.validatorUnsuitable03(),
                fixture.validatorPromptEcho(), fixture.validatorTprActionMarkers(),
                fixture.validatorDeliveryGuidanceMarkers(), fixture.sceneIntents()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("policyVersion");
    }

    @Test
    void invalidDangerousMedicalPatternFailsClosed() {
        var fixture = PracticeDiscoveryPolicyTestFixture.properties();

        assertThatThrownBy(() -> new PracticeDiscoveryPolicyProperties(
                fixture.policyVersion(), fixture.babyNamePattern(), fixture.phonePattern(), fixture.emailPattern(),
                fixture.piiMarkers(), fixture.promptInjectionMarkers(), fixture.unsupportedIntents(),
                fixture.careContextMarkers(), fixture.generatedCareKeywords(), fixture.validatorBlockedFraming(),
                fixture.validatorMedicalLegal(), List.of("["), fixture.validatorDangerousMedicalNegationPatterns(),
                fixture.validatorAdultViolentSexual(), fixture.validatorUnsupportedClaims(),
                fixture.validatorUnsuitable03(), fixture.validatorPromptEcho(), fixture.validatorTprActionMarkers(),
                fixture.validatorDeliveryGuidanceMarkers(), fixture.sceneIntents()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("validatorDangerousMedicalCommandPatterns");
    }

    @Test
    void careContextMarkersNeedNotBelongToASceneIntent() {
        var fixture = PracticeDiscoveryPolicyTestFixture.properties();

        var properties = new PracticeDiscoveryPolicyProperties(
                fixture.policyVersion(), fixture.babyNamePattern(), fixture.phonePattern(), fixture.emailPattern(),
                fixture.piiMarkers(), fixture.promptInjectionMarkers(), fixture.unsupportedIntents(),
                List.of("unclassified-care-marker"), fixture.generatedCareKeywords(),
                fixture.validatorBlockedFraming(), fixture.validatorMedicalLegal(),
                fixture.validatorDangerousMedicalCommandPatterns(),
                fixture.validatorDangerousMedicalNegationPatterns(),
                fixture.validatorAdultViolentSexual(), fixture.validatorUnsupportedClaims(),
                fixture.validatorUnsuitable03(), fixture.validatorPromptEcho(),
                fixture.validatorTprActionMarkers(), fixture.validatorDeliveryGuidanceMarkers(),
                fixture.sceneIntents());

        assertThat(properties.careContextMarkers()).containsExactly("unclassified-care-marker");
    }

    @Test
    void careContextMarkersAllowSingleCharacterFamilyReference() {
        assertThat(PracticeDiscoveryPolicyTestFixture.properties().careContextMarkers())
                .contains("娃");
    }
}
