package com.zhangspaghetti.babytalk.onboarding.conversation;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentKeyFactory;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public final class OnboardingAudioCapabilityService {

    private static final Pattern SAFE_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{5,127}$");
    private static final Pattern TOKEN = Pattern.compile("^oac1\\.([0-9]{10})\\.([0-9a-f]{64})$");

    private final PracticeGeneratedContentKeyFactory keyFactory;
    private final Clock clock;

    @Autowired
    public OnboardingAudioCapabilityService(PracticeGeneratedContentKeyFactory keyFactory) {
        this(keyFactory, Clock.systemUTC());
    }

    OnboardingAudioCapabilityService(PracticeGeneratedContentKeyFactory keyFactory, Clock clock) {
        this.keyFactory = keyFactory;
        this.clock = clock;
    }

    public String issue(String conversationId, String utteranceId, OffsetDateTime expiresAt) {
        requireSafeId(conversationId);
        requireSafeId(utteranceId);
        if (expiresAt == null || !expiresAt.isAfter(OffsetDateTime.now(clock))) {
            throw audioNotFound();
        }
        var expiry = expiresAt.toEpochSecond();
        return "oac1." + expiry + "."
                + keyFactory.onboardingAudioCapabilitySignature(conversationId, utteranceId, expiry);
    }

    public void requireAuthorized(String capability, String conversationId, String utteranceId) {
        requireSafeId(conversationId);
        requireSafeId(utteranceId);
        var matcher = capability == null ? null : TOKEN.matcher(capability);
        if (matcher == null || !matcher.matches()) {
            throw audioNotFound();
        }
        long expiry;
        try {
            expiry = Long.parseLong(matcher.group(1));
        } catch (NumberFormatException exception) {
            throw audioNotFound();
        }
        if (OffsetDateTime.now(clock).toEpochSecond() >= expiry) {
            throw audioNotFound();
        }
        var expected = keyFactory.onboardingAudioCapabilitySignature(conversationId, utteranceId, expiry);
        if (!MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.US_ASCII),
                matcher.group(2).getBytes(StandardCharsets.US_ASCII))) {
            throw audioNotFound();
        }
    }

    private void requireSafeId(String value) {
        if (value == null || !SAFE_ID.matcher(value).matches()) {
            throw audioNotFound();
        }
    }

    private ContractException audioNotFound() {
        return new ContractException(
                HttpStatus.NOT_FOUND,
                "onboarding_audio_not_found",
                "未找到可播放的访客语音。");
    }
}
