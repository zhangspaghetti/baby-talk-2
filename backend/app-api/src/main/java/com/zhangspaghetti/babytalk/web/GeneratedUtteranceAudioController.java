package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedUtteranceAudioService;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/practice/generated-content/{generatedContentId}/utterances/{utteranceId}")
public class GeneratedUtteranceAudioController {

    private final GeneratedUtteranceAudioService generatedUtteranceAudioService;

    public GeneratedUtteranceAudioController(GeneratedUtteranceAudioService generatedUtteranceAudioService) {
        this.generatedUtteranceAudioService = generatedUtteranceAudioService;
    }

    @GetMapping("/audio")
    public ResponseEntity<byte[]> audio(
            JwtAuthenticationToken authentication,
            @PathVariable String generatedContentId,
            @PathVariable String utteranceId
    ) {
        var audio = generatedUtteranceAudioService.synthesize(
                generatedContentId,
                utteranceId,
                sessionId(authentication)
        );
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore().cachePrivate())
                .header(HttpHeaders.VARY, HttpHeaders.AUTHORIZATION)
                .header("X-Generated-Audio-Voice-Version", audio.voiceVersion())
                .contentType(MediaType.parseMediaType(audio.mimeType()))
                .contentLength(audio.bytes().length)
                .body(audio.bytes());
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            return null;
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        return sid == null || sid.isBlank() ? null : sid;
    }
}
