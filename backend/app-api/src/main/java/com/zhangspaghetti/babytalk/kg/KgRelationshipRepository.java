package com.zhangspaghetti.babytalk.kg;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Repository;

/**
 * kg_relationships 表 CRUD — 使用 MyBatis mapper 操作。
 */
@Repository
public class KgRelationshipRepository {

    private final KgRelationshipMapper mapper;

    public KgRelationshipRepository(KgRelationshipMapper mapper) {
        this.mapper = mapper;
    }

    /** 插入新关系 */
    public void insert(KgRelationship rel) {
        mapper.insert(rel);
    }

    /** 按 ID 查询 */
    public Optional<KgRelationship> findById(UUID id) {
        return Optional.ofNullable(mapper.findById(id));
    }

    /** 按源实体查询所有关系 */
    public List<KgRelationship> findBySourceEntityId(UUID sourceEntityId) {
        return mapper.findBySourceEntityId(sourceEntityId);
    }

    /** 按目标实体查询所有关系 */
    public List<KgRelationship> findByTargetEntityId(UUID targetEntityId) {
        return mapper.findByTargetEntityId(targetEntityId);
    }

    /** 按关系类型查询 */
    public List<KgRelationship> findByRelationType(String relationType) {
        return mapper.findByRelationType(relationType);
    }

    /**
     * 查找某个 target 实体上来自不同 source_book 的 supports 关系 —— 矛盾检测候选。
     * 返回同一 target 但 source_book 不同的 supports 类型关系对。
     */
    public List<KgRelationship> findContradictionCandidatesForEntity(UUID targetEntityId) {
        return mapper.findContradictionCandidatesForEntity(targetEntityId);
    }
}
