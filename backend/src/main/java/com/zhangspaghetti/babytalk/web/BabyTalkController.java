package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.PhaseOneAppService;
import java.util.Map;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
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
    public BabyTalkPayloads.AppSnapshotResponse bootstrap() {
        return phaseOneAppService.bootstrap();
    }

    @PostMapping("/onboarding")
    public BabyTalkPayloads.AppSnapshotResponse completeOnboarding(
            @RequestBody BabyTalkPayloads.OnboardingRequest request
    ) {
        return phaseOneAppService.completeOnboarding(request);
    }

    @PostMapping("/reactions")
    public BabyTalkPayloads.AppActionResponse registerReaction(
            @RequestBody BabyTalkPayloads.PracticeReactionRequest request
    ) {
        return phaseOneAppService.registerReaction(request);
    }

    @PostMapping("/water")
    public BabyTalkPayloads.AppActionResponse waterPatch(
            @RequestBody BabyTalkPayloads.WaterPatchRequest request
    ) {
        return phaseOneAppService.waterPatch(request);
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }
}