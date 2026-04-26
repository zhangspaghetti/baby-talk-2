package com.zhangspaghetti.babytalk.palace;

import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PalaceKeywordMapper {

    List<ChunkRow> searchByKeywords(
            @Param("keywords") String keywords,
            @Param("wing") String wing,
            @Param("room") String room,
            @Param("limit") int limit
    );

    ChunkRow readChunkById(@Param("id") UUID id);

    record ChunkRow(
            UUID id,
            String content,
            String metadataJson
    ) {
    }
}
