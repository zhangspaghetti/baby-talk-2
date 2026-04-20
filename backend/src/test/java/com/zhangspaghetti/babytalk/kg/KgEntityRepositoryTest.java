package com.zhangspaghetti.babytalk.kg;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * KgEntityRepository 集成测试 — 验证 insert + findById 往返、findByNameLike 模糊搜索、findByWingAndRoom 查询。
 */
class KgEntityRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    private KgEntityRepository repo;

    private KgEntity sleepEntity;
    private KgEntity feedEntity;

    @BeforeEach
    void setUp() {
        sleepEntity = KgEntity.create("婴儿睡眠训练", KgEntity.TYPE_RECOMMENDATION,
                "Baby Sleep Guide", "sleep", "newborn",
                "建议在6个月后开始睡眠训练", 6, 12);
        feedEntity = KgEntity.create("母乳喂养指南", KgEntity.TYPE_CONCEPT,
                "Breastfeeding Handbook", "feeding", "newborn",
                "母乳喂养基础知识", 0, 24);
        repo.insert(sleepEntity);
        repo.insert(feedEntity);
    }

    @Test
    void insertAndFindById_roundTrip() {
        Optional<KgEntity> found = repo.findById(sleepEntity.id());

        assertThat(found).isPresent();
        KgEntity entity = found.get();
        assertThat(entity.name()).isEqualTo("婴儿睡眠训练");
        assertThat(entity.entityType()).isEqualTo(KgEntity.TYPE_RECOMMENDATION);
        assertThat(entity.sourceBook()).isEqualTo("Baby Sleep Guide");
        assertThat(entity.wing()).isEqualTo("sleep");
        assertThat(entity.room()).isEqualTo("newborn");
        assertThat(entity.validFromMonths()).isEqualTo(6);
        assertThat(entity.validToMonths()).isEqualTo(12);
    }

    @Test
    void findByNameLike_trigramSearch() {
        List<KgEntity> results = repo.findByNameLike("睡眠");

        assertThat(results).isNotEmpty();
        assertThat(results).anyMatch(e -> e.name().contains("睡眠"));
    }

    @Test
    void findByWingAndRoom() {
        List<KgEntity> results = repo.findByWingAndRoom("sleep", "newborn");

        assertThat(results).isNotEmpty();
        assertThat(results).allMatch(e -> e.wing().equals("sleep") && e.room().equals("newborn"));
    }

    @Test
    void update_changesDescription() {
        KgEntity updated = new KgEntity(sleepEntity.id(), sleepEntity.name(),
                sleepEntity.entityType(), sleepEntity.sourceBook(),
                sleepEntity.wing(), sleepEntity.room(),
                "更新后的描述：建议在4个月后开始",
                4, 12,
                sleepEntity.createdAt(), sleepEntity.updatedAt());
        repo.update(updated);

        Optional<KgEntity> found = repo.findById(sleepEntity.id());
        assertThat(found).isPresent();
        assertThat(found.get().description()).contains("4个月");
        assertThat(found.get().validFromMonths()).isEqualTo(4);
    }
}
