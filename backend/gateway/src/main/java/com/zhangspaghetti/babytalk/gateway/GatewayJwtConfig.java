package com.zhangspaghetti.babytalk.gateway;

import java.nio.charset.StandardCharsets;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

@Configuration
@EnableConfigurationProperties(GatewayJwtConfig.GatewayJwtProperties.class)
public class GatewayJwtConfig {

    @Bean
    JwtDecoder adminJwtDecoder(GatewayJwtProperties properties) {
        var secretBytes = properties.adminJwtSecret().getBytes(StandardCharsets.UTF_8);
        if (secretBytes.length < 32) {
            throw new IllegalStateException("app.gateway.admin-jwt-secret must be at least 32 bytes for HS256.");
        }

        var jwtDecoder = NimbusJwtDecoder.withSecretKey(new SecretKeySpec(secretBytes, "HmacSHA256"))
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        jwtDecoder.setJwtValidator(JwtValidators.createDefaultWithIssuer(properties.adminJwtIssuer()));
        return jwtDecoder;
    }

    @ConfigurationProperties(prefix = "app.gateway")
    public record GatewayJwtProperties(String adminJwtSecret, String adminJwtIssuer) {
    }
}
