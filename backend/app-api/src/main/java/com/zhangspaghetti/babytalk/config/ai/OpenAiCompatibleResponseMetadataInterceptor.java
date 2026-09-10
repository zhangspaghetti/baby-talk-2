package com.zhangspaghetti.babytalk.config.ai;

import java.io.IOException;
import java.util.Locale;
import okhttp3.Interceptor;
import okhttp3.Response;
import okhttp3.ResponseBody;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Normalizes nullable metadata emitted by some OpenAI-compatible providers before the OpenAI SDK
 * applies its stricter wire contract. No request field or completion content is changed.
 */
public final class OpenAiCompatibleResponseMetadataInterceptor implements Interceptor {

    private static final JsonMapper JSON_MAPPER = JsonMapper.builder().build();
    private static final String[] TOKEN_FIELDS = {
            "prompt_tokens", "completion_tokens", "total_tokens"
    };

    @Override
    public Response intercept(Chain chain) throws IOException {
        var response = chain.proceed(chain.request());
        var body = response.body();
        if (!eligible(response, body)) {
            return response;
        }

        var contentType = body.contentType();
        var original = body.bytes();
        var normalized = normalize(original);
        return response.newBuilder()
                .removeHeader("Content-Length")
                .body(ResponseBody.create(normalized, contentType))
                .build();
    }

    private boolean eligible(Response response, ResponseBody body) {
        if (!response.isSuccessful() || body == null) {
            return false;
        }
        var contentType = body.contentType();
        return response.request().url().encodedPath().endsWith("/chat/completions")
                && contentType != null
                && contentType.subtype().toLowerCase(Locale.ROOT).endsWith("json");
    }

    private byte[] normalize(byte[] original) {
        try {
            var root = JSON_MAPPER.readTree(original);
            if (!(root instanceof ObjectNode rootObject)) {
                return original;
            }
            boolean changed = normalizeUsage(rootObject);
            changed |= normalizeFinishReasons(rootObject);
            return changed ? JSON_MAPPER.writeValueAsBytes(rootObject) : original;
        } catch (JacksonException exception) {
            return original;
        }
    }

    private boolean normalizeUsage(ObjectNode root) {
        if (!(root.get("usage") instanceof ObjectNode usage)) {
            return false;
        }
        boolean changed = false;
        for (String fieldName : TOKEN_FIELDS) {
            var field = usage.get(fieldName);
            if (field == null || field.isNull()) {
                usage.put(fieldName, 0);
                changed = true;
            }
        }
        return changed;
    }

    private boolean normalizeFinishReasons(ObjectNode root) {
        if (!(root.get("choices") instanceof ArrayNode choices)) {
            return false;
        }
        boolean changed = false;
        for (var choiceNode : choices) {
            if (choiceNode instanceof ObjectNode choice) {
                var finishReason = choice.get("finish_reason");
                if (finishReason == null || finishReason.isNull()) {
                    choice.put("finish_reason", "unknown");
                    changed = true;
                }
            }
        }
        return changed;
    }
}
