package com.zhangspaghetti.babytalk.gateway;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.springframework.boot.webflux.error.ErrorWebExceptionHandler;
import org.springframework.core.Ordered;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/**
 * 限流异常统一响应格式：{"code":"RATE_LIMITED","message":"...","retryAfter":60}
 */
@Component
public class GatewayRateLimitErrorHandler implements ErrorWebExceptionHandler, Ordered {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public int getOrder() {
        return -2; // 高优先级
    }

    @Override
    public Mono<Void> handle(ServerWebExchange exchange, Throwable ex) {
        if (ex instanceof ResponseStatusException rse
                && rse.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
            exchange.getResponse().setStatusCode(HttpStatus.TOO_MANY_REQUESTS);
            exchange.getResponse().getHeaders().setContentType(MediaType.APPLICATION_JSON);

            var body = Map.of(
                    "code", "RATE_LIMITED",
                    "message", "请求过于频繁，请稍后重试。",
                    "retryAfter", 60
            );

            try {
                byte[] bytes = objectMapper.writeValueAsBytes(body);
                DataBuffer buffer = exchange.getResponse().bufferFactory().wrap(bytes);
                return exchange.getResponse().writeWith(Mono.just(buffer));
            } catch (JsonProcessingException e) {
                byte[] fallback = "{\"code\":\"RATE_LIMITED\",\"message\":\"请求过于频繁。\"}"
                        .getBytes(StandardCharsets.UTF_8);
                DataBuffer buffer = exchange.getResponse().bufferFactory().wrap(fallback);
                return exchange.getResponse().writeWith(Mono.just(buffer));
            }
        }
        return Mono.error(ex);
    }
}
