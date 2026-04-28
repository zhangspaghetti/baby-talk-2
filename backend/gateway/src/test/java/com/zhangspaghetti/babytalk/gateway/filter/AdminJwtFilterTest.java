package com.zhangspaghetti.babytalk.gateway.filter;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import reactor.core.publisher.Mono;

@ExtendWith(MockitoExtension.class)
class AdminJwtFilterTest {

    @Mock
    private JwtDecoder jwtDecoder;

    private AdminJwtGlobalFilter filter;

    @BeforeEach
    void setUp() {
        filter = new AdminJwtGlobalFilter(jwtDecoder);
    }

    @Test
    void filterSkipsNonAdminPath() {
        var exchange = buildExchange("/health");
        var chainCalled = new AtomicBoolean(false);

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isTrue();
        assertThat(exchange.getResponse().getStatusCode()).isNull();
    }

    @Test
    void filterSkipsPublicAuthPath() {
        var exchange = buildExchange("/api/admin/auth/login");
        var chainCalled = new AtomicBoolean(false);

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isTrue();
        assertThat(exchange.getResponse().getStatusCode()).isNull();
    }

    @Test
    void filterSkipsPublicAuthRefreshPath() {
        var exchange = buildExchange("/api/admin/auth/refresh");
        var chainCalled = new AtomicBoolean(false);

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isTrue();
        assertThat(exchange.getResponse().getStatusCode()).isNull();
    }

    @Test
    void filterReturnsMissingTokenWhenNoAuthHeader() {
        var exchange = buildExchange("/api/admin/dashboard");
        var chainCalled = new AtomicBoolean(false);

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isFalse();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(bodyOf(exchange)).contains(AdminJwtGlobalFilter.MISSING_TOKEN);
    }

    @Test
    void filterReturnsMalformedTokenForBadJwt() {
        var exchange = buildExchangeWithBearer("/api/admin/dashboard", "bad-token");
        var chainCalled = new AtomicBoolean(false);
        when(jwtDecoder.decode(anyString())).thenThrow(new BadJwtException("bad"));

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isFalse();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(bodyOf(exchange)).contains(AdminJwtGlobalFilter.MALFORMED_TOKEN);
    }

    @Test
    void filterReturnsExpiredTokenForExpiredJwt() {
        var exchange = buildExchangeWithBearer("/api/admin/dashboard", "expired-token");
        var chainCalled = new AtomicBoolean(false);
        when(jwtDecoder.decode(anyString())).thenThrow(new JwtValidationException(
                "Jwt expired at 2020-01-01",
                List.of(new OAuth2Error("invalid_token", "Jwt expired at 2020-01-01", null))
        ));

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isFalse();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(bodyOf(exchange)).contains(AdminJwtGlobalFilter.EXPIRED_TOKEN);
    }

    @Test
    void filterReturnsInvalidIssuerForIssuerMismatch() {
        var exchange = buildExchangeWithBearer("/api/admin/dashboard", "issuer-mismatch");
        var chainCalled = new AtomicBoolean(false);
        when(jwtDecoder.decode(anyString())).thenThrow(new JwtValidationException(
                "iss claim is not valid",
                List.of(new OAuth2Error("invalid_token", "iss claim is not valid", null))
        ));

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isFalse();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(bodyOf(exchange)).contains(AdminJwtGlobalFilter.INVALID_ISSUER);
    }

    @Test
    void filterReturnsWrongTokenTypeForRefreshToken() {
        var exchange = buildExchangeWithBearer("/api/admin/dashboard", "refresh-token");
        var chainCalled = new AtomicBoolean(false);
        when(jwtDecoder.decode(anyString())).thenReturn(jwtWithType("refresh"));

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isFalse();
        assertThat(exchange.getResponse().getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(bodyOf(exchange)).contains(AdminJwtGlobalFilter.WRONG_TOKEN_TYPE);
    }

    @Test
    void filterPassesThroughForValidAccessToken() {
        var exchange = buildExchangeWithBearer("/api/admin/dashboard", "access-token");
        var chainCalled = new AtomicBoolean(false);
        when(jwtDecoder.decode(anyString())).thenReturn(jwtWithType("access"));

        filter.filter(exchange, chain(chainCalled)).block();

        assertThat(chainCalled).isTrue();
        assertThat(exchange.getResponse().getStatusCode()).isNull();
    }

    private GatewayFilterChain chain(AtomicBoolean chainCalled) {
        return exchange -> {
            chainCalled.set(true);
            return Mono.empty();
        };
    }

    private MockServerWebExchange buildExchange(String path) {
        return MockServerWebExchange.from(MockServerHttpRequest.get(path).build());
    }

    private MockServerWebExchange buildExchangeWithBearer(String path, String token) {
        return MockServerWebExchange.from(
                MockServerHttpRequest.get(path)
                        .header("Authorization", "Bearer " + token)
                        .build()
        );
    }

    private String bodyOf(MockServerWebExchange exchange) {
        return exchange.getResponse().getBodyAsString().block();
    }

    private Jwt jwtWithType(String type) {
        return Jwt.withTokenValue("t")
                .header("alg", "HS256")
                .subject("admin-user")
                .claim("type", type)
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(300))
                .build();
    }
}
