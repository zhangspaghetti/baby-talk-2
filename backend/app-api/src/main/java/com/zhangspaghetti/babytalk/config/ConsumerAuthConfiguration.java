package com.zhangspaghetti.babytalk.config;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import com.nimbusds.jose.proc.SecurityContext;
import com.zhangspaghetti.babytalk.security.JwtTokenService;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

@Configuration
public class ConsumerAuthConfiguration {

    @Bean
    SecretKey consumerJwtSecretKey(ConsumerAuthProperties properties) {
        var rawSecret = properties.jwtSecret().getBytes(StandardCharsets.UTF_8);
        if (rawSecret.length < 32) {
            throw new IllegalStateException("app.auth.jwt-secret must be at least 32 bytes for HS256.");
        }
        return new SecretKeySpec(rawSecret, "HmacSHA256");
    }

    @Bean
    JwtEncoder consumerJwtEncoder(SecretKey consumerJwtSecretKey) {
        return new NimbusJwtEncoder(new ImmutableSecret<SecurityContext>(consumerJwtSecretKey));
    }

    @Bean("consumerTokenJwtDecoder")
    JwtDecoder consumerTokenJwtDecoder(SecretKey consumerJwtSecretKey, ConsumerAuthProperties properties) {
        var jwtDecoder = NimbusJwtDecoder.withSecretKey(consumerJwtSecretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        jwtDecoder.setJwtValidator(JwtValidators.createDefaultWithIssuer(properties.issuer()));
        return jwtDecoder;
    }

    @Bean
    JwtTokenService jwtTokenService(
            JwtEncoder consumerJwtEncoder,
            @Qualifier("consumerTokenJwtDecoder") JwtDecoder consumerTokenJwtDecoder
    ) {
        return new JwtTokenService(consumerJwtEncoder, consumerTokenJwtDecoder, Clock.systemUTC());
    }
}
