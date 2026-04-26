package com.zhangspaghetti.babytalk.admin.auth;

import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
public class AdminJwtAuthenticationConverter {

    private final AdminAuthorityService adminAuthorityService;

    public AdminJwtAuthenticationConverter(AdminAuthorityService adminAuthorityService) {
        this.adminAuthorityService = adminAuthorityService;
    }

    public AbstractAuthenticationToken convert(Jwt jwt) {
        var authoritySnapshot = adminAuthorityService.loadCurrentAuthorities(jwt.getSubject());
        return new JwtAuthenticationToken(
                jwt,
                authoritySnapshot.grantedAuthorities(),
                jwt.getClaimAsString("username")
        );
    }
}
