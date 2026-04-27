package com.zhangspaghetti.babytalk.gateway.filter;

import com.zhangspaghetti.babytalk.security.JwtTokenService;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Component
public class AdminJwtGlobalFilter implements GlobalFilter, Ordered {

    static final String MISSING_TOKEN = "missing_token";
    static final String MALFORMED_TOKEN = "malformed_token";
    static final String EXPIRED_TOKEN = "expired_token";
    static final String INVALID_ISSUER = "invalid_issuer";
    static final String WRONG_TOKEN_TYPE = "wrong_token_type";
    static final String PERMISSION_DENIED = "permission_denied";

    private static final Logger log = LoggerFactory.getLogger(AdminJwtGlobalFilter.class);
    private static final String ADMIN_PATH_PREFIX = "/api/admin/";
    private static final String BEARER_PREFIX = "Bearer ";
    private static final Set<String> PUBLIC_PATHS = Set.of(
            "/api/admin/auth/login",
            "/api/admin/auth/refresh",
            "/api/admin/auth/logout"
    );

    private final JwtDecoder jwtDecoder;

    public AdminJwtGlobalFilter(JwtDecoder jwtDecoder) {
        this.jwtDecoder = jwtDecoder;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        var path = exchange.getRequest().getPath().value();
        if (!path.startsWith(ADMIN_PATH_PREFIX) || PUBLIC_PATHS.contains(path)) {
            return chain.filter(exchange);
        }

        var authorization = exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        if (authorization == null || !authorization.startsWith(BEARER_PREFIX)) {
            return reject(exchange, MISSING_TOKEN, "Admin bearer token is required.");
        }

        var rawToken = authorization.substring(BEARER_PREFIX.length()).trim();
        if (rawToken.isEmpty()) {
            return reject(exchange, MISSING_TOKEN, "Admin bearer token is required.");
        }

        final Jwt jwt;
        try {
            jwt = jwtDecoder.decode(rawToken);
        } catch (JwtValidationException ex) {
            return reject(exchange, validationErrorCode(ex), validationMessage(ex));
        } catch (BadJwtException ex) {
            return reject(exchange, MALFORMED_TOKEN, "Admin token is malformed or has an invalid signature.");
        }

        if (!JwtTokenService.TokenType.ACCESS.claimValue().equals(jwt.getClaimAsString("type"))) {
            return reject(exchange, WRONG_TOKEN_TYPE, "Admin token must be an access token.");
        }

        return chain.filter(exchange);
    }

    @Override
    public int getOrder() {
        return -100;
    }

    private String validationErrorCode(JwtValidationException ex) {
        var descriptions = lowerCaseDescriptions(ex.getErrors());
        if (descriptions.stream().anyMatch(description -> description.contains("expired"))) {
            return EXPIRED_TOKEN;
        }
        if (descriptions.stream().anyMatch(description -> description.contains("iss"))) {
            return INVALID_ISSUER;
        }
        return PERMISSION_DENIED;
    }

    private String validationMessage(JwtValidationException ex) {
        return switch (validationErrorCode(ex)) {
            case EXPIRED_TOKEN -> "Admin token has expired.";
            case INVALID_ISSUER -> "Admin token issuer is invalid.";
            default -> "Admin token was rejected.";
        };
    }

    private List<String> lowerCaseDescriptions(Collection<OAuth2Error> errors) {
        return errors.stream()
                .map(OAuth2Error::getDescription)
                .filter(description -> description != null && !description.isBlank())
                .map(description -> description.toLowerCase(Locale.ROOT))
                .toList();
    }

    private Mono<Void> reject(ServerWebExchange exchange, String code, String message) {
        log.atWarn()
                .addKeyValue("error_code", code)
                .addKeyValue("path", exchange.getRequest().getPath().value())
                .log(message);
        return writeErrorResponse(exchange, code, message);
    }

    private Mono<Void> writeErrorResponse(ServerWebExchange exchange, String code, String message) {
        var response = exchange.getResponse();
        response.setStatusCode(HttpStatus.UNAUTHORIZED);
        response.getHeaders().setContentType(MediaType.APPLICATION_JSON);
        var body = String.format(Locale.ROOT, "{\"error\":\"%s\",\"message\":\"%s\"}", code, message);
        var buffer = response.bufferFactory().wrap(body.getBytes(StandardCharsets.UTF_8));
        return response.writeWith(Mono.just(buffer));
    }
}
