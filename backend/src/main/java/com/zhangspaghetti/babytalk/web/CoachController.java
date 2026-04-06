package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.PhaseOneAppService;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/coach")
@CrossOrigin(originPatterns = "*")
public class CoachController {

    private final PhaseOneAppService phaseOneAppService;

    public CoachController(PhaseOneAppService phaseOneAppService) {
        this.phaseOneAppService = phaseOneAppService;
    }

    @PostMapping("/ask")
    public BabyTalkPayloads.CoachAskResponse askCoach(
            @RequestHeader("X-Session-Id") String sessionId,
            @RequestBody BabyTalkPayloads.CoachAskRequest request
    ) {
        return phaseOneAppService.askCoach(sessionId, request);
    }
}