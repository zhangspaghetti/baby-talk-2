package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.ai.document.Document;

/**
 * MemPalacePromptBuilder 单元测试。
 * 验证 L0/L1/L2 分层 prompt 构建逻辑在三种 searchMode 下的行为。
 */
class MemPalacePromptBuilderTest {

    private final PalaceSearchService mockSearchService = mock(PalaceSearchService.class);

    // ─── 辅助方法 ───────────────────────────────────────

    private Document createDoc(String text, String sourceBook, String ageRange) {
        return new Document(text, Map.of(
                "source_book", sourceBook,
                "age_range", ageRange,
                "wing", "language_development",
                "room", "early_communication"
        ));
    }

    // ─── L0: searchMode=none ───────────────────────────

    @Nested
    class SearchModeNone {

        @Test
        void returnsOnlyL0Prompt() {
            String result = MemPalacePromptBuilder.buildSystemPrompt("none", "宝宝不说话", mockSearchService);

            assertThat(result).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
            verify(mockSearchService, never()).search(any(), any(), any(), anyInt());
        }

        @Test
        void nullSearchModeDefaultsToNone() {
            String result = MemPalacePromptBuilder.buildSystemPrompt(null, "宝宝不说话", mockSearchService);
            assertThat(result).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
        }

        @Test
        void blankSearchModeDefaultsToNone() {
            String result = MemPalacePromptBuilder.buildSystemPrompt("  ", "宝宝不说话", mockSearchService);
            assertThat(result).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
        }

        @Test
        void unknownSearchModeDefaultsToNone() {
            String result = MemPalacePromptBuilder.buildSystemPrompt("unknown_mode", "宝宝不说话", mockSearchService);
            assertThat(result).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
        }
    }

    // ─── L0 + L1: searchMode=rag ───────────────────────

    @Nested
    class SearchModeRag {

        @Test
        void includesL0AndL1WhenDocumentsFound() {
            var docs = List.of(
                    createDoc("宝宝6个月开始咿呀学语", "《语言发展指南》", "0-12个月"),
                    createDoc("多和宝宝对话有助于语言发展", "《亲子沟通》", "0-24个月")
            );
            when(mockSearchService.search(any(), isNull(), isNull(), eq(15))).thenReturn(docs);

            String result = MemPalacePromptBuilder.buildSystemPrompt("rag", "宝宝不说话", mockSearchService);

            assertThat(result).startsWith(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
            assertThat(result).contains("参考知识（来自知识宫殿）");
            assertThat(result).contains("《语言发展指南》");
            assertThat(result).contains("《亲子沟通》");
            assertThat(result).contains("适用年龄：0-12个月");
            // rag 模式不包含工具指引
            assertThat(result).doesNotContain("工具使用指引");
        }

        @Test
        void l1EmptyResultsOmitsKnowledgeSection() {
            when(mockSearchService.search(any(), isNull(), isNull(), eq(15))).thenReturn(List.of());

            String result = MemPalacePromptBuilder.buildSystemPrompt("rag", "宝宝不说话", mockSearchService);

            assertThat(result).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
            assertThat(result).doesNotContain("参考知识");
        }

        @Test
        void l1FallsBackToL0OnSearchException() {
            when(mockSearchService.search(any(), isNull(), isNull(), eq(15)))
                    .thenThrow(new RuntimeException("DB connection failed"));

            String result = MemPalacePromptBuilder.buildSystemPrompt("rag", "宝宝不说话", mockSearchService);

            assertThat(result).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
        }

        @Test
        void l1SkippedWhenContextSummaryIsBlank() {
            String result = MemPalacePromptBuilder.buildSystemPrompt("rag", "", mockSearchService);

            assertThat(result).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
            verify(mockSearchService, never()).search(any(), any(), any(), anyInt());
        }

        @Test
        void l1SkippedWhenPalaceSearchIsNull() {
            String result = MemPalacePromptBuilder.buildSystemPrompt("rag", "宝宝不说话", null);

            assertThat(result).isEqualTo(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
        }

        @Test
        void customL1TopKIsRespected() {
            var docs = List.of(createDoc("内容", "《测试书》", "0-12个月"));
            when(mockSearchService.search(any(), isNull(), isNull(), eq(5))).thenReturn(docs);

            String result = MemPalacePromptBuilder.buildSystemPrompt("rag", "宝宝不说话", mockSearchService, 5);

            assertThat(result).contains("参考知识");
            verify(mockSearchService).search(any(), isNull(), isNull(), eq(5));
        }
    }

    // ─── L0 + L1 + L2: searchMode=agentic ──────────────

    @Nested
    class SearchModeAgentic {

        @Test
        void includesL0L1AndL2ToolGuidance() {
            var docs = List.of(createDoc("早期语言发展知识", "《婴幼儿语言》", "0-36个月"));
            when(mockSearchService.search(any(), isNull(), isNull(), eq(15))).thenReturn(docs);

            String result = MemPalacePromptBuilder.buildSystemPrompt("agentic", "宝宝说话晚", mockSearchService);

            assertThat(result).startsWith(MemPalacePromptBuilder.L0_SYSTEM_PROMPT);
            assertThat(result).contains("参考知识（来自知识宫殿）");
            assertThat(result).contains("《婴幼儿语言》");
            assertThat(result).contains("工具使用指引");
            assertThat(result).contains("palace_vector_search");
            assertThat(result).contains("palace_keyword_search");
        }

        @Test
        void l2ToolGuidancePresentsEvenWhenL1IsEmpty() {
            when(mockSearchService.search(any(), isNull(), isNull(), eq(15))).thenReturn(List.of());

            String result = MemPalacePromptBuilder.buildSystemPrompt("agentic", "宝宝说话晚", mockSearchService);

            // L1 为空但 L2 仍然存在
            assertThat(result).doesNotContain("参考知识");
            assertThat(result).contains("工具使用指引");
        }

        @Test
        void agenticModeCaseInsensitive() {
            when(mockSearchService.search(any(), isNull(), isNull(), eq(15))).thenReturn(List.of());

            String result = MemPalacePromptBuilder.buildSystemPrompt("AGENTIC", "测试", mockSearchService);
            assertThat(result).contains("工具使用指引");
        }
    }

    // ─── 辅助方法测试 ───────────────────────────────────

    @Nested
    class HelperMethods {

        @Test
        void extractQueryFromContextTruncatesLongInput() {
            String longContext = "宝".repeat(300);
            String result = MemPalacePromptBuilder.extractQueryFromContext(longContext);
            assertThat(result).hasSize(200);
        }

        @Test
        void extractQueryFromContextReturnsEmptyForNull() {
            assertThat(MemPalacePromptBuilder.extractQueryFromContext(null)).isEmpty();
        }

        @Test
        void extractQueryFromContextReturnsEmptyForBlank() {
            assertThat(MemPalacePromptBuilder.extractQueryFromContext("  ")).isEmpty();
        }

        @Test
        void formatDocForPromptIncludesSourceAndContent() {
            Document doc = createDoc("测试内容", "《测试书名》", "0-12个月");
            String formatted = MemPalacePromptBuilder.formatDocForPrompt(doc);

            assertThat(formatted).contains("《测试书名》");
            assertThat(formatted).contains("适用年龄：0-12个月");
            assertThat(formatted).contains("测试内容");
        }

        @Test
        void formatDocForPromptTruncatesLongContent() {
            String longContent = "字".repeat(400);
            Document doc = createDoc(longContent, "《长书》", "");
            String formatted = MemPalacePromptBuilder.formatDocForPrompt(doc);

            // 内容应被截取到 300 字符 + "…"
            assertThat(formatted).contains("…");
        }

        @Test
        void normalizeModeHandlesValidValues() {
            assertThat(MemPalacePromptBuilder.normalizeMode("agentic")).isEqualTo("agentic");
            assertThat(MemPalacePromptBuilder.normalizeMode("rag")).isEqualTo("rag");
            assertThat(MemPalacePromptBuilder.normalizeMode("none")).isEqualTo("none");
            assertThat(MemPalacePromptBuilder.normalizeMode("AGENTIC")).isEqualTo("agentic");
            assertThat(MemPalacePromptBuilder.normalizeMode(" RAG ")).isEqualTo("rag");
        }

        @Test
        void normalizeModeDefaultsToNoneForInvalid() {
            assertThat(MemPalacePromptBuilder.normalizeMode(null)).isEqualTo("none");
            assertThat(MemPalacePromptBuilder.normalizeMode("")).isEqualTo("none");
            assertThat(MemPalacePromptBuilder.normalizeMode("invalid")).isEqualTo("none");
        }
    }
}
