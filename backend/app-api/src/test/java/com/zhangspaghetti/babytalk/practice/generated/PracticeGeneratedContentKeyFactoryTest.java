package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalStateException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;

class PracticeGeneratedContentKeyFactoryTest {

    private final PracticeGeneratedContentKeyFactory factory =
            new PracticeGeneratedContentKeyFactory(
                    new PracticeGeneratedContentOwnerProperties(
                            "v1",
                            "0123456789abcdef0123456789abcdef"));

    @Test
    void sameOwnerAndSecurityRequestProduceStableFingerprint() {
        var material = material("宝宝 不肯穿鞋");

        assertThat(factory.requestFingerprint("owner_a", material))
                .isEqualTo(factory.requestFingerprint("owner_a", material));
    }

    @Test
    void differentOwnersCannotBeComparedByPlainSceneHash() {
        var material = material("宝宝 不肯穿鞋");

        assertThat(factory.requestFingerprint("owner_a", material))
                .isNotEqualTo(factory.requestFingerprint("owner_b", material));
    }

    @Test
    void fingerprintDoesNotEqualPlainSha256OfSecurityRequest() throws Exception {
        var material = material("宝宝 不肯穿鞋");
        var canonicalRequest = "onboarding|custom_scene|宝宝 不肯穿鞋|12_18m"
                + "|daily_care|zh-CN|prompt-v1|strategy-v1|policy-v2|1";
        var plainSha256 = HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(canonicalRequest.getBytes(StandardCharsets.UTF_8)));

        assertThat(factory.requestFingerprint("owner_a", material))
                .startsWith("fp_")
                .doesNotContain("宝宝")
                .isNotEqualTo("fp_" + plainSha256);
    }

    @Test
    void fingerprintUsesExactVersionedPayloadWithoutRoutingFields() throws Exception {
        var material = material("宝宝 不肯穿鞋");
        var payload = "onboarding|custom_scene|宝宝 不肯穿鞋|12_18m"
                + "|daily_care|zh-CN|prompt-v1|strategy-v1|policy-v2|1";

        assertThat(factory.requestFingerprint("owner_a", material))
                .isEqualTo("fp_" + hmacHex(
                        "practice-request-fingerprint:v1|v1|owner_a|" + payload));
    }

    @Test
    void ownerAndInstallationReferencesUseSeparateDomains() {
        assertThat(factory.ownerKey("installation", "install-a"))
                .startsWith("owner_")
                .isNotEqualTo(factory.installationRefHash("install-a"));
    }

    @Test
    void stableDigestIsDeterministicForPublicSlugInputs() {
        assertThat(factory.stableDigest("safe slug input"))
                .isEqualTo(factory.stableDigest("safe slug input"));
    }

    @Test
    void missingOrBlankOwnerSecretDefersFailureUntilHmacOperation() {
        var nullSecretFactory = new PracticeGeneratedContentKeyFactory(
                new PracticeGeneratedContentOwnerProperties("v1", null));
        var blankSecretFactory = new PracticeGeneratedContentKeyFactory(
                propertiesWithSecret(" \t"));

        assertHmacOperationsFailClosed(nullSecretFactory);
        assertHmacOperationsFailClosed(blankSecretFactory);

        var secretWithWhitespace = new PracticeGeneratedContentKeyFactory(propertiesWithSecret(" secret "));
        var trimmedSecret = new PracticeGeneratedContentKeyFactory(propertiesWithSecret("secret"));

        assertThat(secretWithWhitespace.ownerKey("installation", "install-a"))
                .isNotEqualTo(trimmedSecret.ownerKey("installation", "install-a"));
    }

    private void assertHmacOperationsFailClosed(PracticeGeneratedContentKeyFactory factory) {
        assertThatIllegalStateException()
                .isThrownBy(() -> factory.ownerKey("installation", "install-a"))
                .withMessage("HmacSHA256 key secret is unavailable");
        assertThatIllegalStateException()
                .isThrownBy(() -> factory.installationRefHash("install-a"))
                .withMessage("HmacSHA256 key secret is unavailable");
        assertThatIllegalStateException()
                .isThrownBy(() -> factory.requestFingerprint("owner_a", material("宝宝 不肯穿鞋")))
                .withMessage("HmacSHA256 key secret is unavailable");
    }

    private PracticeGeneratedContentOwnerProperties propertiesWithSecret(String secret) {
        var properties = org.mockito.Mockito.mock(PracticeGeneratedContentOwnerProperties.class);
        org.mockito.Mockito.when(properties.keyVersion()).thenReturn("v1");
        org.mockito.Mockito.when(properties.keySecret()).thenReturn(secret);
        return properties;
    }

    private PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial material(String scene) {
        return new PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial(
                "onboarding", "custom_scene", scene, "12_18m",
                "daily_care", "zh-CN", "prompt-v1", "strategy-v1", "policy-v2", 1);
    }

    private String hmacHex(String value) throws Exception {
        var mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(
                "0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.UTF_8),
                "HmacSHA256"));
        return HexFormat.of().formatHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
    }
}
