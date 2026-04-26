package com.zhangspaghetti.babytalk.kg;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 矛盾检测器单元测试 — 纯 Mockito，不依赖 Spring 容器。
 */
@ExtendWith(MockitoExtension.class)
class KgContradictionDetectorTest {

    @Mock
    private KgEntityRepository entityRepository;

    @Mock
    private KgContradictionRepository contradictionRepository;

    private KgContradictionDetector detector;

    @BeforeEach
    void setUp() {
        detector = new KgContradictionDetector(entityRepository, contradictionRepository);
    }

    @Test
    @DisplayName("contradicts 关系触发矛盾记录创建")
    void shouldCreateContradictionForContradictsRelation() {
        UUID sourceId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        KgEntity sourceEntity = new KgEntity(sourceId, "早睡建议", "recommendation",
                "育儿百科", "sleep", "basics", "宝宝应该8点前入睡", 6, 12,
                Instant.now(), Instant.now());
        KgEntity targetEntity = new KgEntity(targetId, "晚睡建议", "recommendation",
                "西尔斯亲密育儿", "sleep", "basics", "宝宝可以跟随父母作息", 6, 12,
                Instant.now(), Instant.now());

        when(entityRepository.findById(sourceId)).thenReturn(Optional.of(sourceEntity));
        when(entityRepository.findById(targetId)).thenReturn(Optional.of(targetEntity));

        KgRelationship rel = KgRelationship.create(sourceId, targetId,
                KgRelationship.REL_CONTRADICTS, "育儿百科", BigDecimal.valueOf(0.9), "关于入睡时间的矛盾");

        detector.onRelationshipInserted(rel);

        ArgumentCaptor<KgContradiction> captor = ArgumentCaptor.forClass(KgContradiction.class);
        verify(contradictionRepository).insert(captor.capture());

        KgContradiction created = captor.getValue();
        assertThat(created.status()).isEqualTo(KgContradiction.STATUS_DETECTED);
        assertThat(created.entityTopic()).isEqualTo("早睡建议 vs 晚睡建议");
        assertThat(created.sourceABook()).isEqualTo("育儿百科");
        assertThat(created.sourceBBook()).isEqualTo("西尔斯亲密育儿");
        assertThat(created.relationshipAId()).isEqualTo(sourceId);
        assertThat(created.relationshipBId()).isEqualTo(targetId);
    }

    @Test
    @DisplayName("非 contradicts 关系不触发矛盾检测")
    void shouldSkipNonContradictsRelation() {
        UUID sourceId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        KgRelationship rel = KgRelationship.create(sourceId, targetId,
                KgRelationship.REL_SUPPORTS, "育儿百科", BigDecimal.valueOf(0.8), "支持关系");

        detector.onRelationshipInserted(rel);

        verifyNoInteractions(entityRepository);
        verifyNoInteractions(contradictionRepository);
    }

    @Test
    @DisplayName("源实体不存在时跳过矛盾检测")
    void shouldSkipWhenSourceEntityNotFound() {
        UUID sourceId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        when(entityRepository.findById(sourceId)).thenReturn(Optional.empty());
        when(entityRepository.findById(targetId)).thenReturn(Optional.of(
                new KgEntity(targetId, "实体B", "concept", "书B", "wing", "room",
                        "描述", null, null, Instant.now(), Instant.now())));

        KgRelationship rel = KgRelationship.create(sourceId, targetId,
                KgRelationship.REL_CONTRADICTS, "育儿百科", BigDecimal.valueOf(0.9), "矛盾");

        detector.onRelationshipInserted(rel);

        verify(contradictionRepository, never()).insert(any());
    }

    @Test
    @DisplayName("目标实体不存在时跳过矛盾检测")
    void shouldSkipWhenTargetEntityNotFound() {
        UUID sourceId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        when(entityRepository.findById(sourceId)).thenReturn(Optional.of(
                new KgEntity(sourceId, "实体A", "concept", "书A", "wing", "room",
                        "描述", null, null, Instant.now(), Instant.now())));
        when(entityRepository.findById(targetId)).thenReturn(Optional.empty());

        KgRelationship rel = KgRelationship.create(sourceId, targetId,
                KgRelationship.REL_CONTRADICTS, "育儿百科", BigDecimal.valueOf(0.9), "矛盾");

        detector.onRelationshipInserted(rel);

        verify(contradictionRepository, never()).insert(any());
    }
}
