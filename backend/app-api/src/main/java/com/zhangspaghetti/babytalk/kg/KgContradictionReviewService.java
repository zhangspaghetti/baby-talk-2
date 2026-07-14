package com.zhangspaghetti.babytalk.kg;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Agent 矛盾审查服务 — 定时扫描 {@code detected} 状态的矛盾记录，
 * 使用 LLM 判定 resolved / escalated，并创建管理员通知。
 *
 * <p>安全默认：LLM 调用失败时保持 {@code detected} 状态不变，下次扫描重试。
 */
@Service
public class KgContradictionReviewService {

    private static final Logger log = LoggerFactory.getLogger(KgContradictionReviewService.class);

    private final ChatClient kgReviewChatClient;
    private final KgContradictionRepository contradictionRepository;
    private final KgAdminNotificationRepository adminNotificationRepository;
    private final KgEntityRepository entityRepository;
    private final KgRelationshipRepository relationshipRepository;
    private final KgProperties kgProperties;
    private final ObjectMapper objectMapper;

    public KgContradictionReviewService(ChatClient kgReviewChatClient,
                                         KgContradictionRepository contradictionRepository,
                                         KgAdminNotificationRepository adminNotificationRepository,
                                         KgEntityRepository entityRepository,
                                         KgRelationshipRepository relationshipRepository,
                                         KgProperties kgProperties,
                                         ObjectMapper objectMapper) {
        this.kgReviewChatClient = kgReviewChatClient;
        this.contradictionRepository = contradictionRepository;
        this.adminNotificationRepository = adminNotificationRepository;
        this.entityRepository = entityRepository;
        this.relationshipRepository = relationshipRepository;
        this.kgProperties = kgProperties;
        this.objectMapper = objectMapper;
    }

    /**
     * 定时审查待处理矛盾 — 由 Spring {@code @Scheduled} 调度。
     * 当 {@code app.kg.review-enabled=false} 时跳过。
     */
    @Scheduled(fixedDelayString = "${app.kg.review-interval}")
    public void reviewPendingContradictions() {
        if (!kgProperties.reviewEnabled()) {
            return;
        }

        List<KgContradiction> pending = contradictionRepository.findPendingReview(
                kgProperties.reviewBatchSize());

        log.info("KG 矛盾审查扫描开始: 待审查 {} 条", pending.size());

        int resolved = 0;
        int escalated = 0;
        int failed = 0;

        for (KgContradiction c : pending) {
            try {
                String verdict = reviewSingle(c);
                if ("resolved".equals(verdict)) {
                    resolved++;
                } else {
                    escalated++;
                }
            } catch (Exception e) {
                failed++;
                log.error("矛盾审查失败: contradictionId={}, 保持 detected 状态", c.id(), e);
                // 安全默认：保持 detected 状态不变
            }
        }

        log.info("KG 矛盾审查扫描结束: resolved={}, escalated={}, failed={}", resolved, escalated, failed);
    }

    /**
     * 审查单条矛盾 — 加载关系+实体上下文，调用 LLM 判定，更新状态。
     *
     * @param c 待审查的矛盾记录
     * @return verdict — "resolved" 或 "escalated"
     */
    String reviewSingle(KgContradiction c) {
        // 先标记为 reviewing
        contradictionRepository.updateStatus(c.id(), KgContradiction.STATUS_REVIEWING, null);

        // 加载关系和实体上下文
        Optional<KgRelationship> relAOpt = relationshipRepository.findById(c.relationshipAId());
        Optional<KgRelationship> relBOpt = relationshipRepository.findById(c.relationshipBId());
        Optional<KgEntity> entityAOpt = entityRepository.findById(
                relAOpt.map(KgRelationship::sourceEntityId).orElse(c.relationshipAId()));
        Optional<KgEntity> entityBOpt = entityRepository.findById(
                relBOpt.map(KgRelationship::targetEntityId).orElse(c.relationshipBId()));

        String prompt = buildReviewPrompt(c, relAOpt.orElse(null), relBOpt.orElse(null),
                entityAOpt.orElse(null), entityBOpt.orElse(null));

        // 调用 LLM
        String response = kgReviewChatClient.prompt()
                .user(prompt)
                .call()
                .content();

        // 解析 JSON verdict
        String verdict = parseVerdict(response, c);

        if ("resolved".equals(verdict)) {
            contradictionRepository.updateStatus(c.id(), KgContradiction.STATUS_RESOLVED, response);
            log.info("矛盾已解决: contradictionId={}", c.id());
        } else {
            // 默认 escalated
            contradictionRepository.updateStatus(c.id(), KgContradiction.STATUS_ESCALATED, response);

            // 创建管理员通知
            KgAdminNotification notification = KgAdminNotification.create(
                    c.id(),
                    "contradiction_escalated",
                    "矛盾需要管理员审查: %s — %s".formatted(c.entityTopic(), c.description()));
            adminNotificationRepository.insert(notification);

            log.info("矛盾已升级: contradictionId={}, notificationId={}", c.id(), notification.id());
        }

        return verdict;
    }

    /**
     * 构建 LLM 审查 prompt — 中文提示词，要求 JSON 输出。
     */
    String buildReviewPrompt(KgContradiction c,
                              KgRelationship relA, KgRelationship relB,
                              KgEntity entityA, KgEntity entityB) {
        StringBuilder sb = new StringBuilder();
        sb.append("你是一个育儿知识图谱矛盾审查助手。请分析以下矛盾并给出判定。\n\n");
        sb.append("## 矛盾信息\n");
        sb.append("- 主题: ").append(c.entityTopic()).append("\n");
        sb.append("- 描述: ").append(c.description()).append("\n");
        sb.append("- 来源A: ").append(c.sourceABook()).append("\n");
        sb.append("- 来源B: ").append(c.sourceBBook()).append("\n\n");

        if (entityA != null) {
            sb.append("## 实体A\n");
            sb.append("- 名称: ").append(entityA.name()).append("\n");
            sb.append("- 类型: ").append(entityA.entityType()).append("\n");
            sb.append("- 描述: ").append(entityA.description()).append("\n\n");
        }
        if (entityB != null) {
            sb.append("## 实体B\n");
            sb.append("- 名称: ").append(entityB.name()).append("\n");
            sb.append("- 类型: ").append(entityB.entityType()).append("\n");
            sb.append("- 描述: ").append(entityB.description()).append("\n\n");
        }
        if (relA != null) {
            sb.append("## 关系A\n");
            sb.append("- 类型: ").append(relA.relationType()).append("\n");
            sb.append("- 上下文: ").append(relA.contextNote()).append("\n\n");
        }
        if (relB != null) {
            sb.append("## 关系B\n");
            sb.append("- 类型: ").append(relB.relationType()).append("\n");
            sb.append("- 上下文: ").append(relB.contextNote()).append("\n\n");
        }

        sb.append("## 请以 JSON 格式回答\n");
        sb.append("```json\n");
        sb.append("{\n");
        sb.append("  \"verdict\": \"resolved\" 或 \"escalated\",\n");
        sb.append("  \"reason\": \"判定理由\"\n");
        sb.append("}\n");
        sb.append("```\n\n");
        sb.append("判定标准：\n");
        sb.append("- resolved: 两条信息可以共存（不同月龄适用、不同上下文、互补而非矛盾）\n");
        sb.append("- escalated: 两条信息确实矛盾，需要管理员人工审核\n");

        return sb.toString();
    }

    /**
     * 从 LLM 响应中解析 verdict。解析失败时默认 escalated（安全默认）。
     */
    String parseVerdict(String response, KgContradiction c) {
        if (response == null || response.isBlank()) {
            log.warn("LLM 返回空响应: contradictionId={}, 默认 escalated", c.id());
            return "escalated";
        }

        try {
            // 尝试从 markdown 代码块中提取 JSON
            String json = response;
            if (json.contains("```json")) {
                int start = json.indexOf("```json") + 7;
                int end = json.indexOf("```", start);
                if (end > start) {
                    json = json.substring(start, end).trim();
                }
            } else if (json.contains("```")) {
                int start = json.indexOf("```") + 3;
                int end = json.indexOf("```", start);
                if (end > start) {
                    json = json.substring(start, end).trim();
                }
            }

            JsonNode node = objectMapper.readTree(json);
            String verdict = node.has("verdict") ? node.get("verdict").asText() : null;

            if ("resolved".equals(verdict) || "escalated".equals(verdict)) {
                return verdict;
            }

            log.warn("LLM 返回未知 verdict: {}, contradictionId={}, 默认 escalated", verdict, c.id());
            return "escalated";

        } catch (Exception e) {
            log.warn("解析 LLM JSON 响应失败: contradictionId={}, 默认 escalated", c.id(), e);
            return "escalated";
        }
    }
}
