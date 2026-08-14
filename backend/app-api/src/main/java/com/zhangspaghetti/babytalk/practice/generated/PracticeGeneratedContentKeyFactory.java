package com.zhangspaghetti.babytalk.practice.generated;

import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

@Component
public final class PracticeGeneratedContentKeyFactory {

    private static final String HMAC_ALGORITHM = "HmacSHA256";

    private final byte[] secret;
    private final String keyVersion;

    public PracticeGeneratedContentKeyFactory(PracticeGeneratedContentOwnerProperties properties) {
        var keySecret = properties.keySecret();
        this.secret = keySecret == null || keySecret.isBlank()
                ? null
                : keySecret.getBytes(StandardCharsets.UTF_8);
        this.keyVersion = properties.keyVersion();
    }

    public String ownerKey(String ownerScope, String rawOwnerMaterial) {
        return "owner_" + hmacHex(
                "practice-owner-key:v1|" + keyVersion + "|" + ownerScope + "|" + rawOwnerMaterial);
    }

    public String installationRefHash(String installationId) {
        return "installation_" + hmacHex(
                "practice-installation-ref:v1|" + keyVersion + "|" + installationId);
    }

    public String requestFingerprint(String ownerKey, RequestFingerprintMaterial material) {
        var canonicalRequest = String.join("|",
                material.surface(),
                material.mode(),
                material.securitySceneText(),
                material.ageRange(),
                material.parentGoal(),
                material.locale(),
                material.generationProfileVersion(),
                material.rubricVersion(),
                material.evidencePolicyVersion(),
                Integer.toString(material.contentRefreshEpoch()));
        return "fp_" + hmacHex(
                "practice-request-fingerprint:v1|" + keyVersion + "|" + ownerKey + "|" + canonicalRequest);
    }

    public String clientRequestFingerprint(String ownerKey, ClientRequestFingerprintMaterial material) {
        var immutableFacts = String.join("|",
                material.surface(),
                material.mode(),
                material.securitySceneText(),
                material.ageRange(),
                material.parentGoal(),
                material.locale());
        return "crf_" + hmacHex(
                "practice-client-request-fingerprint:v1|" + keyVersion + "|" + ownerKey + "|" + immutableFacts);
    }

    public String onboardingConversationFingerprint(String installationRefHash, String canonicalRequest) {
        return "ocf_" + hmacHex(
                "onboarding-conversation-fingerprint:v1|" + keyVersion + "|"
                        + installationRefHash + "|" + canonicalRequest);
    }

    public String onboardingTurnFingerprint(String conversationId, String canonicalRequest) {
        return "otf_" + hmacHex(
                "onboarding-turn-fingerprint:v1|" + keyVersion + "|"
                        + conversationId + "|" + canonicalRequest);
    }

    public String onboardingAudioCapabilitySignature(
            String conversationId,
            String utteranceId,
            long expiresAtEpochSecond
    ) {
        return hmacHex(
                "onboarding-audio-capability:v1|" + keyVersion + "|"
                        + conversationId.length() + ":" + conversationId + "|"
                        + utteranceId.length() + ":" + utteranceId + "|"
                        + expiresAtEpochSecond);
    }

    public String stableDigest(String value) {
        try {
            var digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 unavailable", exception);
        }
    }

    private String hmacHex(String value) {
        if (secret == null || secret.length == 0) {
            throw new IllegalStateException("HmacSHA256 key secret is unavailable");
        }
        try {
            var mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(secret, HMAC_ALGORITHM));
            return HexFormat.of().formatHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException | InvalidKeyException exception) {
            throw new IllegalStateException("HmacSHA256 unavailable", exception);
        }
    }

    public record RequestFingerprintMaterial(
            String surface,
            String mode,
            String securitySceneText,
            String ageRange,
            String parentGoal,
            String locale,
            String generationProfileVersion,
            String rubricVersion,
            String evidencePolicyVersion,
            int contentRefreshEpoch
    ) {
    }

    public record ClientRequestFingerprintMaterial(
            String surface,
            String mode,
            String securitySceneText,
            String ageRange,
            String parentGoal,
            String locale
    ) {
    }
}
