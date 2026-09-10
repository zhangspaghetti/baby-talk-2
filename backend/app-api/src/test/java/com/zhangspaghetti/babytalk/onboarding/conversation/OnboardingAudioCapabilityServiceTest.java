package com.zhangspaghetti.babytalk.onboarding.conversation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentKeyFactory;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentOwnerProperties;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class OnboardingAudioCapabilityServiceTest {

    private static final PracticeGeneratedContentKeyFactory KEYS =
            new PracticeGeneratedContentKeyFactory(new PracticeGeneratedContentOwnerProperties(
                    "v1", "0123456789abcdef0123456789abcdef"));

    @Test
    void capabilityAuthorizesOnlyItsExactConversationAndUtterance() {
        var service = serviceAt("2026-08-14T10:00:00Z");
        var capability = service.issue(
                "onbc_12345678", "utterance-1", OffsetDateTime.parse("2026-08-14T11:00:00Z"));

        service.requireAuthorized(capability, "onbc_12345678", "utterance-1");

        assertThat(capability).startsWith("oac1.").doesNotContain("onbc_12345678");
        assertClosed(() -> service.requireAuthorized(capability, "onbc_other123", "utterance-1"));
        assertClosed(() -> service.requireAuthorized(capability, "onbc_12345678", "utterance-2"));
        assertClosed(() -> service.requireAuthorized("malformed", "onbc_12345678", "utterance-1"));
    }

    @Test
    void expiredCapabilityFailsClosed() {
        var capability = serviceAt("2026-08-14T10:00:00Z").issue(
                "onbc_12345678", "utterance-1", OffsetDateTime.parse("2026-08-14T11:00:00Z"));

        assertClosed(() -> serviceAt("2026-08-14T11:00:00Z")
                .requireAuthorized(capability, "onbc_12345678", "utterance-1"));
    }

    private OnboardingAudioCapabilityService serviceAt(String instant) {
        return new OnboardingAudioCapabilityService(
                KEYS, Clock.fixed(Instant.parse(instant), ZoneOffset.UTC));
    }

    private void assertClosed(org.assertj.core.api.ThrowableAssert.ThrowingCallable call) {
        assertThatThrownBy(call).isInstanceOfSatisfying(ContractException.class, error -> {
            assertThat(error.status().value()).isEqualTo(404);
            assertThat(error.code()).isEqualTo("onboarding_audio_not_found");
            assertThat(error.details()).isEmpty();
        });
    }
}
