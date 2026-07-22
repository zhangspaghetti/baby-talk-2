package com.zhangspaghetti.babytalk.practice.discovery;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator;
import java.util.Locale;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service
@Profile({"dev", "test"})
@ConditionalOnProperty(prefix = "babytalk.practice.discovery.custom-scene", name = "provider-mode", havingValue = "fake")
public class FakeCustomSceneGenerationService implements CustomSceneGenerator {

    private final PracticeDiscoveryCustomSceneProperties properties;

    public FakeCustomSceneGenerationService(PracticeDiscoveryCustomSceneProperties properties) {
        this.properties = properties;
    }

    @Override
    public GeneratedPracticeContentCandidate generate(GeneratorRequest request) {
        if (!properties.enabled()) {
            throw new GenerationUnavailableException(GenerationUnavailableReason.PROVIDER_DISABLED);
        }
        return successCandidate(request);
    }

    private GeneratedPracticeContentCandidate successCandidate(GeneratorRequest request) {
        var scene = normalizeMode(request.displayText());
        if (scene.contains("shoe") || scene.contains("鞋") || scene.contains("出门")) {
            return candidate("出门准备", "穿鞋出门", "Shoes on", "拿起鞋子。", "慢慢说一遍。", "Shoes on.", "穿鞋出门。");
        }
        if (scene.contains("diaper") || scene.contains("尿布") || scene.contains("换")) {
            return candidate("日常照护", "换尿布", "Diaper change", "换上干净尿布。", "轻声说，等宝宝看过来再重复。", "Fresh diaper.", "干净尿布。");
        }
        if (scene.contains("sleep") || scene.contains("bed") || scene.contains("睡") || scene.contains("哄")) {
            return candidate("家庭节奏", "睡前安抚", "Bedtime care", "抱抱宝宝。", "放慢声音，先说短句。", "Sleepy baby.", "宝宝困了。");
        }
        if (scene.contains("feed") || scene.contains("milk") || scene.contains("meal")
                || scene.contains("奶") || scene.contains("饭")) {
            return candidate("日常照护", "喂奶时间", "Feeding time", "抱稳宝宝。", "慢慢说一遍。", "Milk time.", "喝奶时间。");
        }
        if (scene.contains("soothe") || scene.contains("calm") || scene.contains("cuddle")
                || scene.contains("安抚") || scene.contains("抱抱") || scene.contains("哭闹")) {
            return candidate("日常照护", "安抚宝宝", "Calm care", "抱抱宝宝。", "轻声重复。", "Calm baby.", "安抚宝宝。");
        }
        if (scene.contains("刷牙")) {
            return candidate("日常照护", "刷牙时间", "Brush teeth", "拿起牙刷。", "慢慢说一遍。", "Brush teeth.", "刷牙啦。");
        }
        if (scene.contains("dress") || scene.contains("穿衣")) {
            return candidate("出门准备", "穿衣服", "Getting dressed", "拿起衣服。", "慢慢说一遍。", "Shirt on.", "穿衣服。");
        }
        if (scene.contains("potty") || scene.contains("toilet") || scene.contains("如厕")) {
            return candidate("日常照护", "如厕时间", "Potty time", "陪着宝宝坐稳。", "轻声说一遍。", "Potty time.", "如厕时间。");
        }
        throw new GenerationUnavailableException(GenerationUnavailableReason.FAKE_SCENE_NOT_SUPPORTED);
    }

    private GeneratedPracticeContentCandidate candidate(
            String spaceTitleZh,
            String activityTitleZh,
            String sceneTagEn,
            String tprActionZh,
            String deliveryGuidanceZh,
            String englishText,
            String chineseText
    ) {
        return new GeneratedPracticeContentCandidate(
                spaceTitleZh,
                activityTitleZh,
                sceneTagEn,
                tprActionZh,
                deliveryGuidanceZh,
                englishText,
                chineseText,
                englishText.toLowerCase(Locale.ROOT).replaceAll("[^a-z ]", "").trim(),
                "starter",
                "fake"
        );
    }

    private String normalizeMode(String value) {
        return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
    }
}
