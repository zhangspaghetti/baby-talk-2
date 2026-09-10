package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.practice.preset.PresetSceneCatalogService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/practice/preset-scenes")
public class PresetSceneCatalogController {

    private final PresetSceneCatalogService catalogService;

    public PresetSceneCatalogController(PresetSceneCatalogService catalogService) {
        this.catalogService = catalogService;
    }

    @GetMapping
    public List<PresetSceneResponse> list() {
        return catalogService.listPublished().stream()
                .map(PresetSceneResponse::from)
                .toList();
    }

    public record PresetSceneResponse(
            String presetSceneId,
            int publishedVersion,
            String spaceId,
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            int sortOrder
    ) {

        private static PresetSceneResponse from(PresetSceneCatalogService.PublishedPresetScene scene) {
            return new PresetSceneResponse(
                    scene.presetSceneId(),
                    scene.publishedVersion(),
                    scene.spaceId(),
                    scene.title(),
                    scene.summary(),
                    scene.sceneTag(),
                    scene.coachTip(),
                    scene.sortOrder());
        }
    }
}
