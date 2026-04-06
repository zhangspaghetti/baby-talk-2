package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.PhaseOneAppService;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
@CrossOrigin(originPatterns = "*")
public class AuthController {

    private final PhaseOneAppService phaseOneAppService;

    public AuthController(PhaseOneAppService phaseOneAppService) {
        this.phaseOneAppService = phaseOneAppService;
    }

    @PostMapping("/session")
    public BabyTalkPayloads.SessionResponse createSession() {
        return phaseOneAppService.createSession();
    }
}