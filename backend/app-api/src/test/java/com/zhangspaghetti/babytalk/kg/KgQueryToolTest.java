package com.zhangspaghetti.babytalk.kg;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * KgQueryTool 单元测试 — 验证实体查询和 JSON 输出格式。
 */
@ExtendWith(MockitoExtension.class)
class KgQueryToolTest {

    @Mock
    private KgEntityRepository entityRepository;

    @Mock
    private KgRelationshipRepository relationshipRepository;

    private final ObjectMapper objectMapper = JsonMapper.builder().build();
    private KgQueryTool queryTool;

    @BeforeEach
    void setUp() {
        queryTool = new KgQueryTool(entityRepository, relationshipRepository, objectMapper);
    }

    @Test
    void queryEntity_returnsEmptyForNullInput() throws Exception {
        String json = queryTool.queryEntity(null);
        JsonNode node = objectMapper.readTree(json);

        assertThat(node.get("entity").asText()).isEmpty();
        assertThat(node.get("relationships")).isEmpty();
        assertThat(node.get("count").asInt()).isZero();
    }

    @Test
    void queryEntity_returnsEmptyForBlankInput() throws Exception {
        String json = queryTool.queryEntity("   ");
        JsonNode node = objectMapper.readTree(json);

        assertThat(node.get("entity").asText()).isEmpty();
        assertThat(node.get("count").asInt()).isZero();
    }

    @Test
    void queryEntity_returnsNotMatchedWhenNoEntitiesFound() throws Exception {
        when(entityRepository.findByNameLike("不存在的实体")).thenReturn(List.of());

        String json = queryTool.queryEntity("不存在的实体");
        JsonNode node = objectMapper.readTree(json);

        assertThat(node.get("matched").asBoolean()).isFalse();
        assertThat(node.get("entity").asText()).isEqualTo("不存在的实体");
        assertThat(node.get("relationships")).isEmpty();
        assertThat(node.get("count").asInt()).isZero();
    }

    @Test
    void queryEntity_returnsEntityWithRelationships() throws Exception {
        UUID entityId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();
        UUID relId = UUID.randomUUID();
        Instant now = Instant.now();

        KgEntity entity = new KgEntity(
                entityId, "母乳喂养", "recommendation", "Baby Talk",
                "nutrition", "breastfeeding", "母乳喂养是最佳选择",
                0, 24, now, now);

        KgEntity targetEntity = new KgEntity(
                targetId, "免疫力", "concept", "Baby Talk",
                "health", "immunity", "免疫系统发育",
                null, null, now, now);

        KgRelationship rel = new KgRelationship(
                relId, entityId, targetId,
                "supports", "Baby Talk",
                new BigDecimal("0.95"), "母乳有助于提高免疫力",
                now, now);

        when(entityRepository.findByNameLike("母乳喂养")).thenReturn(List.of(entity));
        when(relationshipRepository.findBySourceEntityId(entityId)).thenReturn(List.of(rel));
        when(relationshipRepository.findByTargetEntityId(entityId)).thenReturn(List.of());
        when(entityRepository.findById(targetId)).thenReturn(Optional.of(targetEntity));

        String json = queryTool.queryEntity("母乳喂养");
        JsonNode node = objectMapper.readTree(json);

        // 验证 entity 信息
        assertThat(node.get("matched").asBoolean()).isTrue();
        assertThat(node.get("entity").get("name").asText()).isEqualTo("母乳喂养");
        assertThat(node.get("entity").get("entityType").asText()).isEqualTo("recommendation");
        assertThat(node.get("entity").get("sourceBook").asText()).isEqualTo("Baby Talk");

        // 验证 relationships
        assertThat(node.get("count").asInt()).isEqualTo(1);
        JsonNode relNode = node.get("relationships").get(0);
        assertThat(relNode.get("direction").asText()).isEqualTo("outgoing");
        assertThat(relNode.get("relationType").asText()).isEqualTo("supports");
        assertThat(relNode.get("contextNote").asText()).isEqualTo("母乳有助于提高免疫力");

        // 验证对端实体简要信息
        assertThat(relNode.get("otherEntity").get("name").asText()).isEqualTo("免疫力");
        assertThat(relNode.get("otherEntity").get("entityType").asText()).isEqualTo("concept");
    }

    @Test
    void queryEntity_includesIncomingRelationships() throws Exception {
        UUID entityId = UUID.randomUUID();
        UUID sourceId = UUID.randomUUID();
        Instant now = Instant.now();

        KgEntity entity = new KgEntity(
                entityId, "语言发展", "milestone", "Language Book",
                "language", "early", "语言发展里程碑",
                6, 18, now, now);

        KgEntity sourceEntity = new KgEntity(
                sourceId, "亲子互动", "concept", "Parenting",
                "social", "interaction", "亲子互动方式",
                null, null, now, now);

        KgRelationship incomingRel = new KgRelationship(
                UUID.randomUUID(), sourceId, entityId,
                "causes", "Language Book",
                new BigDecimal("0.80"), "亲子互动促进语言发展",
                now, now);

        when(entityRepository.findByNameLike("语言发展")).thenReturn(List.of(entity));
        when(relationshipRepository.findBySourceEntityId(entityId)).thenReturn(List.of());
        when(relationshipRepository.findByTargetEntityId(entityId)).thenReturn(List.of(incomingRel));
        when(entityRepository.findById(sourceId)).thenReturn(Optional.of(sourceEntity));

        String json = queryTool.queryEntity("语言发展");
        JsonNode node = objectMapper.readTree(json);

        assertThat(node.get("count").asInt()).isEqualTo(1);
        JsonNode relNode = node.get("relationships").get(0);
        assertThat(relNode.get("direction").asText()).isEqualTo("incoming");
        assertThat(relNode.get("otherEntity").get("name").asText()).isEqualTo("亲子互动");
    }

    @Test
    void queryEntity_handlesMultipleCandidatesPicksBestMatch() throws Exception {
        UUID id1 = UUID.randomUUID();
        UUID id2 = UUID.randomUUID();
        Instant now = Instant.now();

        KgEntity best = new KgEntity(id1, "睡眠训练", "recommendation", "SleepBook",
                "sleep", "training", "睡眠训练方法", 4, 12, now, now);
        KgEntity second = new KgEntity(id2, "睡眠训练注意事项", "concept", "SleepBook",
                "sleep", "training", "注意事项", null, null, now, now);

        when(entityRepository.findByNameLike("睡眠训练")).thenReturn(List.of(best, second));
        when(relationshipRepository.findBySourceEntityId(id1)).thenReturn(List.of());
        when(relationshipRepository.findByTargetEntityId(id1)).thenReturn(List.of());

        String json = queryTool.queryEntity("睡眠训练");
        JsonNode node = objectMapper.readTree(json);

        assertThat(node.get("matched").asBoolean()).isTrue();
        assertThat(node.get("matchCandidates").asInt()).isEqualTo(2);
        assertThat(node.get("entity").get("name").asText()).isEqualTo("睡眠训练");
    }

    @Test
    void queryEntity_handlesUnknownOtherEntity() throws Exception {
        UUID entityId = UUID.randomUUID();
        UUID unknownTargetId = UUID.randomUUID();
        Instant now = Instant.now();

        KgEntity entity = new KgEntity(entityId, "测试实体", "concept", "Book",
                "test", "room", "描述", null, null, now, now);

        KgRelationship rel = new KgRelationship(
                UUID.randomUUID(), entityId, unknownTargetId,
                "related_to", "Book",
                new BigDecimal("0.50"), "关联",
                now, now);

        when(entityRepository.findByNameLike("测试实体")).thenReturn(List.of(entity));
        when(relationshipRepository.findBySourceEntityId(entityId)).thenReturn(List.of(rel));
        when(relationshipRepository.findByTargetEntityId(entityId)).thenReturn(List.of());
        when(entityRepository.findById(unknownTargetId)).thenReturn(Optional.empty());

        String json = queryTool.queryEntity("测试实体");
        JsonNode node = objectMapper.readTree(json);

        JsonNode otherEntity = node.get("relationships").get(0).get("otherEntity");
        assertThat(otherEntity.get("name").asText()).isEqualTo("unknown");
    }
}
