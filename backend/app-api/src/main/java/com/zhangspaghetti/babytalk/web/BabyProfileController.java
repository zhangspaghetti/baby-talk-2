package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.profile.BabyProfileService;
import com.zhangspaghetti.babytalk.profile.dto.BabyProfileResponse;
import com.zhangspaghetti.babytalk.profile.dto.PutBabyProfileRequest;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Validated
@RequestMapping("/api/v1/onboarding/profile")
public class BabyProfileController {

    private final BabyProfileService babyProfileService;

    public BabyProfileController(BabyProfileService babyProfileService) {
        this.babyProfileService = babyProfileService;
    }

    @GetMapping
    public BabyProfileResponse getProfile(JwtAuthenticationToken authentication) {
        return babyProfileService.getProfile(sessionId(authentication));
    }

    @PutMapping
    public BabyProfileResponse putProfile(
            JwtAuthenticationToken authentication,
            @Valid @RequestBody PutBabyProfileRequest request
    ) {
        return babyProfileService.putProfile(sessionId(authentication), request);
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "consumer_session_invalid",
                    "访问令牌缺少 sid。",
                    Map.of("field", "sid")
            );
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        if (sid == null || sid.isBlank()) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "consumer_session_invalid",
                    "访问令牌缺少 sid。",
                    Map.of("field", "sid")
            );
        }
        return sid;
    }
}
