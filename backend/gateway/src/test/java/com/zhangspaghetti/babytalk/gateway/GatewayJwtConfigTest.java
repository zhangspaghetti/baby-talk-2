package com.zhangspaghetti.babytalk.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.autoconfigure.context.ConfigurationPropertiesAutoConfiguration;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.cloud.gateway.config.GatewayProperties;
import org.springframework.security.oauth2.jwt.JwtException;

class GatewayJwtConfigTest {

    private final GatewayJwtConfig gatewayJwtConfig = new GatewayJwtConfig();

    @Test
    void rejectsSecretsShorterThan32Bytes() {
        var properties = new GatewayJwtConfig.GatewayJwtProperties("short-secret", "babytalk-admin-api");

        assertThatThrownBy(() -> gatewayJwtConfig.adminJwtDecoder(properties))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("app.gateway.admin-jwt-secret must be at least 32 bytes for HS256.");
    }

    @Test
    void decodesTokenSignedWithConfiguredSecretAndIssuer() throws Exception {
        var properties = new GatewayJwtConfig.GatewayJwtProperties(
                "babytalk-admin-local-hs256-secret-20260424",
                "babytalk-admin-api"
        );
        var jwtDecoder = gatewayJwtConfig.adminJwtDecoder(properties);
        var token = createToken(properties.adminJwtSecret(), properties.adminJwtIssuer());

        var jwt = jwtDecoder.decode(token);

        assertThat(jwt.getSubject()).isEqualTo("admin-user");
        assertThat(jwt.getClaimAsString("iss")).isEqualTo(properties.adminJwtIssuer());
    }

    @Test
    void rejectsTokenWithUnexpectedIssuer() throws Exception {
        var properties = new GatewayJwtConfig.GatewayJwtProperties(
                "babytalk-admin-local-hs256-secret-20260424",
                "babytalk-admin-api"
        );
        var jwtDecoder = gatewayJwtConfig.adminJwtDecoder(properties);
        var token = createToken(properties.adminJwtSecret(), "unexpected-issuer");

        assertThatThrownBy(() -> jwtDecoder.decode(token))
                .isInstanceOf(JwtException.class);
    }

    @Test
    void bindsProductionRoutesFromServerWebfluxGatewayPrefix() {
        new ApplicationContextRunner()
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .withConfiguration(AutoConfigurations.of(ConfigurationPropertiesAutoConfiguration.class))
                .withUserConfiguration(GatewayPropertiesConfiguration.class)
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    assertThat(context.getBean(GatewayProperties.class).getRoutes()).anySatisfy(route -> {
                        assertThat(route.getId()).isEqualTo("admin-api");
                        assertThat(route.getUri()).isEqualTo(URI.create("http://localhost:8081"));
                        assertThat(route.getPredicates()).singleElement().satisfies(predicate -> {
                            assertThat(predicate.getName()).isEqualTo("Path");
                            assertThat(predicate.getArgs()).containsValue("/api/admin/**");
                        });
                    });
                });
    }

    @Test
    void doesNotBindRoutesFromLegacyGatewayPrefix() {
        new ApplicationContextRunner()
                .withConfiguration(AutoConfigurations.of(ConfigurationPropertiesAutoConfiguration.class))
                .withUserConfiguration(GatewayPropertiesConfiguration.class)
                .withPropertyValues(
                        "spring.cloud.gateway.routes[0].id=admin-api",
                        "spring.cloud.gateway.routes[0].uri=http://localhost:8081",
                        "spring.cloud.gateway.routes[0].predicates[0]=Path=/api/admin/**")
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    assertThat(context.getBean(GatewayProperties.class).getRoutes())
                            .noneMatch(route -> route.getId().equals("admin-api"));
                });
    }

    @TestConfiguration(proxyBeanMethods = false)
    @EnableConfigurationProperties(GatewayProperties.class)
    static class GatewayPropertiesConfiguration {
    }

    private String createToken(String secret, String issuer) throws Exception {
        var claims = new JWTClaimsSet.Builder()
                .subject("admin-user")
                .issuer(issuer)
                .issueTime(Date.from(Instant.now()))
                .expirationTime(Date.from(Instant.now().plusSeconds(300)))
                .build();
        var signedJwt = new SignedJWT(new JWSHeader(JWSAlgorithm.HS256), claims);
        signedJwt.sign(new MACSigner(secret.getBytes(StandardCharsets.UTF_8)));
        return signedJwt.serialize();
    }
}
