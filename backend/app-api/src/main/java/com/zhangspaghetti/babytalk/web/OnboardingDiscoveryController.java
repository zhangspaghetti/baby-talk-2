package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.OnboardingDiscoveryService;
import jakarta.validation.Valid;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/onboarding/discovery")
public class OnboardingDiscoveryController {

    private final OnboardingDiscoveryService onboardingDiscoveryService;

    public OnboardingDiscoveryController(OnboardingDiscoveryService onboardingDiscoveryService) {
        this.onboardingDiscoveryService = onboardingDiscoveryService;
    }

    @PostMapping
    public OnboardingDiscoveryService.OnboardingDiscoveryResponse discover(
            JwtAuthenticationToken authentication,
            @Valid @RequestBody OnboardingDiscoveryService.OnboardingDiscoveryRequest request
    ) {
        return onboardingDiscoveryService.discover(request, sessionId(authentication));
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            return null;
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        return sid == null || sid.isBlank() ? null : sid;
    }
}
