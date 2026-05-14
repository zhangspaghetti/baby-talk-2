package com.zhangspaghetti.babytalk.gateway;

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.cloud.gateway.filter.ratelimit.RedisRateLimiter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import reactor.core.publisher.Mono;

@Configuration
public class RateLimiterConfig {

    /**
     * 用户维度限流：基于请求 IP。
     * 限制：50 req/min（replenishRate=1/s 的令牌桶，burstCapacity=50）。
     */
    @Bean
    public KeyResolver userKeyResolver() {
        return exchange -> Mono.just(
                exchange.getRequest().getRemoteAddress() != null
                        ? exchange.getRequest().getRemoteAddress().getAddress().getHostAddress()
                        : "anonymous"
        );
    }

    /**
     * 默认限流器：50 req/min（约 1 req/s，burst 50）。
     * 对应计划 §4.3 的 user 维度限流。
     */
    @Bean
    public RedisRateLimiter defaultRateLimiter() {
        // replenishRate: 每秒填充的令牌数（1 ≈ 60 req/min）
        // burstCapacity: 令牌桶最大容量
        // requestedTokens: 每次请求消耗的令牌数
        return new RedisRateLimiter(1, 50, 1);
    }
}

