package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.document.Document;

/**
 * MemPalaceMetadataEnricher 单元测试 — 验证宫殿坐标注入逻辑。
 */
class MemPalaceMetadataEnricherTest {

    private MemPalaceMetadataEnricher enricher;

    @BeforeEach
    void setUp() {
        enricher = new MemPalaceMetadataEnricher();
    }

    @Test
    void apply_knownBook_injectsCorrectPalaceCoordinates() {
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("source_book", "Brain Rules for Baby");
        Document doc = new Document("some text content", metadata);

        List<Document> result = enricher.apply(List.of(doc));

        assertThat(result).hasSize(1);
        Map<String, Object> enrichedMeta = result.get(0).getMetadata();
        assertThat(enrichedMeta.get("wing")).isEqualTo("cognitive");
        assertThat(enrichedMeta.get("room")).isEqualTo("brain_science");
        assertThat(enrichedMeta.get("hall")).isEqualTo("neural_pathways_hall");
        assertThat(enrichedMeta.get("age_range")).isEqualTo("0-5");
    }

    @Test
    void apply_unknownBook_injectsDefaultCoordinates() {
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("source_book", "Unknown Book");
        Document doc = new Document("some text content", metadata);

        List<Document> result = enricher.apply(List.of(doc));

        assertThat(result).hasSize(1);
        Map<String, Object> enrichedMeta = result.get(0).getMetadata();
        assertThat(enrichedMeta.get("wing")).isEqualTo("parenting_skills");
        assertThat(enrichedMeta.get("room")).isEqualTo("overview");
        assertThat(enrichedMeta.get("hall")).isEqualTo("main_hall");
        assertThat(enrichedMeta.get("age_range")).isEqualTo("0-6");
    }

    @Test
    void apply_missingSourceBook_usesDefault() {
        Map<String, Object> metadata = new HashMap<>();
        // source_book 缺失
        Document doc = new Document("some text content", metadata);

        List<Document> result = enricher.apply(List.of(doc));

        Map<String, Object> enrichedMeta = result.get(0).getMetadata();
        assertThat(enrichedMeta.get("wing")).isEqualTo("parenting_skills");
        assertThat(enrichedMeta.get("room")).isEqualTo("overview");
    }

    @Test
    void apply_emptySourceBook_usesDefault() {
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("source_book", "");
        Document doc = new Document("some text content", metadata);

        List<Document> result = enricher.apply(List.of(doc));

        Map<String, Object> enrichedMeta = result.get(0).getMetadata();
        assertThat(enrichedMeta.get("wing")).isEqualTo("parenting_skills");
    }

    @Test
    void apply_multipleDocuments_enrichesAll() {
        Map<String, Object> meta1 = new HashMap<>();
        meta1.put("source_book", "Baby Talk");
        Map<String, Object> meta2 = new HashMap<>();
        meta2.put("source_book", "Positive Discipline");

        Document doc1 = new Document("text1", meta1);
        Document doc2 = new Document("text2", meta2);

        List<Document> result = enricher.apply(List.of(doc1, doc2));

        assertThat(result).hasSize(2);
        assertThat(result.get(0).getMetadata().get("wing")).isEqualTo("language_development");
        assertThat(result.get(1).getMetadata().get("wing")).isEqualTo("parenting_skills");
        assertThat(result.get(1).getMetadata().get("room")).isEqualTo("discipline_guidance");
    }

    @Test
    void apply_emptyList_returnsEmptyList() {
        List<Document> result = enricher.apply(List.of());
        assertThat(result).isEmpty();
    }

    @Test
    void apply_null_returnsNull() {
        List<Document> result = enricher.apply(null);
        assertThat(result).isNull();
    }

    @Test
    void apply_preservesExistingMetadata() {
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("source_book", "Brain Rules for Baby");
        metadata.put("custom_key", "custom_value");
        Document doc = new Document("some text content", metadata);

        List<Document> result = enricher.apply(List.of(doc));

        Map<String, Object> enrichedMeta = result.get(0).getMetadata();
        // 原有 metadata 保留
        assertThat(enrichedMeta.get("custom_key")).isEqualTo("custom_value");
        assertThat(enrichedMeta.get("source_book")).isEqualTo("Brain Rules for Baby");
        // 新增宫殿坐标
        assertThat(enrichedMeta.get("wing")).isEqualTo("cognitive");
    }

    @Test
    void apply_allMetadataKeysAreSnakeCase() {
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("source_book", "Baby Talk");
        Document doc = new Document("text", metadata);

        List<Document> result = enricher.apply(List.of(doc));

        Map<String, Object> enrichedMeta = result.get(0).getMetadata();
        // 所有新增 key 都是 snake_case
        assertThat(enrichedMeta).containsKeys("wing", "room", "hall", "age_range");
        // 值也是 snake_case lowercase
        assertThat(enrichedMeta.get("wing").toString()).matches("[a-z_]+");
        assertThat(enrichedMeta.get("room").toString()).matches("[a-z_]+");
        assertThat(enrichedMeta.get("hall").toString()).matches("[a-z_]+");
    }
}
