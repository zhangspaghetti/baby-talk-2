package com.zhangspaghetti.babytalk.practice.discovery;

import com.ibm.icu.text.SpoofChecker;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.util.stream.Stream;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public final class SceneTextSecurityPolicy {

    private final PracticeDiscoveryPolicyProperties policyProperties;
    private final PolicyTextMatcher policyTextMatcher;
    private final SpoofChecker spoofChecker;

    public SceneTextSecurityPolicy(
            PracticeDiscoveryPolicyProperties policyProperties,
            PolicyTextMatcher policyTextMatcher
    ) {
        this(policyProperties, policyTextMatcher, new SpoofChecker.Builder().build());
    }

    SceneTextSecurityPolicy(
            PracticeDiscoveryPolicyProperties policyProperties,
            PolicyTextMatcher policyTextMatcher,
            SpoofChecker spoofChecker
    ) {
        this.policyProperties = policyProperties;
        this.policyTextMatcher = policyTextMatcher;
        this.spoofChecker = spoofChecker;
    }

    public void requireSafe(SceneTextForms forms) {
        if (forms == null || forms.securityText() == null) {
            return;
        }
        if (forms.riskSignals().bidiControlPresent()) {
            throw unsafe("bidi_control");
        }
        if (phoneOrEmailOrNameMatches(forms.securityText())) {
            throw unsafe("pii");
        }
        if (forms.riskSignals().mixedDigitSystems() && forms.riskSignals().longDigitRun()) {
            throw unsafe("mixed_number_system_pii");
        }
        if (highRiskMarkerMatches(forms.securityText())
                || highRiskMarkerMatches(spoofChecker.getSkeleton(forms.securityText()))) {
            throw unsafe("high_risk_marker");
        }
    }

    private boolean phoneOrEmailOrNameMatches(String securityText) {
        return policyProperties.compiledPhonePattern().matcher(securityText).find()
                || securityText.replaceAll("\\D", "").length() >= 11
                || policyProperties.compiledEmailPattern().matcher(securityText).find()
                || policyProperties.compiledBabyNamePattern().matcher(securityText).find()
                || policyTextMatcher.containsAnyLiteral(securityText, policyProperties.piiMarkers());
    }

    private boolean highRiskMarkerMatches(String securityText) {
        return policyTextMatcher.containsAnyLiteral(securityText, highRiskMarkers());
    }

    private java.util.List<String> highRiskMarkers() {
        return Stream.of(
                        policyProperties.piiMarkers(),
                        policyProperties.promptInjectionMarkers(),
                        policyProperties.validatorMedicalLegal(),
                        policyProperties.validatorAdultViolentSexual())
                .flatMap(java.util.Collection::stream)
                .distinct()
                .toList();
    }

    private ContractException unsafe(String reason) {
        return new ContractException(
                HttpStatus.UNPROCESSABLE_ENTITY,
                "unsafe_custom_scene_text",
                "customSceneText 包含不适合提交的内容。",
                java.util.Map.of("reason", reason));
    }
}
