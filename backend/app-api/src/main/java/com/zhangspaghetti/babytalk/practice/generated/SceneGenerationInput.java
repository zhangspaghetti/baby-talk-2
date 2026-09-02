package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.scene.GenerationSubject;
import com.zhangspaghetti.babytalk.practice.scene.ScenePersonalizationContext;

/**
 * Source-neutral input contract shared by preset and custom scene generation.
 *
 * <p>Generation fields can contain prompt, installation, and profile material.
 * Diagnostic rendering therefore exposes only the source tag and preset
 * presence.</p>
 */
public record SceneGenerationInput(
        String inputSource,
        String resolvedSceneText,
        GenerationSubject subject,
        ScenePersonalizationContext personalization,
        Long presetActivityId,
        Long presetSceneVersionId,
        String stableSpaceId,
        String stableActivityId,
        String locale,
        String installationId,
        String clientRequestId
) {

    @Override
    public String toString() {
        return "SceneGenerationInput{"
                + "inputSource='" + sourceTag(inputSource) + '\''
                + ", preset=" + (presetActivityId != null || presetSceneVersionId != null)
                + '}';
    }

    private static String sourceTag(String value) {
        return "custom".equals(value) || "preset".equals(value) ? value : "unknown";
    }

}
