package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.ConsumerAuthProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/** Protects values that are only needed for short-lived auth lookup and verification. */
@Component
public class SensitiveAuthDataProtector {

    private static final String HMAC_ALGORITHM = "HmacSHA256";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final byte[] pepper;

    public SensitiveAuthDataProtector(ConsumerAuthProperties properties) {
        var configuredPepper = properties.sensitiveDataPepper();
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
