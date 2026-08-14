package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.onboarding.conversation.OnboardingConversationAudioService;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/onboarding/conversations/{conversationId}/utterances/{utteranceId}")
public class OnboardingConversationAudioController {

    public static final String CAPABILITY_HEADER = "X-Onboarding-Audio-Capability";

    private final OnboardingConversationAudioService service;

    public OnboardingConversationAudioController(OnboardingConversationAudioService service) {
        this.service = service;
    }

    @GetMapping("/audio")
    public ResponseEntity<byte[]> audio(
            @PathVariable String conversationId,
            @PathVariable String utteranceId,
            @RequestHeader(name = CAPABILITY_HEADER, required = false) String capability
    ) {
        var audio = service.fetch(conversationId, utteranceId, capability);
        var bytes = audio.bytes();
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore().cachePrivate())
                .header(HttpHeaders.VARY, CAPABILITY_HEADER)
                .header("X-Generated-Audio-Voice-Version", audio.voiceVersion())
                .contentType(org.springframework.http.MediaType.parseMediaType(audio.mimeType()))
                .contentLength(bytes.length)
                .body(bytes);
    }
}
