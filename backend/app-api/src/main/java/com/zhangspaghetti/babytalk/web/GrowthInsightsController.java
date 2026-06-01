package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.GrowthInsightsService;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/growth")
public class GrowthInsightsController {

    private final GrowthInsightsService growthInsightsService;

    public GrowthInsightsController(GrowthInsightsService growthInsightsService) {
        this.growthInsightsService = growthInsightsService;
    }

    @GetMapping("/insights")
    public GrowthInsightsService.GrowthInsightsResponse getInsights(
            JwtAuthenticationToken authentication,
            @RequestParam(value = "period", required = false) String period
    ) {
        return growthInsightsService.loadInsights(sessionId(authentication), period);
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "consumer_session_invalid", "访问令牌缺少 sid。", java.util.Map.of("field", "sid"));
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        if (sid == null || sid.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "consumer_session_invalid", "访问令牌缺少 sid。", java.util.Map.of("field", "sid"));
        }
        return sid;
    }
}
