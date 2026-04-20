package com.zhangspaghetti.babytalk.kg;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

/**
 * kg_relationships 表 CRUD — 使用 JdbcTemplate 直接操作。
 */
@Repository
public class KgRelationshipRepository {

    private final JdbcTemplate jdbc;

    public KgRelationshipRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final RowMapper<KgRelationship> ROW_MAPPER = (rs, rowNum) -> mapRow(rs);

    private static KgRelationship mapRow(ResultSet rs) throws SQLException {
        return new KgRelationship(
                UUID.fromString(rs.getString("id")),
                UUID.fromString(rs.getString("source_entity_id")),
                UUID.fromString(rs.getString("target_entity_id")),
                rs.getString("relation_type"),
                rs.getString("source_book"),
                rs.getBigDecimal("confidence"),
                rs.getString("context_note"),
                rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant()
        );
    }

    /** 插入新关系 */
    public void insert(KgRelationship rel) {
        jdbc.update("""
                INSERT INTO kg_relationships (id, source_entity_id, target_entity_id, relation_type,
                                               source_book, confidence, context_note,
                                               created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                rel.id(),
                rel.sourceEntityId(),
                rel.targetEntityId(),
                rel.relationType(),
                rel.sourceBook(),
                rel.confidence(),
                rel.contextNote(),
                Timestamp.from(rel.createdAt()),
                Timestamp.from(rel.updatedAt())
        );
    }

    /** 按 ID 查询 */
    public Optional<KgRelationship> findById(UUID id) {
        List<KgRelationship> results = jdbc.query(
                "SELECT * FROM kg_relationships WHERE id = ?",
                ROW_MAPPER, id
        );
        return results.stream().findFirst();
    }

    /** 按源实体查询所有关系 */
    public List<KgRelationship> findBySourceEntityId(UUID sourceEntityId) {
        return jdbc.query(
                "SELECT * FROM kg_relationships WHERE source_entity_id = ? ORDER BY created_at",
                ROW_MAPPER, sourceEntityId
        );
    }

    /** 按目标实体查询所有关系 */
    public List<KgRelationship> findByTargetEntityId(UUID targetEntityId) {
        return jdbc.query(
                "SELECT * FROM kg_relationships WHERE target_entity_id = ? ORDER BY created_at",
                ROW_MAPPER, targetEntityId
        );
    }

    /** 按关系类型查询 */
    public List<KgRelationship> findByRelationType(String relationType) {
        return jdbc.query(
                "SELECT * FROM kg_relationships WHERE relation_type = ? ORDER BY created_at",
                ROW_MAPPER, relationType
        );
    }

    /**
     * 查找某个 target 实体上来自不同 source_book 的 supports 关系 —— 矛盾检测候选。
     * 返回同一 target 但 source_book 不同的 supports 类型关系对。
     */
    public List<KgRelationship> findContradictionCandidatesForEntity(UUID targetEntityId) {
        return jdbc.query("""
                SELECT * FROM kg_relationships
                WHERE target_entity_id = ?
                  AND relation_type = 'supports'
                ORDER BY source_book, created_at
                """,
                ROW_MAPPER, targetEntityId
        );
    }
}
