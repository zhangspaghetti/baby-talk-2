package com.zhangspaghetti.babytalk.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/** Protects values that are only needed for short-lived auth lookup and verification. */
public class SensitiveAuthDataProtector {

    private static final String HMAC_ALGORITHM = "HmacSHA256";
    private static final String REDACTED_INSTALLATION_REFERENCE = "redacted";
    private static final String INTERACTION_EVENT_KEY_REFERENCE_PREFIX = "e1:";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final byte[] pepper;

    public SensitiveAuthDataProtector(String configuredPepper) {
        if (configuredPepper == null || configuredPepper.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("app.auth.sensitive-data-pepper must be at least 32 bytes.");
        }
        this.pepper = configuredPepper.getBytes(StandardCharsets.UTF_8);
    }

    public String phoneLookupRef(String normalizedPhoneNumber) {
        return "v1:" + encode(hmac("phone-lookup-v1\u0000" + normalizedPhoneNumber));
    }

    public String installationLookupRef(String normalizedInstallationId) {
        return "v1:" + encode(hmac("installation-lookup-v1\u0000" + normalizedInstallationId));
    }

    /**
     * Projects a stored installation identifier before exposing it to an API or admin view.
     * Legacy raw identifiers are read-only compatible and never leave the trust boundary.
     */
    public String safeInstallationReference(String storedInstallationId) {
        if (storedInstallationId == null || storedInstallationId.isBlank()) {
            return REDACTED_INSTALLATION_REFERENCE;
        }
        var normalized = storedInstallationId.trim();
        if (REDACTED_INSTALLATION_REFERENCE.equals(normalized) || isInstallationReference(normalized)) {
            return normalized;
        }
        return installationLookupRef(normalized);
    }

    public boolean isInstallationReference(String value) {
        return value != null && value.matches("v1:[A-Za-z0-9_-]{43}");
    }

    public String interactionEventKeyLookupRef(String normalizedEventKey) {
        return INTERACTION_EVENT_KEY_REFERENCE_PREFIX
                + encode(hmac("interaction-event-key-lookup-v1\u0000" + normalizedEventKey));
    }

    public boolean isInteractionEventKeyReference(String value) {
        return value != null && value.matches("e1:[A-Za-z0-9_-]{43}");
    }

    public String inviteTokenLookupRef(String normalizedInviteToken) {
        return "v1:" + encode(hmac("invite-token-lookup-v1\u0000" + normalizedInviteToken));
    }

    public String createVerificationVerifier(String verificationCode) {
        byte[] salt = new byte[16];
        RANDOM.nextBytes(salt);
        String encodedSalt = encode(salt);
        return "v1:" + encodedSalt + ":" + encode(hmac("otp-verifier-v1\u0000" + encodedSalt + "\u0000" + verificationCode));
    }

    public boolean matchesVerificationVerifier(String storedVerifier, String verificationCode) {
        if (storedVerifier == null || verificationCode == null) {
            return false;
        }
        String[] parts = storedVerifier.split(":", -1);
        if (parts.length != 3 || !"v1".equals(parts[0]) || parts[1].isBlank() || parts[2].isBlank()) {
            return false;
        }
        byte[] expected = decode(parts[2]);
        if (expected == null) {
            return false;
        }
        return MessageDigest.isEqual(expected, hmac("otp-verifier-v1\u0000" + parts[1] + "\u0000" + verificationCode));
    }

    private byte[] hmac(String value) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(pepper, HMAC_ALGORITHM));
            return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
        } catch (Exception exception) {
            throw new IllegalStateException("Cannot initialize auth sensitive-data protector.", exception);
        }
    }

    private String encode(byte[] value) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(value);
    }

    private byte[] decode(String value) {
        try {
            return Base64.getUrlDecoder().decode(value);
        } catch (IllegalArgumentException exception) {
            return null;
        }
    }
}
