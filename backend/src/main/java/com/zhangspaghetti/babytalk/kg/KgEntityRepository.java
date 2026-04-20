package com.zhangspaghetti.babytalk.kg;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

/**
 * kg_entities 表 CRUD — 使用 JdbcTemplate 直接操作。
 */
@Repository
public class KgEntityRepository {

    private final JdbcTemplate jdbc;

    public KgEntityRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final RowMapper<KgEntity> ROW_MAPPER = (rs, rowNum) -> mapRow(rs);

    private static KgEntity mapRow(ResultSet rs) throws SQLException {
        return new KgEntity(
                UUID.fromString(rs.getString("id")),
                rs.getString("name"),
                rs.getString("entity_type"),
                rs.getString("source_book"),
                rs.getString("wing"),
                rs.getString("room"),
                rs.getString("description"),
                rs.getObject("valid_from_months", Integer.class),
                rs.getObject("valid_to_months", Integer.class),
                rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant()
        );
    }

    /** 插入新实体 */
    public void insert(KgEntity entity) {
        jdbc.update("""
                INSERT INTO kg_entities (id, name, entity_type, source_book, wing, room,
                                         description, valid_from_months, valid_to_months,
                                         created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                entity.id(),
                entity.name(),
                entity.entityType(),
                entity.sourceBook(),
                entity.wing(),
                entity.room(),
                entity.description(),
                entity.validFromMonths(),
                entity.validToMonths(),
                Timestamp.from(entity.createdAt()),
                Timestamp.from(entity.updatedAt())
        );
    }

    /** 按 ID 查询 */
    public Optional<KgEntity> findById(UUID id) {
        List<KgEntity> results = jdbc.query(
                "SELECT * FROM kg_entities WHERE id = ?",
                ROW_MAPPER, id
        );
        return results.stream().findFirst();
    }

    /** 按名称模糊搜索（pg_trgm ILIKE） */
    public List<KgEntity> findByNameLike(String query) {
        return jdbc.query(
                "SELECT * FROM kg_entities WHERE name ILIKE ? ORDER BY similarity(name, ?) DESC, name",
                ROW_MAPPER,
                "%" + query + "%",
                query
        );
    }

    /** 按 wing 和 room 查询 */
    public List<KgEntity> findByWingAndRoom(String wing, String room) {
        return jdbc.query(
                "SELECT * FROM kg_entities WHERE wing = ? AND room = ? ORDER BY name",
                ROW_MAPPER, wing, room
        );
    }

    /** 更新实体 */
    public void update(KgEntity entity) {
        jdbc.update("""
                UPDATE kg_entities
                SET name = ?, entity_type = ?, source_book = ?, wing = ?, room = ?,
                    description = ?, valid_from_months = ?, valid_to_months = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                entity.name(),
                entity.entityType(),
                entity.sourceBook(),
                entity.wing(),
                entity.room(),
                entity.description(),
                entity.validFromMonths(),
                entity.validToMonths(),
                Timestamp.from(Instant.now()),
                entity.id()
        );
    }
}
