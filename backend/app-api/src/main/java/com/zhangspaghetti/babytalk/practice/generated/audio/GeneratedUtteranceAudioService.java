package com.zhangspaghetti.babytalk.practice.generated.audio;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentQueryMapper;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GeneratedUtteranceAudioService {

    private static final Pattern SAFE_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$");

    private final AuthConsentSyncService authConsentSyncService;
    private final PracticeGeneratedContentQueryMapper queryMapper;
    private final GeneratedSpeechSynthesisPort speechSynthesisPort;
    private final GeneratedSpeechProperties properties;

    public GeneratedUtteranceAudioService(
            AuthConsentSyncService authConsentSyncService,
            PracticeGeneratedContentQueryMapper queryMapper,
            GeneratedSpeechSynthesisPort speechSynthesisPort,
            GeneratedSpeechProperties properties
    ) {
        this.authConsentSyncService = authConsentSyncService;
        this.queryMapper = queryMapper;
        this.speechSynthesisPort = speechSynthesisPort;
        this.properties = properties;
    }

    @Transactional(readOnly = true)
    public GeneratedUtteranceAudio synthesize(String generatedContentId, String utteranceId, String sessionId) {
        var session = authConsentSyncService.requireAcceptedConsumerSession(sessionId, "播放已批准的自定义场景语音");
        var contentId = requireSafeId(generatedContentId);
        var approvedUtteranceId = requireSafeId(utteranceId);
        var utterance = queryMapper.findPlayableOwnedActiveBundleUtterance(
                contentId, approvedUtteranceId, session.accountId());
        if (utterance == null) {
            throw audioNotFound();
        }
        try {
            var response = validateResponse(speechSynthesisPort.synthesize(
                    new GeneratedSpeechSynthesisPort.GeneratedSpeechRequest(
                            contentId, approvedUtteranceId, utterance.englishText())));
            return new GeneratedUtteranceAudio(
                    response.bytes(), response.mimeType(), response.voiceVersion(), properties.configurationIdentity());
        } catch (ContractException exception) {
            throw exception;
        } catch (GeneratedSpeechSynthesisException exception) {
            throw providerFailure(exception);
        } catch (RuntimeException exception) {
            throw providerFailure(GeneratedSpeechSynthesisException.unavailable(exception));
        }
    }

    private GeneratedAudioResponse validateResponse(GeneratedAudioResponse response) {
        if (response == null
                || response.bytes().length == 0
                || response.bytes().length > properties.maxBytes()
                || !properties.mimeType().equals(response.mimeType())
                || !properties.voiceVersion().equals(response.voiceVersion())) {
            throw new ContractException(
                    HttpStatus.BAD_GATEWAY,
                    "generated_audio_invalid_response",
                    "生成语音服务返回了不可播放的数据。"
            );
        }
        return response;
    }

    private String requireSafeId(String value) {
        if (value == null || !SAFE_ID.matcher(value).matches()) {
            throw audioNotFound();
        }
        return value;
    }

    private ContractException audioNotFound() {
        return new ContractException(HttpStatus.NOT_FOUND, "generated_audio_not_found", "未找到可播放的生成语音。");
    }

    private ContractException providerFailure(GeneratedSpeechSynthesisException exception) {
        return switch (exception.kind()) {
            case TIMEOUT -> new ContractException(
                    HttpStatus.GATEWAY_TIMEOUT,
                    "generated_audio_timeout",
                    "生成语音超时，请稍后再试。",
                    Map.of("retryable", true)
            );
            case DISABLED -> new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "generated_audio_unavailable",
                    "生成语音暂不可用。",
                    Map.of("retryable", false)
            );
            case UNAVAILABLE -> new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "generated_audio_unavailable",
                    "生成语音暂不可用。",
                    Map.of("retryable", true)
            );
        };
    }
}
