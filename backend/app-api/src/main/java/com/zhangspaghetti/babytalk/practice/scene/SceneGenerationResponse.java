package com.zhangspaghetti.babytalk.practice.scene;

import java.util.List;
import java.util.Objects;

/** Privacy-safe response contract for one complete generated care moment. */
public record SceneGenerationResponse(
        String generatedContentId,
        String bundleSchemaVersion,
        RouteView route,
        SceneView scene,
        UtteranceView starter,
        List<UtteranceView> reactionSupports,
        SourceView source
) {

    public SceneGenerationResponse {
        generatedContentId = requireText(generatedContentId, "generatedContentId");
        bundleSchemaVersion = requireText(bundleSchemaVersion, "bundleSchemaVersion");
        route = Objects.requireNonNull(route, "route");
        scene = Objects.requireNonNull(scene, "scene");
        starter = Objects.requireNonNull(starter, "starter");
        reactionSupports = reactionSupports == null ? List.of() : List.copyOf(reactionSupports);
        source = Objects.requireNonNull(source, "source");
    }

    public record RouteView(
            String sceneId,
            String spaceId,
            String momentId,
            String activityId,
            String phraseId
    ) {
        public RouteView {
            sceneId = requireText(sceneId, "sceneId");
            spaceId = requireText(spaceId, "spaceId");
            momentId = requireText(momentId, "momentId");
            activityId = requireText(activityId, "activityId");
            phraseId = requireText(phraseId, "phraseId");
        }
    }

    public record SceneView(
            String spaceTitle,
            String activityTitle,
            String sceneTag
    ) {
        public SceneView {
            spaceTitle = requireText(spaceTitle, "spaceTitle");
            activityTitle = requireText(activityTitle, "activityTitle");
            sceneTag = requireText(sceneTag, "sceneTag");
        }
    }

    public record UtteranceView(
            String utteranceId,
            String phraseId,
            String english,
            String chinese,
            String pronunciation,
            String tprActionZh,
            String deliveryGuidanceZh,
            String difficulty,
            String role,
            String reaction,
            int displayOrder,
            ProviderProvenance providerProvenance
    ) {
        public UtteranceView {
            utteranceId = requireText(utteranceId, "utteranceId");
            phraseId = requireText(phraseId, "phraseId");
            english = requireText(english, "english");
            chinese = requireText(chinese, "chinese");
            pronunciation = requireText(pronunciation, "pronunciation");
            tprActionZh = requireText(tprActionZh, "tprActionZh");
            deliveryGuidanceZh = requireText(deliveryGuidanceZh, "deliveryGuidanceZh");
            difficulty = requireText(difficulty, "difficulty");
            role = requireText(role, "role");
            providerProvenance = Objects.requireNonNull(providerProvenance, "providerProvenance");
            if (displayOrder < 1 || displayOrder > 6) {
                throw new IllegalArgumentException("displayOrder must be between 1 and 6");
            }
        }
    }

    public record ProviderProvenance(
            String origin,
            String providerName,
            String modelName,
            int attemptNumber
    ) {
        public ProviderProvenance {
            origin = requireText(origin, "origin");
            providerName = requireText(providerName, "providerName");
            modelName = requireText(modelName, "modelName");
            if (attemptNumber < 1 || attemptNumber > 5) {
                throw new IllegalArgumentException("attemptNumber must be between 1 and 5");
            }
        }
    }

    public record SourceView(String type, String presetSceneId, Integer presetSceneVersion) {
        public SourceView {
            type = requireText(type, "type");
            if ("custom".equals(type) && (presetSceneId != null || presetSceneVersion != null)) {
                throw new IllegalArgumentException("custom source cannot expose preset metadata");
            }
            if ("preset".equals(type)
                    && (presetSceneId == null || presetSceneId.isBlank()
                    || presetSceneVersion == null || presetSceneVersion < 1)) {
                throw new IllegalArgumentException("preset source requires preset metadata");
            }
            if (!"custom".equals(type) && !"preset".equals(type)) {
                throw new IllegalArgumentException("unsupported source type");
            }
        }
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must be non-blank");
        }
        return value;
    }
}
