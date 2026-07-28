package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedAudioResponse;
import com.zhangspaghetti.babytalk.practice.generated.audio.GeneratedUtteranceAudioService;
import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.http.HttpHeaders;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

class GeneratedUtteranceAudioControllerTest {

    @Test
    void returnsPrivateNoStoreAudioWithTheConfiguredMimeAndVoiceVersion() {
        var service = Mockito.mock(GeneratedUtteranceAudioService.class);
        when(service.synthesize("pgc_1", "utt_1", "session_1"))
                .thenReturn(new GeneratedAudioResponse(new byte[] {3, 2, 1}, "audio/mpeg", "generated-tts-v1"));
        var controller = new GeneratedUtteranceAudioController(service);

        var response = controller.audio(authentication("session_1"), "pgc_1", "utt_1");

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getHeaders().getContentType().toString()).isEqualTo("audio/mpeg");
        assertThat(response.getHeaders().getFirst(HttpHeaders.CACHE_CONTROL))
                .contains("private")
                .contains("no-store");
        assertThat(response.getHeaders().getFirst(HttpHeaders.VARY)).isEqualTo(HttpHeaders.AUTHORIZATION);
        assertThat(response.getHeaders().getFirst("X-Generated-Audio-Voice-Version"))
                .isEqualTo("generated-tts-v1");
        assertThat(response.getBody()).containsExactly(3, 2, 1);
        verify(service).synthesize("pgc_1", "utt_1", "session_1");
    }

    @Test
    void missingAuthenticationIsDelegatedToTheOwnerCheckingService() {
        var service = Mockito.mock(GeneratedUtteranceAudioService.class);
        when(service.synthesize("pgc_1", "utt_1", null))
                .thenThrow(new ContractException(
                        org.springframework.http.HttpStatus.UNAUTHORIZED,
                        "consumer_authentication_required",
                        "需要登录。"
                ));
        var controller = new GeneratedUtteranceAudioController(service);

        assertThatThrownBy(() -> controller.audio(null, "pgc_1", "utt_1"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> assertThat(((ContractException) error).code())
                        .isEqualTo("consumer_authentication_required"));

        verify(service).synthesize("pgc_1", "utt_1", null);
    }

    private JwtAuthenticationToken authentication(String sessionId) {
        var jwt = new Jwt(
                "access-token",
                Instant.now(),
                Instant.now().plusSeconds(60),
                Map.of("alg", "none"),
                Map.of("sid", sessionId)
        );
        return new JwtAuthenticationToken(jwt);
    }
}
