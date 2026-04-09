package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.MentorService;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
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
            @RequestHeader(value = "X-Session-Id", required = false) String sessionId,
            @RequestBody ChatRequest request
    ) {
        return mentorService.chat(
                new MentorService.ChatCommand(
                        request.installationId(),
                        request.prompt(),
                        request.surface(),
                        request.mode(),
                        request.correlationId(),
                        request.contextSummary()
                ),
                sessionId
        );
    }

    public record ChatRequest(
            String installationId,
            String prompt,
            String surface,
            String mode,
            String correlationId,
            String contextSummary
    ) {
    }
}
