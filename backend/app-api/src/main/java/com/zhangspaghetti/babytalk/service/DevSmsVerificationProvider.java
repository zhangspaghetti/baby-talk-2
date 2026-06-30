package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.SmsProperties;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DevSmsVerificationProvider implements SmsVerificationProvider {

    private static final Logger log = LoggerFactory.getLogger(DevSmsVerificationProvider.class);

    private final SmsProperties properties;

    public DevSmsVerificationProvider(SmsProperties properties) {
        this.properties = properties;
    }

    @Override
    public SmsChallenge issueChallenge(String normalizedPhoneNumber, Instant now) {
        if (properties.simulateTimeout()) {
            log.warn("[DEV-SMS] 模拟超时: phone={}", normalizedPhoneNumber);
            throw new RetryableChallengeException("开发 stub 正在模拟上游超时，请稍后重试。");
        }
        var devCode = properties.devCode();
        if (devCode == null || !devCode.matches("\\d{4,8}")) {
            log.error("[DEV-SMS] devCode 缺失或格式非法");
            throw new ProviderMisconfiguredException("BABY_TALK_SMS_DEV_CODE 缺失或格式非法，dev stub 无法生成验证码。");
        }
        log.info("[DEV-SMS] 发送验证码: phone={}, code={}, ttl={}", normalizedPhoneNumber, devCode, properties.challengeTtl());
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
