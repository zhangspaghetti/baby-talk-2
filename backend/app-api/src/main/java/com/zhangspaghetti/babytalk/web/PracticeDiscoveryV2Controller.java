package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryService;
import com.zhangspaghetti.babytalk.practice.discovery.dto.CustomSceneDiscoveryV2Response;
import com.zhangspaghetti.babytalk.practice.discovery.dto.PracticeDiscoveryRequest;
import jakarta.validation.Valid;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v2/practice/discovery")
public class PracticeDiscoveryV2Controller {

    private final PracticeDiscoveryService practiceDiscoveryService;

    public PracticeDiscoveryV2Controller(PracticeDiscoveryService practiceDiscoveryService) {
        this.practiceDiscoveryService = practiceDiscoveryService;
    }

    @PostMapping
    public CustomSceneDiscoveryV2Response discover(
            JwtAuthenticationToken authentication,
            @Valid @RequestBody PracticeDiscoveryRequest request
    ) {
        return practiceDiscoveryService.discoverCustomSceneV2(request, sessionId(authentication));
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            return null;
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        return sid == null || sid.isBlank() ? null : sid;
    }
}
