package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.PhaseOneAppService;
import java.util.Map;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/app")
@CrossOrigin(originPatterns = "*")
public class BabyTalkController {

    private final PhaseOneAppService phaseOneAppService;

    public BabyTalkController(PhaseOneAppService phaseOneAppService) {
        this.phaseOneAppService = phaseOneAppService;
    }

    @GetMapping("/bootstrap")
    public BabyTalkPayloads.AppSnapshotResponse bootstrap(
            @RequestHeader("X-Session-Id") String sessionId
    ) {
        return phaseOneAppService.bootstrap(sessionId);
    }

    @PostMapping("/onboarding")
    public BabyTalkPayloads.AppSnapshotResponse completeOnboarding(
            @RequestHeader("X-Session-Id") String sessionId,
            @RequestBody BabyTalkPayloads.OnboardingRequest request
    ) {
        return phaseOneAppService.completeOnboarding(sessionId, request);
    }

    @PostMapping("/reactions")
    public BabyTalkPayloads.AppActionResponse registerReaction(
            @RequestHeader("X-Session-Id") String sessionId,
            @RequestBody BabyTalkPayloads.PracticeReactionRequest request
    ) {
        return phaseOneAppService.registerReaction(sessionId, request);
    }

    @PostMapping("/water")
    public BabyTalkPayloads.AppActionResponse waterPatch(
            @RequestHeader("X-Session-Id") String sessionId,
            @RequestBody BabyTalkPayloads.WaterPatchRequest request
    ) {
        return phaseOneAppService.waterPatch(sessionId, request);
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }
}