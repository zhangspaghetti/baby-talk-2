package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.SmsProperties;
import java.time.Instant;

public class DevSmsVerificationProvider implements SmsVerificationProvider {

    private final SmsProperties properties;

    public DevSmsVerificationProvider(SmsProperties properties) {
        this.properties = properties;
    }

    @Override
    public SmsChallenge issueChallenge(String normalizedPhoneNumber, Instant now) {
        if (properties.simulateTimeout()) {
            throw new RetryableChallengeException("开发 stub 正在模拟上游超时，请稍后重试。");
        }
        var devCode = properties.devCode();
        if (devCode == null || !devCode.matches("\\d{4,8}")) {
            throw new ProviderMisconfiguredException("BABY_TALK_SMS_DEV_CODE 缺失或格式非法，dev stub 无法生成验证码。");
        }
        return new SmsChallenge(
                devCode,
                maskPhone(normalizedPhoneNumber),
                devCode.length(),
                now.plus(properties.challengeTtl())
        );
    }

    private String maskPhone(String phoneNumber) {
        if (phoneNumber.length() < 7) {
            return "***";
        }
        return phoneNumber.substring(0, 3) + "****" + phoneNumber.substring(phoneNumber.length() - 4);
    }
}
