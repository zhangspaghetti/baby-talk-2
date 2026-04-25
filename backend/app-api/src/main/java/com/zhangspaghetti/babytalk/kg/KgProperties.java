package com.zhangspaghetti.babytalk.kg;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * KG 审查相关配置属性 — 绑定 {@code app.kg} 前缀。
 *
 * <ul>
 *   <li>{@code reviewInterval} — agent 审查轮询间隔</li>
 *   <li>{@code reviewEnabled} — 是否启用定时审查</li>
 *   <li>{@code reviewBatchSize} — 每轮审查批次大小</li>
 * </ul>
 */
@ConfigurationProperties(prefix = "app.kg")
public record KgProperties(
        Duration reviewInterval,
        boolean reviewEnabled,
        int reviewBatchSize
) {
}
