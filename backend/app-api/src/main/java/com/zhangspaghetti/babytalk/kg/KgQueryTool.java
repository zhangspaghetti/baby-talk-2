package com.zhangspaghetti.babytalk.kg;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * KG 实体关系查询服务 — 基于 pg_trgm 模糊搜索实体，
 * 获取所有关联关系并拼装为 JSON 输出。
 *
 * <p>供 {@link com.zhangspaghetti.babytalk.palace.PalaceToolProvider#kgQueryEntity}
 * 作为真实 KG 查询的委托实现。
 */
@Service
public class KgQueryTool {

    private static final Logger log = LoggerFactory.getLogger(KgQueryTool.class);

    private final KgEntityRepository entityRepository;
    private final KgRelationshipRepository relationshipRepository;
    private final ObjectMapper objectMapper;

    public KgQueryTool(KgEntityRepository entityRepository,
                        KgRelationshipRepository relationshipRepository,
                        ObjectMapper objectMapper) {
        this.entityRepository = entityRepository;
        this.relationshipRepository = relationshipRepository;
        this.objectMapper = objectMapper;
    }

    /**
     * 按实体名称模糊搜索 KG，返回实体详情 + 关联关系 + 对端实体简要信息。
     *
     * @param entityName 要查询的实体名称（支持模糊匹配）
     * @return JSON 字符串
     */
    public String queryEntity(String entityName) {
        if (entityName == null || entityName.isBlank()) {
            log.info("kg_query_entity: entityName 为空，返回空结果");
            return toJson(Map.of(
                    "entity", "",
                    "relationships", List.of(),
                    "count", 0
            ));
        }

        String trimmed = entityName.trim();
        log.info("kg_query_entity: 搜索实体 '{}'", trimmed);

        // pg_trgm 模糊搜索
        List<KgEntity> entities = entityRepository.findByNameLike(trimmed);
        if (entities.isEmpty()) {
            log.info("kg_query_entity: 未找到匹配实体 '{}'", trimmed);
            return toJson(Map.of(
                    "entity", trimmed,
                    "matched", false,
                    "relationships", List.of(),
                    "count", 0
            ));
        }

        // 取最佳匹配（第一个，pg_trgm 已按 similarity 排序）
        KgEntity bestMatch = entities.get(0);
        log.info("kg_query_entity: 最佳匹配 entity='{}', id={}", bestMatch.name(), bestMatch.id());

        // 获取该实体的所有关系（作为 source 和 target）
        List<KgRelationship> asSource = relationshipRepository.findBySourceEntityId(bestMatch.id());
        List<KgRelationship> asTarget = relationshipRepository.findByTargetEntityId(bestMatch.id());

        // 拼装关系列表 + 对端实体简要信息
        List<Map<String, Object>> relList = new ArrayList<>();

        for (KgRelationship rel : asSource) {
            Map<String, Object> relMap = buildRelationshipMap(rel, "outgoing", rel.targetEntityId());
            relList.add(relMap);
        }
        for (KgRelationship rel : asTarget) {
            Map<String, Object> relMap = buildRelationshipMap(rel, "incoming", rel.sourceEntityId());
            relList.add(relMap);
        }

        // 构建结果
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("entity", entityToMap(bestMatch));
        result.put("matched", true);
        result.put("matchCandidates", entities.size());
        result.put("relationships", relList);
        result.put("count", relList.size());

        log.info("kg_query_entity: 返回 {} 条关系", relList.size());
        return toJson(result);
    }

    // ─── 辅助方法 ─────────────────────────────────────────────

    private Map<String, Object> buildRelationshipMap(KgRelationship rel,
                                                      String direction,
                                                      UUID otherEntityId) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("relationshipId", rel.id().toString());
        map.put("direction", direction);
        map.put("relationType", rel.relationType());
        map.put("sourceBook", rel.sourceBook());
        map.put("confidence", rel.confidence());
        map.put("contextNote", rel.contextNote());

        // 加载对端实体简要信息
        Optional<KgEntity> otherOpt = entityRepository.findById(otherEntityId);
        if (otherOpt.isPresent()) {
            KgEntity other = otherOpt.get();
            map.put("otherEntity", Map.of(
                    "id", other.id().toString(),
                    "name", other.name(),
                    "entityType", other.entityType(),
                    "wing", other.wing() != null ? other.wing() : "",
                    "room", other.room() != null ? other.room() : ""
            ));
        } else {
            map.put("otherEntity", Map.of("id", otherEntityId.toString(), "name", "unknown"));
        }

        return map;
    }

    private static Map<String, Object> entityToMap(KgEntity e) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", e.id().toString());
        map.put("name", e.name());
        map.put("entityType", e.entityType());
        map.put("sourceBook", e.sourceBook());
        map.put("wing", e.wing());
        map.put("room", e.room());
        map.put("description", e.description());
        map.put("validFromMonths", e.validFromMonths());
        map.put("validToMonths", e.validToMonths());
        return map;
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            log.error("JSON 序列化失败", e);
            return "{\"error\":\"JSON 序列化失败\"}";
        }
    }
}
