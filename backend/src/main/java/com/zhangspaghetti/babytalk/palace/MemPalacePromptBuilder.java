package com.zhangspaghetti.babytalk.palace;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;

/**
 * 四层 MemPalace Prompt 构建器。
 *
 * <p>分层结构：
 * <ul>
 *   <li>L0: 小禾老师核心人格 + 知识来源引用指令</li>
 *   <li>L1: 基于 contextSummary 预检索的 top-N 知识条目（rag / agentic 模式）</li>
 *   <li>L2: Tool calling 工具使用指引（仅 agentic 模式）</li>
 *   <li>L3: Tool calling 运行时执行（由 Spring AI 框架处理，不体现在 prompt 中）</li>
 * </ul>
 */
public class MemPalacePromptBuilder {

    private static final Logger log = LoggerFactory.getLogger(MemPalacePromptBuilder.class);

    // L0 核心人格 prompt
    public static final String L0_SYSTEM_PROMPT = """
            你是小禾老师，一位温暖、专业的早期语言发展导师。
            规则：
            - 回复不超过 200 字，使用简洁中文，可适当加入英文示范短句
            - 不给医疗诊断建议
            - 不讨论任何可能伤害儿童的行为
            - 输出纯文本，不含 markdown 格式符号
            - 每次只给一个具体可操作的建议
            - 如果使用了知识宫殿中的知识，请在回复末尾用括号标注来源书名，例如：（来源：《书名》）""";

    // L2 工具使用指引（agentic 模式专用）
    static final String L2_TOOL_GUIDANCE = """

            【工具使用指引】
            你可以使用以下工具搜索知识宫殿获取专业育儿知识：
            - palace_vector_search: 按语义相似度搜索，适合开放性问题
            - palace_keyword_search: 按关键词精确搜索，适合查找特定术语
            - palace_read_chunk: 读取检索结果的完整内容
            - palace_list_rooms: 查看知识宫殿结构，了解知识分布
            请根据用户问题自主决定是否需要搜索以及使用哪个工具。搜索后请引用来源书名。""";

    private static final int DEFAULT_L1_TOP_K = 15;

    private MemPalacePromptBuilder() {
        // 工具类，禁止实例化
    }

    /**
     * 根据 searchMode 构建系统 prompt。
     *
     * @param searchMode     搜索模式: "agentic", "rag", "none"
     * @param contextSummary 上下文摘要（可能包含年龄信息，用于 L1 预检索）
     * @param palaceSearch   知识宫殿搜索服务（L1 预检索用，searchMode=none 时可为 null）
     * @param l1TopK         L1 预检索返回条目数上限
     * @return 完整的系统 prompt 字符串
     */
    public static String buildSystemPrompt(String searchMode, String contextSummary,
                                            PalaceSearchService palaceSearch, int l1TopK) {
        String mode = normalizeMode(searchMode);
        log.info("search-mode={}, L1 topK={}", mode, l1TopK);

        if ("none".equals(mode)) {
            log.info("prompt.length={}", L0_SYSTEM_PROMPT.length());
            return L0_SYSTEM_PROMPT;
        }

        StringBuilder sb = new StringBuilder(L0_SYSTEM_PROMPT);

        // L1: 预检索知识注入
        String l1Section = buildL1Section(contextSummary, palaceSearch, l1TopK);
        if (!l1Section.isEmpty()) {
            sb.append(l1Section);
        }

        // L2: agentic 模式下添加工具使用指引
        if ("agentic".equals(mode)) {
            sb.append(L2_TOOL_GUIDANCE);
        }

        String result = sb.toString();
        log.info("prompt.length={}", result.length());
        return result;
    }

    /**
     * 便捷方法：使用默认 L1 topK。
     */
    public static String buildSystemPrompt(String searchMode, String contextSummary,
                                            PalaceSearchService palaceSearch) {
        return buildSystemPrompt(searchMode, contextSummary, palaceSearch, DEFAULT_L1_TOP_K);
    }

    /**
     * 构建 L1 预注入段落 — 从知识宫殿预检索相关知识片段。
     */
    static String buildL1Section(String contextSummary, PalaceSearchService palaceSearch, int l1TopK) {
        if (palaceSearch == null) {
            log.warn("L1 pre-fetch skipped: palaceSearch is null");
            return "";
        }

        String query = extractQueryFromContext(contextSummary);
        if (query.isEmpty()) {
            log.info("L1 pre-fetch: 无有效查询文本，跳过预检索");
            return "";
        }

        try {
            List<Document> docs = palaceSearch.search(query, null, null, l1TopK);
            log.info("L1 pre-fetch count={}", docs.size());

            if (docs.isEmpty()) {
                return "";
            }

            String knowledgeBlock = docs.stream()
                    .map(MemPalacePromptBuilder::formatDocForPrompt)
                    .collect(Collectors.joining("\n"));

            return "\n\n【参考知识（来自知识宫殿）】\n" + knowledgeBlock;

        } catch (Exception e) {
            log.warn("L1 pre-fetch failed, falling back to L0 only: {}", e.getMessage());
            return "";
        }
    }

    /**
     * 从 contextSummary 中提取用于预检索的查询文本。
     * 如果 contextSummary 为空，返回空字符串。
     */
    static String extractQueryFromContext(String contextSummary) {
        if (contextSummary == null || contextSummary.isBlank()) {
            return "";
        }
        // 使用 contextSummary 本身作为查询（它通常是用户消息的摘要或用户输入）
        String trimmed = contextSummary.trim();
        // 截取前 200 字符避免过长查询
        return trimmed.length() > 200 ? trimmed.substring(0, 200) : trimmed;
    }

    /**
     * 将 Document 格式化为 prompt 中的引用条目。
     */
    static String formatDocForPrompt(Document doc) {
        Map<String, Object> meta = doc.getMetadata();
        String sourceBook = String.valueOf(meta.getOrDefault("source_book", "未知来源"));
        String ageRange = String.valueOf(meta.getOrDefault("age_range", ""));
        String content = doc.getText();

        // 截取内容前 300 字符避免 prompt 过长
        if (content != null && content.length() > 300) {
            content = content.substring(0, 300) + "…";
        }

        StringBuilder sb = new StringBuilder();
        sb.append("- 【").append(sourceBook).append("】");
        if (!ageRange.isEmpty()) {
            sb.append("（适用年龄：").append(ageRange).append("）");
        }
        sb.append("：").append(content);
        return sb.toString();
    }

    /**
     * 规范化 searchMode 值。
     */
    static String normalizeMode(String searchMode) {
        if (searchMode == null || searchMode.isBlank()) {
            return "none";
        }
        String normalized = searchMode.trim().toLowerCase();
        return switch (normalized) {
            case "agentic", "rag", "none" -> normalized;
            default -> {
                log.warn("未知的 search-mode '{}'，降级为 'none'", searchMode);
                yield "none";
            }
        };
    }
}
