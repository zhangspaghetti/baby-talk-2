package com.zhangspaghetti.babytalk.practice.agentic;

import java.util.ArrayDeque;
import java.util.Objects;
import org.springframework.ai.converter.BeanOutputConverter;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;

/** Publishes the exact JSON Schema sent to structured-output providers. */
public final class PracticeAiJsonSchemaPublisher {

    static final int MAX_SCHEMA_DEPTH = 128;
    static final int MAX_SCHEMA_NODES = 4_096;

    private static final JsonMapper JSON_MAPPER = JsonMapper.builder().build();

    private PracticeAiJsonSchemaPublisher() {
    }

    public static String publish(BeanOutputConverter<?> converter) {
        Objects.requireNonNull(converter, "converter");
        return publish(converter.getJsonSchema());
    }

    static String publish(String jsonSchema) {
        try {
            var schema = JSON_MAPPER.readTree(jsonSchema);
            addNullToNullableEnums(schema);
            return schema.toString();
        } catch (JacksonException exception) {
            throw new IllegalStateException("practice_ai_json_schema_invalid", exception);
        }
    }

    private static void addNullToNullableEnums(JsonNode root) {
        var pending = new ArrayDeque<SchemaNode>();
        pending.push(new SchemaNode(root, 0));
        var visitedNodes = 0;

        while (!pending.isEmpty()) {
            var current = pending.pop();
            if (current.depth() > MAX_SCHEMA_DEPTH || ++visitedNodes > MAX_SCHEMA_NODES) {
                throw new IllegalStateException("practice_ai_json_schema_too_complex");
            }

            var node = current.node();
            if (node.isObject()) {
                var enumValues = node.get("enum");
                if (enumValues instanceof ArrayNode array
                        && typeAllowsNull(node.get("type"))
                        && java.util.stream.StreamSupport.stream(array.spliterator(), false)
                                .noneMatch(JsonNode::isNull)) {
                    array.addNull();
                }
                node.properties().forEach(property ->
                        pending.push(new SchemaNode(property.getValue(), current.depth() + 1)));
            } else if (node.isArray()) {
                node.forEach(child -> pending.push(new SchemaNode(child, current.depth() + 1)));
            }
        }
    }

    private record SchemaNode(JsonNode node, int depth) {
        private SchemaNode {
            Objects.requireNonNull(node, "node");
        }
    }

    private static boolean typeAllowsNull(JsonNode type) {
        if (type == null) {
            return false;
        }
        if (type.isTextual()) {
            return "null".equals(type.textValue());
        }
        return type.isArray()
                && java.util.stream.StreamSupport.stream(type.spliterator(), false)
                        .anyMatch(value -> value.isTextual() && "null".equals(value.textValue()));
    }
}
