package com.zhangspaghetti.babytalk.palace.projection;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Maps Jackson 3 trees to PostgreSQL JSON/JSONB text without invoking Hibernate's Jackson 2 mapper.
 */
@Converter
public class ToolsJacksonJsonNodeConverter implements AttributeConverter<JsonNode, String> {

    private static final JsonMapper OBJECT_MAPPER = JsonMapper.builder().build();

    @Override
    public String convertToDatabaseColumn(JsonNode attribute) {
        return attribute == null ? null : attribute.toString();
    }

    @Override
    public JsonNode convertToEntityAttribute(String databaseValue) {
        if (databaseValue == null) {
            return null;
        }
        try {
            return OBJECT_MAPPER.readTree(databaseValue);
        } catch (JacksonException exception) {
            throw new IllegalArgumentException("Invalid JSONB value for Jackson 3 tree", exception);
        }
    }
}
