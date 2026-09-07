package com.zhangspaghetti.babytalk.practice.scene;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.HashSet;
import java.util.Set;
import tools.jackson.core.JacksonException;
import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.ValueDeserializer;
import tools.jackson.databind.annotation.JsonDeserialize;

/** Strict wire command for profile-owned scene generation. */
@JsonDeserialize(using = SceneGenerationRequest.StrictDeserializer.class)
@JsonIgnoreProperties(ignoreUnknown = false)
public record SceneGenerationRequest(
        SourceRequest source,
        String locale,
        String installationId,
        String clientRequestId
) {

    public SceneGenerationRequest {
        if (source == null || locale == null || installationId == null || clientRequestId == null) {
            throw new InvalidSceneSourceException();
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = false)
    public record SourceRequest(String type, String text, String presetSceneId) {

        public SourceRequest {
            if (type == null || (!"custom".equals(type) && !"preset".equals(type))) {
                throw new InvalidSceneSourceException();
            }
            if ("custom".equals(type)
                    ? text == null || presetSceneId != null
                    : presetSceneId == null || text != null) {
                throw new InvalidSceneSourceException();
            }
        }

        @JsonAnySetter
        public void rejectUnknownField(String fieldName, Object ignored) {
            throw new InvalidSceneSourceException();
        }
    }

    @JsonAnySetter
    public void rejectUnknownField(String fieldName, Object ignored) {
        throw new InvalidSceneSourceException();
    }

    /** Marker used by the HTTP layer to keep malformed scene bodies privacy-safe. */
    public static final class InvalidSceneSourceException extends IllegalArgumentException {

        public InvalidSceneSourceException() {
            super("invalid_scene_source");
        }
    }

    /** Manual parser prevents Jackson's normal scalar coercions and duplicate-key overwrites. */
    public static final class StrictDeserializer extends ValueDeserializer<SceneGenerationRequest> {

        @Override
        public SceneGenerationRequest deserialize(JsonParser parser, DeserializationContext context)
                throws JacksonException {
            if (parser.currentToken() == null) {
                parser.nextToken();
            }
            if (parser.currentToken() != JsonToken.START_OBJECT) {
                return invalid();
            }

            var fields = new HashSet<String>();
            SourceRequest source = null;
            String locale = null;
            String installationId = null;
            String clientRequestId = null;
            while (parser.nextToken() != JsonToken.END_OBJECT) {
                if (parser.currentToken() != JsonToken.PROPERTY_NAME) {
                    return invalid();
                }
                var field = parser.currentName();
                if (!fields.add(field)) {
                    return invalid();
                }
                var valueToken = parser.nextToken();
                switch (field) {
                    case "source" -> source = parseSource(parser, valueToken);
                    case "locale" -> locale = parseString(parser, valueToken);
                    case "installationId" -> installationId = parseString(parser, valueToken);
                    case "clientRequestId" -> clientRequestId = parseString(parser, valueToken);
                    default -> {
                        return invalid();
                    }
                }
            }
            if (source == null || locale == null || installationId == null || clientRequestId == null
                    || fields.size() != 4) {
                return invalid();
            }
            if (parser.nextToken() != null) {
                return invalid();
            }
            return new SceneGenerationRequest(source, locale, installationId, clientRequestId);
        }

        private SourceRequest parseSource(JsonParser parser, JsonToken valueToken) throws JacksonException {
            if (valueToken != JsonToken.START_OBJECT) {
                return invalid();
            }
            var fields = new HashSet<String>();
            String type = null;
            String text = null;
            String presetSceneId = null;
            while (parser.nextToken() != JsonToken.END_OBJECT) {
                if (parser.currentToken() != JsonToken.PROPERTY_NAME) {
                    return invalid();
                }
                var field = parser.currentName();
                if (!fields.add(field)) {
                    return invalid();
                }
                var token = parser.nextToken();
                switch (field) {
                    case "type" -> type = parseString(parser, token);
                    case "text" -> text = parseString(parser, token);
                    case "presetSceneId" -> presetSceneId = parseString(parser, token);
                    default -> {
                        return invalid();
                    }
                }
            }
            if (type == null) {
                return invalid();
            }
            if ("custom".equals(type)) {
                if (fields.size() != 2 || text == null || presetSceneId != null) {
                    return invalid();
                }
            } else if ("preset".equals(type)) {
                if (fields.size() != 2 || presetSceneId == null || text != null) {
                    return invalid();
                }
            } else {
                return invalid();
            }
            return new SourceRequest(type, text, presetSceneId);
        }

        private String parseString(JsonParser parser, JsonToken token) {
            if (token != JsonToken.VALUE_STRING) {
                return invalid();
            }
            return parser.getString();
        }

        private <T> T invalid() {
            throw new InvalidSceneSourceException();
        }
    }
}
