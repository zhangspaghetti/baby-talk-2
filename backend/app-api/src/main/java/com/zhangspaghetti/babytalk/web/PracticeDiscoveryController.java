package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryService;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryRequest;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryResponse;
import jakarta.validation.Valid;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/practice/discovery")
public class PracticeDiscoveryController {

    private final PracticeDiscoveryService practiceDiscoveryService;

    public PracticeDiscoveryController(PracticeDiscoveryService practiceDiscoveryService) {
        this.practiceDiscoveryService = practiceDiscoveryService;
    }

    @PostMapping
    public PracticeDiscoveryResponse discover(
            JwtAuthenticationToken authentication,
            @Valid @RequestBody PracticeDiscoveryRequest request
    ) {
        return practiceDiscoveryService.discover(request, sessionId(authentication));
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            return null;
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        return sid == null || sid.isBlank() ? null : sid;
    }
}
