package com.zhangspaghetti.babytalk.kg;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Repository;

/**
 * kg_entities 表 CRUD — 使用 MyBatis mapper 操作。
 */
@Repository
public class KgEntityRepository {

    private final KgEntityMapper mapper;

    public KgEntityRepository(KgEntityMapper mapper) {
        this.mapper = mapper;
    }

    /** 插入新实体 */
    public void insert(KgEntity entity) {
        mapper.insert(entity);
    }

    /** 按 ID 查询 */
    public Optional<KgEntity> findById(UUID id) {
        return Optional.ofNullable(mapper.findById(id));
    }

    /** 按名称模糊搜索（pg_trgm ILIKE） */
    public List<KgEntity> findByNameLike(String query) {
        return mapper.findByNameLike(query, "%" + query + "%");
    }

    /** 按 wing 和 room 查询 */
    public List<KgEntity> findByWingAndRoom(String wing, String room) {
        return mapper.findByWingAndRoom(wing, room);
    }

    /** 更新实体 */
    public void update(KgEntity entity) {
        mapper.update(entity, Instant.now());
    }
}
