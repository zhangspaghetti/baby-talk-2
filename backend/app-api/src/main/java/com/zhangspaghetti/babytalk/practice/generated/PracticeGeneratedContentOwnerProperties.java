package com.zhangspaghetti.babytalk.practice.generated;

import cn.hutool.core.util.StrUtil;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "babytalk.practice.discovery.owner")
public record PracticeGeneratedContentOwnerProperties(
        String keyVersion,
        String keySecret
) {

    public PracticeGeneratedContentOwnerProperties {
        keyVersion = StrUtil.trimToNull(keyVersion);
        keySecret = StrUtil.trimToNull(keySecret);
        if (keyVersion == null) {
            throw new IllegalArgumentException("practice generated content owner key version must not be blank");
        }
        if (keyVersion.codePointCount(0, keyVersion.length()) > 32) {
            throw new IllegalArgumentException("practice generated content owner key version must not exceed 32 characters");
        }
    }
}
