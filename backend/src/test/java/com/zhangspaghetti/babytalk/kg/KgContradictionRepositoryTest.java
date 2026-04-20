package com.zhangspaghetti.babytalk.kg;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * KgContradictionRepository 集成测试 — 验证 insert + findById、findByStatus 过滤、updateStatus。
 */
class KgContradictionRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    private KgEntityRepository entityRepo;

    @Autowired
    private KgRelationshipRepository relRepo;

    @Autowired
    private KgContradictionRepository contradictionRepo;

    private KgContradiction contradiction;

    @BeforeEach
    void setUp() {
        // 创建两个实体和两个关系用于矛盾测试
        KgEntity entity1 = KgEntity.create("睡眠训练", KgEntity.TYPE_RECOMMENDATION,
                "Book A", "sleep", "infant", "Book A 建议", 6, 12);
        KgEntity entity2 = KgEntity.create("睡眠训练目标", KgEntity.TYPE_CONCEPT,
                "Book B", "sleep", "infant", "目标实体", null, null);
        entityRepo.insert(entity1);
        entityRepo.insert(entity2);

        KgRelationship relA = KgRelationship.create(entity1.id(), entity2.id(),
                KgRelationship.REL_SUPPORTS, "Book A", new BigDecimal("0.90"),
                "Book A 建议尽早睡眠训练");
        KgRelationship relB = KgRelationship.create(entity1.id(), entity2.id(),
                KgRelationship.REL_SUPPORTS, "Book B", new BigDecimal("0.85"),
                "Book B 建议延迟睡眠训练");
        relRepo.insert(relA);
        relRepo.insert(relB);

        contradiction = KgContradiction.detected("睡眠训练时机",
                relA.id(), relB.id(), "Book A", "Book B",
                "Book A 建议6个月，Book B 建议12个月");
        contradictionRepo.insert(contradiction);
    }

    @Test
    void insertAndFindById_roundTrip() {
        Optional<KgContradiction> found = contradictionRepo.findById(contradiction.id());

        assertThat(found).isPresent();
        KgContradiction c = found.get();
        assertThat(c.entityTopic()).isEqualTo("睡眠训练时机");
        assertThat(c.status()).isEqualTo(KgContradiction.STATUS_DETECTED);
        assertThat(c.sourceABook()).isEqualTo("Book A");
        assertThat(c.sourceBBook()).isEqualTo("Book B");
        assertThat(c.reviewedAt()).isNull();
        assertThat(c.resolvedAt()).isNull();
    }

    @Test
    void findByStatus_filtersCorrectly() {
        List<KgContradiction> detected = contradictionRepo.findByStatus(KgContradiction.STATUS_DETECTED);
        List<KgContradiction> escalated = contradictionRepo.findByStatus(KgContradiction.STATUS_ESCALATED);

        assertThat(detected).anyMatch(c -> c.id().equals(contradiction.id()));
        assertThat(escalated).noneMatch(c -> c.id().equals(contradiction.id()));
    }

    @Test
    void updateStatus_changesStatusAndSetsReviewedAt() {
        contradictionRepo.updateStatus(contradiction.id(),
                KgContradiction.STATUS_ESCALATED, "Agent 认为存在真实矛盾");

        Optional<KgContradiction> found = contradictionRepo.findById(contradiction.id());
        assertThat(found).isPresent();
        assertThat(found.get().status()).isEqualTo(KgContradiction.STATUS_ESCALATED);
        assertThat(found.get().agentReviewResult()).isEqualTo("Agent 认为存在真实矛盾");
        assertThat(found.get().reviewedAt()).isNotNull();
    }

    @Test
    void findPendingReview_returnsBatchSize() {
        List<KgContradiction> batch = contradictionRepo.findPendingReview(10);

        assertThat(batch).isNotEmpty();
        assertThat(batch).allMatch(c -> c.status().equals(KgContradiction.STATUS_DETECTED));
    }

    @Test
    void updateResolved_setsAdminNotesAndResolvedAt() {
        contradictionRepo.updateResolved(contradiction.id(), "管理员已确认，保留 Book A 建议");

        Optional<KgContradiction> found = contradictionRepo.findById(contradiction.id());
        assertThat(found).isPresent();
        assertThat(found.get().status()).isEqualTo(KgContradiction.STATUS_RESOLVED);
        assertThat(found.get().adminNotes()).contains("Book A");
        assertThat(found.get().resolvedAt()).isNotNull();
    }
}
