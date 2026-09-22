package com.zhangspaghetti.babytalk.practice.preset;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PresetSceneCatalogService {

    private final PresetSceneCatalogMapper mapper;

    public PresetSceneCatalogService(PresetSceneCatalogMapper mapper) {
        this.mapper = mapper;
    }

    @Transactional(readOnly = true)
    public List<PublishedPresetScene> listPublished() {
        return mapper.findPublished();
    }

    @Transactional(readOnly = true)
    public PublishedPresetScene requirePublished(String presetSceneId) {
        var scene = mapper.findPublishedBySceneId(presetSceneId);
        if (scene == null) {
            throw presetSceneUnavailable();
        }
        return scene;
    }

    private ContractException presetSceneUnavailable() {
        return new ContractException(
                HttpStatus.NOT_FOUND,
                "preset_scene_unavailable",
                "预置场景暂不可用。",
                Map.of());
    }

    public record PublishedPresetScene(
            long activityId,
            long versionId,
            int publishedVersion,
            String presetSceneId,
            String spaceId,
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            int sortOrder,
            String generationBrief
    ) {
    }
}
