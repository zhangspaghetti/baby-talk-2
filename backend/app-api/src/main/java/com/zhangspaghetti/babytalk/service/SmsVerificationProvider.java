package com.zhangspaghetti.babytalk.service;

import java.time.Instant;

public interface SmsVerificationProvider {

    SmsChallenge issueChallenge(String normalizedPhoneNumber, Instant now);

    record SmsChallenge(
            String verificationCode,
            String maskedPhoneNumber,
            int codeLength,
            Instant expiresAt
    ) {
    }

    class ProviderMisconfiguredException extends RuntimeException {
        public ProviderMisconfiguredException(String message) {
            super(message);
        }
    }

    class RetryableChallengeException extends RuntimeException {
        public RetryableChallengeException(String message) {
            super(message);
        }
    }
}
