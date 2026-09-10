package com.zhangspaghetti.babytalk.practice.preset;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PresetSceneCatalogMapper {

    List<PresetSceneCatalogService.PublishedPresetScene> findPublished();

    PresetSceneCatalogService.PublishedPresetScene findPublishedBySceneId(
            @Param("presetSceneId") String presetSceneId
    );
}
