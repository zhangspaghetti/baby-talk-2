package com.zhangspaghetti.babytalk.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import javax.crypto.SecretKey;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.web.filter.OncePerRequestFilter;
import com.zhangspaghetti.babytalk.security.JwtTokenService;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;

@Configuration
@EnableWebSecurity
public class AppSecurityConfig {

    private static final Logger log = LoggerFactory.getLogger(AppSecurityConfig.class);
    private static final String FAILURE_CODE_ATTRIBUTE = "consumer.auth.failure.code";
    private static final String FAILURE_REASON_ATTRIBUTE = "consumer.auth.failure.reason";
    private static final List<RequestMatcher> AUTH_IGNORED_MATCHERS = List.of(
            new AntPathRequestMatcher("/api/v1/auth/**"),
            new AntPathRequestMatcher("/download"),
            new AntPathRequestMatcher("/upgrade"),
            new AntPathRequestMatcher("/download/redirect"),
            new AntPathRequestMatcher("/upgrade/redirect"),
            new AntPathRequestMatcher("/share/**"),
            new AntPathRequestMatcher("/invite/**"),
            new AntPathRequestMatcher("/actuator/health"),
            new AntPathRequestMatcher("/actuator/info"),
            new AntPathRequestMatcher("/error"),
                new AntPathRequestMatcher("/api/v1/share-links")
    );

    @Bean("consumerAccessTokenJwtDecoder")
    JwtDecoder consumerAccessTokenJwtDecoder(SecretKey consumerJwtSecretKey, ConsumerAuthProperties properties) {
        var jwtDecoder = NimbusJwtDecoder.withSecretKey(consumerJwtSecretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        jwtDecoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefaultWithIssuer(properties.issuer()),
                accessTokenTypeValidator()
        ));
        return jwtDecoder;
    }

    @Bean
    BearerTokenResolver consumerBearerTokenResolver() {
        var delegate = new DefaultBearerTokenResolver();
        return request -> isIgnoredAuthRoute(request) ? null : delegate.resolve(request);
    }

    @Bean
    AuthenticationEntryPoint consumerAuthenticationEntryPoint(ObjectMapper objectMapper) {
        return (request, response, authException) -> writeError(
                objectMapper,
                response,
                HttpStatus.UNAUTHORIZED,
                resolveAuthenticationFailureCode(request),
                resolveAuthenticationFailureReason(request),
                resolveAuthenticationFailureMessage(request)
        );
    }

    @Bean
    AccessDeniedHandler consumerAccessDeniedHandler(ObjectMapper objectMapper) {
        return (request, response, accessDeniedException) -> writeError(
                objectMapper,
                response,
                HttpStatus.FORBIDDEN,
                "forbidden",
                "forbidden",
                "权限不足。"
        );
    }

    @Bean
    ConsumerAccessTokenGuardFilter consumerAccessTokenGuardFilter(
            AuthConsentSyncService authConsentSyncService,
            AuthenticationEntryPoint consumerAuthenticationEntryPoint
    ) {
        return new ConsumerAccessTokenGuardFilter(authConsentSyncService, consumerAuthenticationEntryPoint);
    }

    @Bean
    SecurityFilterChain appSecurityFilterChain(
            HttpSecurity http,
            @Qualifier("consumerAccessTokenJwtDecoder") JwtDecoder consumerAccessTokenJwtDecoder,
            BearerTokenResolver consumerBearerTokenResolver,
            ConsumerAccessTokenGuardFilter consumerAccessTokenGuardFilter,
            AuthenticationEntryPoint consumerAuthenticationEntryPoint,
            AccessDeniedHandler consumerAccessDeniedHandler
    ) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(consumerAuthenticationEntryPoint)
                        .accessDeniedHandler(consumerAccessDeniedHandler))
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers(
                                "/api/v1/auth/**",
                                "/download",
                                "/upgrade",
                                "/download/redirect",
                                "/upgrade/redirect",
                                "/share/**",
                                "/invite/**",
                                "/actuator/health",
                                "/actuator/info",
                                "/error",
                                "/api/v1/share-links",
                                "/api/v1/onboarding/discovery",
                                "/api/v1/mentor/chat")
                        .permitAll()
                        .anyRequest().authenticated())
                .oauth2ResourceServer(oauth2 -> oauth2
                        .bearerTokenResolver(consumerBearerTokenResolver)
                        .authenticationEntryPoint(consumerAuthenticationEntryPoint)
                        .jwt(jwt -> jwt.decoder(consumerAccessTokenJwtDecoder)));
        http.addFilterAfter(consumerAccessTokenGuardFilter, BearerTokenAuthenticationFilter.class);
        return http.build();
    }

    private OAuth2TokenValidator<Jwt> accessTokenTypeValidator() {
        return jwt -> {
            var tokenType = jwt.getClaimAsString("type");
            var sessionId = jwt.getClaimAsString("sid");
            var refreshTokenId = jwt.getClaimAsString("rtid");
            if (!JwtTokenService.TokenType.ACCESS.claimValue().equals(tokenType)
                    || sessionId == null || sessionId.isBlank()
                    || refreshTokenId == null || refreshTokenId.isBlank()) {
                return OAuth2TokenValidatorResult.failure(
                        new OAuth2Error("invalid_token", "Access token claim set is invalid.", null));
            }
            return OAuth2TokenValidatorResult.success();
        };
    }

    private boolean isIgnoredAuthRoute(HttpServletRequest request) {
        return AUTH_IGNORED_MATCHERS.stream().anyMatch(matcher -> matcher.matches(request));
    }

    private String resolveAuthenticationFailureCode(HttpServletRequest request) {
        var explicit = request.getAttribute(FAILURE_CODE_ATTRIBUTE);
        if (explicit instanceof String code && !code.isBlank()) {
            return code;
        }
        return hasAuthorizationHeader(request) ? "invalid_access_token" : "consumer_authentication_required";
    }

    private String resolveAuthenticationFailureReason(HttpServletRequest request) {
        var explicit = request.getAttribute(FAILURE_REASON_ATTRIBUTE);
        if (explicit instanceof String reason && !reason.isBlank()) {
            return reason;
        }
        return hasAuthorizationHeader(request) ? "invalid" : "missing";
    }

    private String resolveAuthenticationFailureMessage(HttpServletRequest request) {
        return switch (resolveAuthenticationFailureCode(request)) {
            case "access_token_rotated" -> "access token 已轮换，请使用新的 token。";
            case "access_token_revoked" -> "access token 已失效，请重新登录。";
            case "access_token_expired" -> "access token 已过期，请重新登录。";
            case "consumer_session_invalid" -> "session 已失效，请重新登录。";
            case "account_deleted" -> "账号已删除。请重新注册。";
            case "invalid_access_token" -> "access token 无效。";
            default -> "请先登录。";
        };
    }

    private boolean hasAuthorizationHeader(HttpServletRequest request) {
        var authorization = request.getHeader(HttpHeaders.AUTHORIZATION);
        return authorization != null && !authorization.isBlank();
    }

    private void writeError(
            ObjectMapper objectMapper,
            HttpServletResponse response,
            HttpStatus status,
            String code,
            String reason,
            String message
    ) throws IOException {
        response.setStatus(status.value());
        response.setCharacterEncoding(java.nio.charset.StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), Map.of(
                "timestamp", Instant.now().toString(),
                "status", status.value(),
                "code", code,
                "message", message,
                "details", Map.of("reason", reason)
        ));
    }

    static final class ConsumerAccessTokenGuardFilter extends OncePerRequestFilter {

        private final AuthConsentSyncService authConsentSyncService;
        private final AuthenticationEntryPoint authenticationEntryPoint;

        ConsumerAccessTokenGuardFilter(
                AuthConsentSyncService authConsentSyncService,
                AuthenticationEntryPoint authenticationEntryPoint
        ) {
            this.authConsentSyncService = authConsentSyncService;
            this.authenticationEntryPoint = authenticationEntryPoint;
        }

        @Override
        protected void doFilterInternal(
                HttpServletRequest request,
                HttpServletResponse response,
                FilterChain filterChain
        ) throws ServletException, IOException {
            var authentication = SecurityContextHolder.getContext().getAuthentication();
            if (!(authentication instanceof JwtAuthenticationToken jwtAuthenticationToken)) {
                filterChain.doFilter(request, response);
                return;
            }

            var token = jwtAuthenticationToken.getToken();
            var validationResult = authConsentSyncService.validateAccessToken(
                    token.getSubject(),
                    token.getClaimAsString("sid"),
                    token.getClaimAsString("rtid")
            );
            if (validationResult == AuthConsentSyncService.AccessValidationResult.ACTIVE) {
                filterChain.doFilter(request, response);
                return;
            }

            var failureCode = switch (validationResult) {
                case ROTATED -> "access_token_rotated";
                case REVOKED -> "access_token_revoked";
                case EXPIRED -> "access_token_expired";
                case SESSION_INVALID -> "consumer_session_invalid";
                case ACCOUNT_DELETED -> "account_deleted";
                default -> "invalid_access_token";
            };
            var failureReason = switch (validationResult) {
                case ROTATED -> "rotated";
                case REVOKED -> "revoked";
                case EXPIRED -> "expired";
                case SESSION_INVALID -> "session_invalid";
                case ACCOUNT_DELETED -> "account_deleted";
                default -> "invalid";
            };

            log.info("consumer bearer rejected: path={}, reason={}", request.getRequestURI(), failureReason);
            request.setAttribute(FAILURE_CODE_ATTRIBUTE, failureCode);
            request.setAttribute(FAILURE_REASON_ATTRIBUTE, failureReason);
            SecurityContextHolder.clearContext();
            authenticationEntryPoint.commence(request, response, new BadCredentialsException("consumer access token rejected"));
        }
    }
}
