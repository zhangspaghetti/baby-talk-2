package com.zhangspaghetti.babytalk.security;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;

public class JwtTokenService {

    private final JwtEncoder jwtEncoder;
    private final JwtDecoder jwtDecoder;
    private final Clock clock;

    public JwtTokenService(JwtEncoder jwtEncoder, JwtDecoder jwtDecoder, Clock clock) {
        this.jwtEncoder = jwtEncoder;
        this.jwtDecoder = jwtDecoder;
        this.clock = clock;
    }

    public IssuedToken issueAccessToken(
            String issuer,
            String principalId,
            String username,
            String refreshTokenId,
            Collection<String> roleCodes,
            Duration ttl
    ) {
        var now = Instant.now(clock);
        var claims = JwtClaimsSet.builder()
                .issuer(issuer)
                .subject(principalId)
                .issuedAt(now)
                .expiresAt(now.plus(ttl))
                .id("aat_" + UUID.randomUUID())
                .claim("type", TokenType.ACCESS.claimValue())
                .claim("username", username)
                .claim("roles", List.copyOf(roleCodes))
                .claim("rtid", refreshTokenId)
                .build();
        return encode(claims);
    }

    public IssuedToken issueRefreshToken(
            String issuer,
            String principalId,
            String username,
            String refreshTokenId,
            Duration ttl
    ) {
        var now = Instant.now(clock);
        var claims = JwtClaimsSet.builder()
                .issuer(issuer)
                .subject(principalId)
                .issuedAt(now)
                .expiresAt(now.plus(ttl))
                .id(refreshTokenId)
                .claim("type", TokenType.REFRESH.claimValue())
                .claim("username", username)
                .build();
        return encode(claims);
    }

    public IssuedToken issueConsumerAccessToken(
            String issuer,
            String accountId,
            String sessionId,
            String refreshTokenId,
            Duration ttl
    ) {
        var now = Instant.now(clock);
        var claims = JwtClaimsSet.builder()
                .issuer(issuer)
                .subject(accountId)
                .issuedAt(now)
                .expiresAt(now.plus(ttl))
                .id("cat_" + UUID.randomUUID())
                .claim("type", TokenType.ACCESS.claimValue())
                .claim("sid", sessionId)
                .claim("rtid", refreshTokenId)
                .build();
        return encode(claims);
    }

    public IssuedToken issueConsumerRefreshToken(
            String issuer,
            String accountId,
            String sessionId,
            String refreshTokenId,
            Duration ttl
    ) {
        var now = Instant.now(clock);
        var claims = JwtClaimsSet.builder()
                .issuer(issuer)
                .subject(accountId)
                .issuedAt(now)
                .expiresAt(now.plus(ttl))
                .id(refreshTokenId)
                .claim("type", TokenType.REFRESH.claimValue())
                .claim("sid", sessionId)
                .claim("rtid", refreshTokenId)
                .build();
        return encode(claims);
    }

    public DecodedToken decode(String rawToken) {
        return new DecodedToken(rawToken, jwtDecoder.decode(rawToken));
    }

    private IssuedToken encode(JwtClaimsSet claimsSet) {
        var encoded = jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).type("JWT").build(),
                claimsSet));
        return new IssuedToken(
                encoded.getTokenValue(),
                encoded.getIssuedAt(),
                encoded.getExpiresAt(),
                encoded.getId());
    }

    public enum TokenType {
        ACCESS("access"),
        REFRESH("refresh");

        private final String claimValue;

        TokenType(String claimValue) {
            this.claimValue = claimValue;
        }

        public String claimValue() {
            return claimValue;
        }

        public static TokenType fromClaim(String claimValue) {
            for (var tokenType : values()) {
                if (tokenType.claimValue.equals(claimValue)) {
                    return tokenType;
                }
            }
            throw new IllegalArgumentException("Unsupported token type: " + claimValue);
        }
    }

    public record IssuedToken(String tokenValue, Instant issuedAt, Instant expiresAt, String tokenId) {
    }

    public record DecodedToken(String tokenValue, Jwt jwt) {

        public TokenType tokenType() {
            return TokenType.fromClaim(jwt.getClaimAsString("type"));
        }

        public String tokenId() {
            return jwt.getId();
        }

        public String subject() {
            return jwt.getSubject();
        }

        public String username() {
            return jwt.getClaimAsString("username");
        }

        public String sessionId() {
            return jwt.getClaimAsString("sid");
        }

        public String refreshTokenId() {
            return jwt.getClaimAsString("rtid");
        }

        public List<String> roleCodes() {
            var roles = jwt.getClaimAsStringList("roles");
            return roles == null ? List.of() : List.copyOf(roles);
        }

        public Instant issuedAt() {
            return jwt.getIssuedAt();
        }

        public Instant expiresAt() {
            return jwt.getExpiresAt();
        }
    }
}
