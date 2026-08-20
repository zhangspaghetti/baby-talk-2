package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.config.ConsumerAuthProperties;
import java.time.Duration;
import org.junit.jupiter.api.Test;

class SensitiveAuthDataProtectorTest {

    @Test
    void phoneLookupReferenceSurvivesJwtKeyRotationWhenPepperIsStable() {
        var beforeRotation = protector("jwt-secret-before-rotation-0123456789", "stable-auth-pepper-0123456789abcdef");
        var afterRotation = protector("jwt-secret-after-rotation-01234567890", "stable-auth-pepper-0123456789abcdef");
        var differentPepper = protector("jwt-secret-after-rotation-01234567890", "other-auth-pepper-0123456789abcdef");

        assertThat(beforeRotation.phoneLookupRef("13800138000"))
                .isEqualTo(afterRotation.phoneLookupRef("13800138000"))
                .isNotEqualTo(differentPepper.phoneLookupRef("13800138000"));
    }

    @Test
    void otpVerifierHasSeparateDomainAndRequiresExactCode() {
        var protector = protector("jwt-secret-0123456789abcdef0123456789", "stable-auth-pepper-0123456789abcdef");
        var verifier = protector.createVerificationVerifier("246810");

        assertThat(verifier).doesNotContain("246810");
        assertThat(protector.matchesVerificationVerifier(verifier, "246810")).isTrue();
        assertThat(protector.matchesVerificationVerifier(verifier, "111111")).isFalse();
    }

    @Test
    void installationLookupReferenceUsesSeparateDomainAndDoesNotExposeRawValue() {
        var protector = protector("jwt-secret-0123456789abcdef0123456789", "stable-auth-pepper-0123456789abcdef");

        var reference = protector.installationLookupRef("install-alpha");

        assertThat(reference)
                .startsWith("v1:")
                .doesNotContain("install-alpha")
                .isNotEqualTo(protector.phoneLookupRef("install-alpha"));
        assertThat(reference).isEqualTo(protector.installationLookupRef("install-alpha"));
    }

    @Test
    void inviteTokenLookupReferenceUsesIndependentDomainAndDoesNotExposeRawValue() {
        var protector = protector("jwt-secret-0123456789abcdef0123456789", "stable-auth-pepper-0123456789abcdef");

        var reference = protector.inviteTokenLookupRef("invite_0123456789abcdef012345");

        assertThat(reference)
                .startsWith("v1:")
                .doesNotContain("invite_0123456789abcdef012345")
                .isNotEqualTo(protector.phoneLookupRef("invite_0123456789abcdef012345"))
                .isNotEqualTo(protector.installationLookupRef("invite_0123456789abcdef012345"));
        assertThat(reference).isEqualTo(protector.inviteTokenLookupRef("invite_0123456789abcdef012345"));
    }

    private SensitiveAuthDataProtector protector(String jwtSecret, String sensitiveDataPepper) {
        return new SensitiveAuthDataProtector(new ConsumerAuthProperties(
                "test-issuer",
                jwtSecret,
                sensitiveDataPepper,
                Duration.ofMinutes(15),
                Duration.ofDays(30)
        ));
    }
}
