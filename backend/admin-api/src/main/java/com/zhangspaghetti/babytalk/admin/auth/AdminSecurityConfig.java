package com.zhangspaghetti.babytalk.admin.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nimbusds.jose.jwk.source.ImmutableSecret;
import com.nimbusds.jose.proc.SecurityContext;
import com.zhangspaghetti.babytalk.security.JwtTokenService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.filter.OncePerRequestFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@EnableConfigurationProperties(AdminSecurityConfig.AdminAuthProperties.class)
public class AdminSecurityConfig {

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    SecretKey adminJwtSecretKey(AdminAuthProperties properties) {
        var rawSecret = properties.jwtSecret().getBytes(StandardCharsets.UTF_8);
        if (rawSecret.length < 32) {
            throw new IllegalStateException("app.admin.auth.jwt-secret must be at least 32 bytes for HS256.");
        }
        return new SecretKeySpec(rawSecret, "HmacSHA256");
    }

    @Bean
    JwtEncoder adminJwtEncoder(SecretKey adminJwtSecretKey) {
        return new NimbusJwtEncoder(new ImmutableSecret<SecurityContext>(adminJwtSecretKey));
    }

    @Bean("adminTokenJwtDecoder")
    JwtDecoder adminTokenJwtDecoder(SecretKey adminJwtSecretKey, AdminAuthProperties properties) {
        var jwtDecoder = NimbusJwtDecoder.withSecretKey(adminJwtSecretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        jwtDecoder.setJwtValidator(JwtValidators.createDefaultWithIssuer(properties.issuer()));
        return jwtDecoder;
    }

    @Bean("adminAccessTokenJwtDecoder")
    JwtDecoder adminAccessTokenJwtDecoder(SecretKey adminJwtSecretKey, AdminAuthProperties properties) {
        var jwtDecoder = NimbusJwtDecoder.withSecretKey(adminJwtSecretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        jwtDecoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefaultWithIssuer(properties.issuer()),
                accessTokenTypeValidator()
        ));
        return jwtDecoder;
    }

    @Bean
    JwtTokenService jwtTokenService(
            JwtEncoder adminJwtEncoder,
            @Qualifier("adminTokenJwtDecoder") JwtDecoder adminTokenJwtDecoder,
            Clock clock
    ) {
        return new JwtTokenService(adminJwtEncoder, adminTokenJwtDecoder, clock);
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    private Converter<Jwt, ? extends AbstractAuthenticationToken> adminJwtAuthenticationConverter() {
        return jwt -> new JwtAuthenticationToken(
                jwt,
                toAuthorities(jwt.getClaimAsStringList("roles")),
                jwt.getClaimAsString("username")
        );
    }

    @Bean
    AuthenticationEntryPoint adminAuthenticationEntryPoint(ObjectMapper objectMapper) {
        return (request, response, authException) -> writeError(
                objectMapper,
                response,
                HttpStatus.UNAUTHORIZED,
                resolveAuthenticationFailureCode(request),
                resolveAuthenticationFailureMessage(request)
        );
    }

    @Bean
    AccessDeniedHandler adminAccessDeniedHandler(ObjectMapper objectMapper) {
        return (request, response, accessDeniedException) -> writeError(
                objectMapper,
                response,
                HttpStatus.FORBIDDEN,
                "forbidden",
                "权限不足。"
        );
    }

    @Bean
    AdminSessionGuardFilter adminSessionGuardFilter(AdminAuthService adminAuthService, AuthenticationEntryPoint adminAuthenticationEntryPoint) {
        return new AdminSessionGuardFilter(adminAuthService, adminAuthenticationEntryPoint);
    }

    @Bean
    SecurityFilterChain adminSecurityFilterChain(
            HttpSecurity http,
            @Qualifier("adminAccessTokenJwtDecoder") JwtDecoder adminAccessTokenJwtDecoder,
            AdminSessionGuardFilter adminSessionGuardFilter,
            AuthenticationEntryPoint adminAuthenticationEntryPoint,
            AccessDeniedHandler adminAccessDeniedHandler
    ) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(adminAuthenticationEntryPoint)
                        .accessDeniedHandler(adminAccessDeniedHandler))
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers(
                                "/actuator/health",
                                "/actuator/info",
                                "/error",
                                "/api/admin/auth/login",
                                "/api/admin/auth/refresh",
                                "/api/admin/auth/logout")
                        .permitAll()
                        .anyRequest().authenticated())
                .oauth2ResourceServer(oauth2 -> oauth2.jwt(jwt -> jwt
                        .decoder(adminAccessTokenJwtDecoder)
                        .jwtAuthenticationConverter(adminJwtAuthenticationConverter())));
        http.addFilterAfter(adminSessionGuardFilter, BearerTokenAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    ApplicationRunner adminBootstrapRunner(AdminAuthService adminAuthService) {
        return args -> adminAuthService.seedBootstrapPrincipalIfMissing();
    }

    private OAuth2TokenValidator<Jwt> accessTokenTypeValidator() {
        return jwt -> {
            var tokenType = jwt.getClaimAsString("type");
            var refreshTokenId = jwt.getClaimAsString("rtid");
            if (!JwtTokenService.TokenType.ACCESS.claimValue().equals(tokenType) || refreshTokenId == null || refreshTokenId.isBlank()) {
                return OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "Access token claim set is invalid.", null));
            }
            return OAuth2TokenValidatorResult.success();
        };
    }

    private Collection<SimpleGrantedAuthority> toAuthorities(List<String> roleCodes) {
        if (roleCodes == null) {
            return List.of();
        }
        return roleCodes.stream()
                .map(roleCode -> "ROLE_" + roleCode.replace('-', '_').toUpperCase())
                .map(SimpleGrantedAuthority::new)
                .collect(Collectors.toList());
    }

    private String resolveAuthenticationFailureCode(HttpServletRequest request) {
        var explicit = request.getAttribute(AdminSessionGuardFilter.FAILURE_CODE_ATTRIBUTE);
        if (explicit instanceof String code && !code.isBlank()) {
            return code;
        }
        return hasAuthorizationHeader(request) ? "invalid_admin_access_token" : "admin_authentication_required";
    }

    private String resolveAuthenticationFailureMessage(HttpServletRequest request) {
        var code = resolveAuthenticationFailureCode(request);
        return switch (code) {
            case "admin_session_invalid" -> "管理员会话已失效，请重新登录。";
            case "admin_account_disabled" -> "管理员账号已停用。";
            case "invalid_admin_access_token" -> "access token 无效。";
            default -> "请先登录管理员账号。";
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
            String message
    ) throws IOException {
        response.setStatus(status.value());
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), Map.of(
                "timestamp", Instant.now().toString(),
                "status", status.value(),
                "code", code,
                "message", message,
                "details", Map.of()
        ));
    }

    @ConfigurationProperties(prefix = "app.admin.auth")
    public record AdminAuthProperties(
            String issuer,
            String jwtSecret,
            Duration accessTokenTtl,
            Duration refreshTokenTtl,
            Bootstrap bootstrap
    ) {
        public record Bootstrap(boolean enabled, String username, String password, String displayName) {
        }
    }

    static final class AdminSessionGuardFilter extends OncePerRequestFilter {

        static final String FAILURE_CODE_ATTRIBUTE = "admin.auth.failure.code";

        private final AdminAuthService adminAuthService;
        private final AuthenticationEntryPoint authenticationEntryPoint;

        AdminSessionGuardFilter(AdminAuthService adminAuthService, AuthenticationEntryPoint authenticationEntryPoint) {
            this.adminAuthService = adminAuthService;
            this.authenticationEntryPoint = authenticationEntryPoint;
        }

        @Override
        protected void doFilterInternal(
                HttpServletRequest request,
                HttpServletResponse response,
                FilterChain filterChain
        ) throws ServletException, IOException {
            var authentication = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (!(authentication instanceof JwtAuthenticationToken jwtAuthenticationToken)) {
                filterChain.doFilter(request, response);
                return;
            }

            var validationResult = adminAuthService.validateAccessToken(
                    jwtAuthenticationToken.getToken().getSubject(),
                    jwtAuthenticationToken.getToken().getClaimAsString("rtid")
            );
            if (validationResult == AdminAuthService.AccessValidationResult.ACTIVE) {
                filterChain.doFilter(request, response);
                return;
            }

            request.setAttribute(FAILURE_CODE_ATTRIBUTE, validationResult == AdminAuthService.AccessValidationResult.ACCOUNT_DISABLED
                    ? "admin_account_disabled"
                    : "admin_session_invalid");
            org.springframework.security.core.context.SecurityContextHolder.clearContext();
            authenticationEntryPoint.commence(request, response, new BadCredentialsException("admin access token rejected"));
        }
    }
}
