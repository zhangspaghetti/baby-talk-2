package com.zhangspaghetti.babytalk.kg;

import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * 矛盾检测器 — 当 {@code contradicts} 类型关系写入时自动创建 {@link KgContradiction} 记录。
 *
 * <p>该服务在关系插入后由调用方主动调用 {@link #onRelationshipInserted(KgRelationship)}，
 * 只对 {@code contradicts} 类型的关系生效。
 */
@Service
public class KgContradictionDetector {

    private static final Logger log = LoggerFactory.getLogger(KgContradictionDetector.class);

    private final KgEntityRepository entityRepository;
    private final KgContradictionRepository contradictionRepository;

    public KgContradictionDetector(KgEntityRepository entityRepository,
                                    KgContradictionRepository contradictionRepository) {
        this.entityRepository = entityRepository;
        this.contradictionRepository = contradictionRepository;
    }

    /**
     * 关系写入后的回调 — 当关系类型为 {@code contradicts} 时创建矛盾记录。
     *
     * @param rel 新插入的关系
     */
    public void onRelationshipInserted(KgRelationship rel) {
        if (!KgRelationship.REL_CONTRADICTS.equals(rel.relationType())) {
            return;
        }

        log.info("检测到 contradicts 关系: {} → {}，准备创建矛盾记录",
                rel.sourceEntityId(), rel.targetEntityId());

        Optional<KgEntity> sourceOpt = entityRepository.findById(rel.sourceEntityId());
        Optional<KgEntity> targetOpt = entityRepository.findById(rel.targetEntityId());

        if (sourceOpt.isEmpty() || targetOpt.isEmpty()) {
            log.warn("contradicts 关系的源/目标实体不存在: source={}, target={}，跳过矛盾检测",
                    rel.sourceEntityId(), rel.targetEntityId());
            return;
        }

        KgEntity source = sourceOpt.get();
        KgEntity target = targetOpt.get();

        // 实体主题取两个实体名称的组合
        String entityTopic = source.name() + " vs " + target.name();

        // 描述包含来源书籍信息
        String description = "来自《%s》的「%s」与来自《%s》的「%s」存在矛盾".formatted(
                source.sourceBook(), source.name(),
                target.sourceBook(), target.name());

        String sourceABook = source.sourceBook() != null ? source.sourceBook() : "未知";
        String sourceBBook = target.sourceBook() != null ? target.sourceBook() : "未知";

        KgContradiction contradiction = KgContradiction.detected(
                entityTopic,
                rel.sourceEntityId(), rel.targetEntityId(),
                sourceABook, sourceBBook,
                description);

        contradictionRepository.insert(contradiction);

        log.info("已创建矛盾记录: id={}, topic={}, status={}",
                contradiction.id(), entityTopic, contradiction.status());
    }
}
