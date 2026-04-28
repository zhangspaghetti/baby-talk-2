package com.zhangspaghetti.babytalk.web;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.zhangspaghetti.babytalk.service.MentorService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Validated
@RequestMapping("/api/v1/mentor")
public class MentorController {

    private final MentorService mentorService;

    public MentorController(MentorService mentorService) {
        this.mentorService = mentorService;
    }

    @PostMapping("/chat")
    public MentorService.ChatResponse chat(
            @AuthenticationPrincipal Jwt authenticatedJwt,
            @RequestBody ChatRequest request
    ) {
        return mentorService.chat(
                new MentorService.ChatCommand(
                        request.installationId(),
                        request.prompt(),
                        request.surface(),
                        request.mode(),
                        request.correlationId(),
                        request.contextSummary(),
                        request.conversationId(),
                        request.childAgeMonths()
                ),
                authenticatedJwt == null ? null : authenticatedJwt.getClaimAsString("sid")
        );
    }

    @PostMapping("/practice/generate")
    public MentorService.PracticeGenerateResponse practiceGenerate(
            @AuthenticationPrincipal Jwt authenticatedJwt,
            @RequestBody PracticeGenerateRequest request
    ) {
        return mentorService.generatePractice(
                new MentorService.PracticeGenerateCommand(
                        request.installationId(),
                        request.surface(),
                        request.babyAgeMonths(),
                        request.sceneTag(),
                        request.conversationId()
                ),
                authenticatedJwt == null ? null : authenticatedJwt.getClaimAsString("sid")
        );
    }

    public record ChatRequest(
            String installationId,
            String prompt,
            String surface,
            String mode,
            String correlationId,
            String contextSummary,
            String conversationId,
            @JsonProperty("childAgeMonths") Integer childAgeMonths
    ) {
    }

    public record PracticeGenerateRequest(
            String installationId,
            String surface,
            int babyAgeMonths,
            String sceneTag,
            String conversationId
    ) {
    }
}
