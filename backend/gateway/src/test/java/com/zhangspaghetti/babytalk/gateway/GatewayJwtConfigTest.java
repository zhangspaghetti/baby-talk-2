package com.zhangspaghetti.babytalk.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import org.junit.jupiter.api.Test;
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
