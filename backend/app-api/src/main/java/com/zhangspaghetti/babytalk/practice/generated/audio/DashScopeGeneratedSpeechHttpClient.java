package com.zhangspaghetti.babytalk.practice.generated.audio;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Locale;
import java.util.Set;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.node.ObjectNode;
import tools.jackson.databind.json.JsonMapper;

final class DashScopeGeneratedSpeechHttpClient implements GeneratedSpeechClient {

    private static final JsonMapper JSON_MAPPER = JsonMapper.builder().build();
    private static final MediaType AUDIO_MPEG = MediaType.parseMediaType("audio/mpeg");
    private static final int SAMPLE_RATE = 24_000;
    private static final int[] MPEG_1_LAYER_III_KBPS =
            {0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0};
    private static final int[] MPEG_2_LAYER_III_KBPS =
            {0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0};
    private static final int[] MPEG_1_SAMPLE_RATES = {44_100, 48_000, 32_000};

    private final GeneratedSpeechProperties properties;
    private final String apiKey;
    private final RestClient restClient;

    DashScopeGeneratedSpeechHttpClient(GeneratedSpeechProperties properties, String apiKey) {
        this(properties, apiKey, restClientBuilder(properties.timeout()));
    }

    DashScopeGeneratedSpeechHttpClient(
            GeneratedSpeechProperties properties,
            String apiKey,
            RestClient.Builder restClientBuilder
    ) {
        this.properties = properties;
        this.apiKey = requireApiKey(apiKey);
        this.restClient = restClientBuilder.build();
    }

    @Override
    public byte[] synthesize(String approvedEnglishText) {
        try {
            var requestBody = requestBody(approvedEnglishText);
            var envelope = restClient.post()
                    .uri(properties.baseUrl())
                    .contentType(MediaType.APPLICATION_JSON)
                    .headers(headers -> headers.setBearerAuth(apiKey))
                    .body(requestBody)
                    .exchange((request, response) -> readEnvelope(response));
            var downloadUri = requireAllowlistedDownloadUri(audioUrl(envelope));
            return restClient.get()
                    .uri(downloadUri)
                    .exchange((request, response) -> readAudio(response));
        } catch (GeneratedSpeechSynthesisException exception) {
            throw exception;
        } catch (ResourceAccessException exception) {
            throw timeoutLike(exception)
                    ? GeneratedSpeechSynthesisException.timeout(null)
                    : GeneratedSpeechSynthesisException.unavailable(null);
        } catch (RuntimeException exception) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
    }

    private byte[] requestBody(String approvedEnglishText) {
        var root = JSON_MAPPER.createObjectNode();
        root.put("model", properties.model());
        var input = root.putObject("input");
        input.put("text", approvedEnglishText);
        input.put("voice", properties.voice());
        input.put("format", properties.format());
        input.put("sample_rate", SAMPLE_RATE);
        return JSON_MAPPER.writeValueAsBytes(root);
    }

    private byte[] readEnvelope(ClientHttpResponse response) throws IOException {
        requireSuccess(response.getStatusCode());
        requireContentType(response.getHeaders(), MediaType.APPLICATION_JSON);
        return readBounded(response, properties.responseMaxBytes());
    }

    private String audioUrl(byte[] envelope) {
        try {
            var root = JSON_MAPPER.readTree(envelope);
            if (!(root instanceof ObjectNode rootObject)
                    || !(rootObject.get("output") instanceof ObjectNode output)
                    || !"stop".equals(text(output, "finish_reason"))
                    || !(output.get("audio") instanceof ObjectNode audio)
                    || !isEmptyString(audio, "data")) {
                throw GeneratedSpeechSynthesisException.unavailable(null);
            }
            var url = text(audio, "url");
            if (url.isBlank()) {
                throw GeneratedSpeechSynthesisException.unavailable(null);
            }
            return url;
        } catch (JacksonException exception) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
    }

    private URI requireAllowlistedDownloadUri(String value) {
        URI uri;
        try {
            uri = URI.create(value);
        } catch (IllegalArgumentException exception) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
        var host = uri.getHost();
        if (host == null
                || uri.getUserInfo() != null
                || uri.getFragment() != null
                || uri.getPort() != -1
                || !properties.allowedDownloadHosts().contains(host.toLowerCase(Locale.ROOT))) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
        if ("https".equalsIgnoreCase(uri.getScheme())) {
            return uri;
        }
        if (!"http".equalsIgnoreCase(uri.getScheme())) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
        try {
            return new URI("https", null, host, -1, uri.getPath(), uri.getQuery(), null);
        } catch (java.net.URISyntaxException exception) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
    }

    private byte[] readAudio(ClientHttpResponse response) throws IOException {
        requireSuccess(response.getStatusCode());
        requireContentType(response.getHeaders(), AUDIO_MPEG);
        var audio = readBounded(response, properties.maxBytes());
        if (!isMp3(audio)) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
        return audio;
    }

    private void requireSuccess(HttpStatusCode status) {
        if (!status.is2xxSuccessful()) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
    }

    private void requireContentType(HttpHeaders headers, MediaType expected) {
        var actual = headers.getContentType();
        if (actual == null || !expected.isCompatibleWith(actual)) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
    }

    private byte[] readBounded(ClientHttpResponse response, int maxBytes) {
        var declaredLength = response.getHeaders().getContentLength();
        if (declaredLength > maxBytes) {
            throw GeneratedSpeechSynthesisException.unavailable(null);
        }
        try {
            var bytes = response.getBody().readNBytes(maxBytes + 1);
            if (bytes.length == 0 || bytes.length > maxBytes) {
                throw GeneratedSpeechSynthesisException.unavailable(null);
            }
            return bytes;
        } catch (IOException exception) {
            throw timeoutLike(exception)
                    ? GeneratedSpeechSynthesisException.timeout(null)
                    : GeneratedSpeechSynthesisException.unavailable(null);
        }
    }

    private static String text(ObjectNode node, String field) {
        var value = node.get(field);
        return value != null && value.isString() ? value.asText() : "";
    }

    private static boolean isEmptyString(ObjectNode node, String field) {
        var value = node.get(field);
        return value != null && value.isString() && value.asText().isEmpty();
    }

    private static boolean isMp3(byte[] bytes) {
        var frameOffset = id3FrameOffset(bytes);
        return frameOffset >= 0 && hasCompleteMpegLayerThreeFrame(bytes, frameOffset);
    }

    private static int id3FrameOffset(byte[] bytes) {
        if (bytes.length < 3 || bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
            return 0;
        }
        if (bytes.length < 10) {
            return -1;
        }
        var majorVersion = Byte.toUnsignedInt(bytes[3]);
        var revision = Byte.toUnsignedInt(bytes[4]);
        var flags = Byte.toUnsignedInt(bytes[5]);
        var reservedFlagMask = switch (majorVersion) {
            case 2 -> 0x3f;
            case 3 -> 0x1f;
            case 4 -> 0x0f;
            default -> -1;
        };
        if (revision == 0xff || reservedFlagMask < 0 || (flags & reservedFlagMask) != 0) {
            return -1;
        }
        var tagSize = 0;
        for (var index = 6; index < 10; index++) {
            var value = Byte.toUnsignedInt(bytes[index]);
            if ((value & 0x80) != 0) {
                return -1;
            }
            tagSize = (tagSize << 7) | value;
        }
        var frameOffset = 10 + tagSize;
        if (frameOffset > bytes.length) {
            return -1;
        }
        if (majorVersion == 4 && (flags & 0x10) != 0) {
            if (bytes.length - frameOffset < 10
                    || bytes[frameOffset] != 0x33
                    || bytes[frameOffset + 1] != 0x44
                    || bytes[frameOffset + 2] != 0x49) {
                return -1;
            }
            for (var index = 3; index < 10; index++) {
                if (bytes[frameOffset + index] != bytes[index]) {
                    return -1;
                }
            }
            frameOffset += 10;
        }
        return frameOffset;
    }

    private static boolean hasCompleteMpegLayerThreeFrame(byte[] bytes, int offset) {
        if (bytes.length - offset < 4) {
            return false;
        }
        var header = (Byte.toUnsignedInt(bytes[offset]) << 24)
                | (Byte.toUnsignedInt(bytes[offset + 1]) << 16)
                | (Byte.toUnsignedInt(bytes[offset + 2]) << 8)
                | Byte.toUnsignedInt(bytes[offset + 3]);
        if ((header & 0xffe00000) != 0xffe00000) {
            return false;
        }
        var version = (header >>> 19) & 0x3;
        var layer = (header >>> 17) & 0x3;
        var bitrateIndex = (header >>> 12) & 0xf;
        var sampleRateIndex = (header >>> 10) & 0x3;
        var emphasis = header & 0x3;
        if (version == 1 || layer != 1 || bitrateIndex == 0 || bitrateIndex == 0xf
                || sampleRateIndex == 0x3 || emphasis == 0x2) {
            return false;
        }
        var bitrateKbps = version == 3
                ? MPEG_1_LAYER_III_KBPS[bitrateIndex]
                : MPEG_2_LAYER_III_KBPS[bitrateIndex];
        var sampleRate = MPEG_1_SAMPLE_RATES[sampleRateIndex];
        if (version == 2) {
            sampleRate /= 2;
        } else if (version == 0) {
            sampleRate /= 4;
        }
        var padding = (header >>> 9) & 0x1;
        var coefficient = version == 3 ? 144 : 72;
        var frameLength = coefficient * bitrateKbps * 1_000 / sampleRate + padding;
        return frameLength >= 4 && bytes.length - offset >= frameLength;
    }

    private static String requireApiKey(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("generated speech provider secret must not be blank");
        }
        return value.trim();
    }

    private static RestClient.Builder restClientBuilder(Duration timeout) {
        var httpClient = HttpClient.newBuilder()
                .connectTimeout(timeout)
                .followRedirects(HttpClient.Redirect.NEVER)
                .build();
        var requestFactory = new JdkClientHttpRequestFactory(httpClient);
        requestFactory.setReadTimeout(timeout);
        return RestClient.builder().requestFactory(requestFactory);
    }

    private static boolean timeoutLike(Throwable exception) {
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof java.net.http.HttpTimeoutException
                    || cause instanceof java.net.SocketTimeoutException
                    || cause instanceof java.util.concurrent.TimeoutException) {
                return true;
            }
        }
        return false;
    }
}
