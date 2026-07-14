package com.zhangspaghetti.babytalk.palace;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordMapper.ChunkRow;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordRepository.ChunkResult;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * PalaceKeywordRepository 单元测试 — 验证参数归一化、限流防御和 metadata 解析。
 */
@ExtendWith(MockitoExtension.class)
class PalaceKeywordRepositoryTest {

    @Mock
    private PalaceKeywordMapper palaceKeywordMapper;

    private PalaceKeywordRepository repository;

    @BeforeEach
    void setUp() {
        repository = new PalaceKeywordRepository(palaceKeywordMapper, JsonMapper.builder().build());
    }

    @Test
    void searchByKeywords_keywordsOnlyDelegatesToMapperAndParsesMetadata() {
        UUID id = UUID.randomUUID();
        when(palaceKeywordMapper.searchByKeywords("宝宝说话", null, null, 5))
                .thenReturn(List.of(new ChunkRow(id, "测试内容", "{\"wing\":\"language_development\"}", 0.82d)));

        List<ChunkResult> results = repository.searchByKeywords("宝宝说话", null, null, 5);

        verify(palaceKeywordMapper).searchByKeywords("宝宝说话", null, null, 5);
        assertThat(results).hasSize(1);
        assertThat(results.get(0).id()).isEqualTo(id);
        assertThat(results.get(0).content()).isEqualTo("测试内容");
        assertThat(results.get(0).metadata()).containsEntry("wing", "language_development");
        assertThat(results.get(0).keywordScore()).isEqualTo(0.82d);
    }

    @Test
    void searchByKeywords_withWingAndRoomNormalizesFiltersBeforeDelegating() {
        when(palaceKeywordMapper.searchByKeywords("早期沟通", "language_development", "early_communication", 3))
                .thenReturn(List.of());

        repository.searchByKeywords(" 早期沟通 ", "LANGUAGE_DEVELOPMENT", "EARLY_COMMUNICATION", 3);

        verify(palaceKeywordMapper).searchByKeywords("早期沟通", "language_development", "early_communication", 3);
    }

    @Test
    void searchByKeywords_nullKeywords_returnsEmptyWithoutMapperCall() {
        List<ChunkResult> results = repository.searchByKeywords(null, null, null, 5);

        assertThat(results).isEmpty();
        verify(palaceKeywordMapper, never()).searchByKeywords(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.anyInt());
    }

    @Test
    void searchByKeywords_blankKeywords_returnsEmptyWithoutMapperCall() {
        List<ChunkResult> results = repository.searchByKeywords("   ", null, null, 5);

        assertThat(results).isEmpty();
        verify(palaceKeywordMapper, never()).searchByKeywords(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.anyInt());
    }

    @Test
    void searchByKeywords_zeroLimit_defaultsToFive() {
        when(palaceKeywordMapper.searchByKeywords("宝宝", null, null, 5)).thenReturn(List.of());

        repository.searchByKeywords("宝宝", null, null, 0);

        verify(palaceKeywordMapper).searchByKeywords("宝宝", null, null, 5);
    }

    @Test
    void searchByKeywords_negativeLimit_defaultsToFive() {
        when(palaceKeywordMapper.searchByKeywords("宝宝", null, null, 5)).thenReturn(List.of());

        repository.searchByKeywords("宝宝", null, null, -3);

        verify(palaceKeywordMapper).searchByKeywords("宝宝", null, null, 5);
    }

    @Test
    void readChunkById_nullId_returnsEmpty() {
        Optional<ChunkResult> result = repository.readChunkById(null);

        assertThat(result).isEmpty();
        verify(palaceKeywordMapper, never()).readChunkById(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void readChunkById_notFound_returnsEmpty() {
        UUID testId = UUID.randomUUID();
        when(palaceKeywordMapper.readChunkById(testId)).thenReturn(null);

        Optional<ChunkResult> result = repository.readChunkById(testId);

        assertThat(result).isEmpty();
        verify(palaceKeywordMapper).readChunkById(testId);
    }

    @Test
    void readChunkById_returnsParsedChunk() {
        UUID testId = UUID.randomUUID();
        when(palaceKeywordMapper.readChunkById(testId))
                .thenReturn(new ChunkRow(testId, "测试内容", "{\"room\":\"early_communication\"}", null));

        Optional<ChunkResult> result = repository.readChunkById(testId);

        assertThat(result).isPresent();
        assertThat(result.get().metadata()).containsEntry("room", "early_communication");
        verify(palaceKeywordMapper).readChunkById(testId);
    }

    @Test
    void malformedMetadataJsonFallsBackToEmptyMap() {
        UUID id = UUID.randomUUID();
        when(palaceKeywordMapper.searchByKeywords("宝宝", null, null, 5))
                .thenReturn(List.of(new ChunkRow(id, "测试内容", "{not-json}", 0.25d)));

        List<ChunkResult> results = repository.searchByKeywords("宝宝", null, null, 5);

        assertThat(results).hasSize(1);
        assertThat(results.get(0).metadata()).isEqualTo(Map.of());
    }
}
