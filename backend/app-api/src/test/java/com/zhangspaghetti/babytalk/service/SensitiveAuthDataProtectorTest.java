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
