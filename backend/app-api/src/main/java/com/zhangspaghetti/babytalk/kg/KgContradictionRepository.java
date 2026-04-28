package com.zhangspaghetti.babytalk.kg;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Repository;

/**
 * kg_contradictions 表 CRUD — 使用 MyBatis mapper 操作。
 */
@Repository
public class KgContradictionRepository {

    private final KgContradictionMapper mapper;

    public KgContradictionRepository(KgContradictionMapper mapper) {
        this.mapper = mapper;
    }

    /** 插入新矛盾记录 */
    public void insert(KgContradiction contradiction) {
        mapper.insert(contradiction);
    }

    /** 按 ID 查询 */
    public Optional<KgContradiction> findById(UUID id) {
        return Optional.ofNullable(mapper.findById(id));
    }

    /** 查询所有矛盾记录 */
    public List<KgContradiction> findAll() {
        return mapper.findAll();
    }

    /** 按状态查询 */
    public List<KgContradiction> findByStatus(String status) {
        return mapper.findByStatus(status);
    }

    /** 更新状态和 agent 审查结果 */
    public void updateStatus(UUID id, String status, String agentReviewResult) {
        mapper.updateStatus(id, status, agentReviewResult, Instant.now());
    }

    /** 标记为已解决 */
    public void updateResolved(UUID id, String adminNotes) {
        mapper.updateResolved(id, KgContradiction.STATUS_RESOLVED, adminNotes, Instant.now());
    }

    /** 查找待审查的矛盾（detected 状态，按时间排序，限制批次大小） */
    public List<KgContradiction> findPendingReview(int batchSize) {
        return mapper.findPendingReview(KgContradiction.STATUS_DETECTED, batchSize);
    }
}
