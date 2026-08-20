package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.ConsumerAuthProperties;
import org.springframework.stereotype.Component;

/** App-api compatibility seam for the shared sensitive-data protector. */
@Component
public class SensitiveAuthDataProtector extends com.zhangspaghetti.babytalk.security.SensitiveAuthDataProtector {

    public SensitiveAuthDataProtector(ConsumerAuthProperties properties) {
        super(properties.sensitiveDataPepper());
    }
}
