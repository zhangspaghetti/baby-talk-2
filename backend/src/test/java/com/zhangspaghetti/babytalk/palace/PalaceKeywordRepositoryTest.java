package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordRepository.ChunkResult;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

/**
 * PalaceKeywordRepository 单元测试 — 使用 Mockito 验证 SQL 构建和参数传递。
 *
 * <p>覆盖场景：
 * <ul>
 *   <li>纯关键词检索</li>
 *   <li>关键词 + wing 过滤</li>
 *   <li>关键词 + wing + room 过滤</li>
 *   <li>null/空 keywords 防御</li>
 *   <li>limit 边界值防御（0、负数）</li>
 *   <li>readChunkById null UUID 处理</li>
 *   <li>readChunkById 不存在 UUID 返回 empty</li>
 * </ul>
 */
@ExtendWith(MockitoExtension.class)
class PalaceKeywordRepositoryTest {

    @Mock
    private JdbcTemplate jdbc;

    private PalaceKeywordRepository repository;

    @BeforeEach
    void setUp() {
        repository = new PalaceKeywordRepository(jdbc, new ObjectMapper());
    }

    // ========== searchByKeywords 正向测试 ==========

    @Test
    void searchByKeywords_keywordsOnly_passesCorrectSqlAndParams() {
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(Collections.emptyList());

        repository.searchByKeywords("宝宝说话", null, null, 5);

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> paramsCaptor = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sqlCaptor.capture(), any(RowMapper.class), paramsCaptor.capture());

        String sql = sqlCaptor.getValue();
        Object[] params = paramsCaptor.getValue();

        // SQL 应包含 plainto_tsquery 和 ts_rank，不包含 wing/room 过滤
        assertThat(sql).contains("plainto_tsquery('simple', ?)");
        assertThat(sql).contains("ts_rank");
        assertThat(sql).contains("ORDER BY rank DESC");
        assertThat(sql).contains("LIMIT ?");
        assertThat(sql).doesNotContain("metadata->>'wing'");
        assertThat(sql).doesNotContain("metadata->>'room'");

        // 参数：keywords（2次） + limit
        assertThat(params).hasSize(3);
        assertThat(params[0]).isEqualTo("宝宝说话");
        assertThat(params[1]).isEqualTo("宝宝说话");
        assertThat(params[2]).isEqualTo(5);
    }

    @Test
    void searchByKeywords_withWing_addsWingFilter() {
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(Collections.emptyList());

        repository.searchByKeywords("语言发展", "LANGUAGE_DEVELOPMENT", null, 10);

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> paramsCaptor = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sqlCaptor.capture(), any(RowMapper.class), paramsCaptor.capture());

        String sql = sqlCaptor.getValue();
        Object[] params = paramsCaptor.getValue();

        assertThat(sql).contains("metadata->>'wing' = ?");
        assertThat(sql).doesNotContain("metadata->>'room'");

        // 参数：keywords（2次） + wing + limit
        assertThat(params).hasSize(4);
        assertThat(params[0]).isEqualTo("语言发展");
        assertThat(params[1]).isEqualTo("语言发展");
        assertThat(params[2]).isEqualTo("language_development"); // 小写化
        assertThat(params[3]).isEqualTo(10);
    }

    @Test
    void searchByKeywords_withWingAndRoom_addsBothFilters() {
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(Collections.emptyList());

        repository.searchByKeywords("早期沟通", "LANGUAGE_DEVELOPMENT", "EARLY_COMMUNICATION", 3);

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Object[]> paramsCaptor = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(sqlCaptor.capture(), any(RowMapper.class), paramsCaptor.capture());

        String sql = sqlCaptor.getValue();
        Object[] params = paramsCaptor.getValue();

        assertThat(sql).contains("metadata->>'wing' = ?");
        assertThat(sql).contains("metadata->>'room' = ?");

        // 参数：keywords（2次） + wing + room + limit
        assertThat(params).hasSize(5);
        assertThat(params[0]).isEqualTo("早期沟通");
        assertThat(params[1]).isEqualTo("早期沟通");
        assertThat(params[2]).isEqualTo("language_development");
        assertThat(params[3]).isEqualTo("early_communication");
        assertThat(params[4]).isEqualTo(3);
    }

    // ========== searchByKeywords 负向测试 ==========

    @Test
    void searchByKeywords_nullKeywords_returnsEmptyWithoutQuery() {
        List<ChunkResult> results = repository.searchByKeywords(null, null, null, 5);

        assertThat(results).isEmpty();
        verify(jdbc, never()).query(anyString(), any(RowMapper.class), any(Object[].class));
    }

    @Test
    void searchByKeywords_emptyKeywords_returnsEmptyWithoutQuery() {
        List<ChunkResult> results = repository.searchByKeywords("  ", null, null, 5);

        assertThat(results).isEmpty();
        verify(jdbc, never()).query(anyString(), any(RowMapper.class), any(Object[].class));
    }

    @Test
    void searchByKeywords_zeroLimit_defaultsToFive() {
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(Collections.emptyList());

        repository.searchByKeywords("宝宝", null, null, 0);

        ArgumentCaptor<Object[]> paramsCaptor = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(anyString(), any(RowMapper.class), paramsCaptor.capture());

        Object[] params = paramsCaptor.getValue();
        // 最后一个参数是 limit，应被防御为默认值 5
        assertThat(params[params.length - 1]).isEqualTo(5);
    }

    @Test
    void searchByKeywords_negativeLimit_defaultsToFive() {
        when(jdbc.query(anyString(), any(RowMapper.class), any(Object[].class)))
                .thenReturn(Collections.emptyList());

        repository.searchByKeywords("宝宝", null, null, -3);

        ArgumentCaptor<Object[]> paramsCaptor = ArgumentCaptor.forClass(Object[].class);
        verify(jdbc).query(anyString(), any(RowMapper.class), paramsCaptor.capture());

        Object[] params = paramsCaptor.getValue();
        assertThat(params[params.length - 1]).isEqualTo(5);
    }

    // ========== readChunkById 测试 ==========

    @Test
    void readChunkById_nullId_returnsEmpty() {
        Optional<ChunkResult> result = repository.readChunkById(null);

        assertThat(result).isEmpty();
        verify(jdbc, never()).query(anyString(), any(RowMapper.class), any(UUID.class));
    }

    @Test
    void readChunkById_notFound_returnsEmpty() {
        UUID testId = UUID.randomUUID();
        when(jdbc.query(anyString(), any(RowMapper.class), eq(testId)))
                .thenReturn(Collections.emptyList());

        Optional<ChunkResult> result = repository.readChunkById(testId);

        assertThat(result).isEmpty();
        verify(jdbc).query(anyString(), any(RowMapper.class), eq(testId));
    }

    @Test
    void readChunkById_passesCorrectSql() {
        UUID testId = UUID.randomUUID();
        when(jdbc.query(anyString(), any(RowMapper.class), eq(testId)))
                .thenReturn(Collections.emptyList());

        repository.readChunkById(testId);

        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        verify(jdbc).query(sqlCaptor.capture(), any(RowMapper.class), eq(testId));

        assertThat(sqlCaptor.getValue()).contains("SELECT id, content, metadata FROM vector_store WHERE id = ?");
    }

    // ========== ChunkResult record 测试 ==========

    @Test
    void chunkResult_holdsDataCorrectly() {
        UUID id = UUID.randomUUID();
        Map<String, Object> metadata = Map.of("wing", "language_development", "room", "early_communication");
        ChunkResult result = new ChunkResult(id, "测试内容", metadata);

        assertThat(result.id()).isEqualTo(id);
        assertThat(result.content()).isEqualTo("测试内容");
        assertThat(result.metadata()).containsEntry("wing", "language_development");
        assertThat(result.metadata()).containsEntry("room", "early_communication");
    }
}
