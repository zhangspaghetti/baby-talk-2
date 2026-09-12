package com.zhangspaghetti.babytalk.practice.discovery.safety;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.ConstructorBinding;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "babytalk.practice.health-safety")
public record CustomSceneSafetyProperties(
        String policyVersion,
        Duration classifierTimeout,
        Map<String, Template> templates,
        Map<String, List<String>> emergencySignals
) {

    private static final Duration DEFAULT_CLASSIFIER_TIMEOUT = Duration.ofSeconds(3);
    private static final String DEFAULT_POLICY_VERSION = "health-safety-v1";
    private static final String DEFAULT_LOCALE = "zh-CN";
    private static final List<String> TREATMENT_FIELDS = List.of("剂量", "服用", "诊断为");

    @ConstructorBinding
    public CustomSceneSafetyProperties {
        policyVersion = requiredText(policyVersion, "policy version");
        classifierTimeout = requiredPositive(classifierTimeout, "classifier timeout");
        templates = immutableTemplates(templates);
        emergencySignals = immutableSignals(emergencySignals);
    }

    public static CustomSceneSafetyProperties defaults() {
        var templates = new LinkedHashMap<String, Template>();
        templates.put("health-emergency-v1", new Template(
                "emergency",
                DEFAULT_LOCALE,
                "请立即寻求医疗帮助",
                "你描述的情况可能需要紧急处理。请立即联系当地急救服务，或前往急诊。不要等待本应用进一步回复。"));
        templates.put("health-concern-v1", new Template(
                "seek-medical-help",
                DEFAULT_LOCALE,
                "先关注宝宝的身体状况",
                "你描述的是宝宝的健康问题。仅凭这段描述，无法判断原因或严重程度，请联系儿科医生进行评估。如果宝宝出现呼吸困难、叫不醒或抽搐，请立即联系当地急救服务。"));
        templates.put("health-prompt-assessment-v1", new Template(
                "seek-medical-help",
                DEFAULT_LOCALE,
                "请尽快寻求医疗评估",
                "你描述的情况需要及时由医护人员评估，请现在联系儿科医生或就近医疗机构。如果宝宝出现呼吸困难、叫不醒或抽搐，请立即联系当地急救服务。"));
        templates.put("health-uncertain-v1", new Template(
                "uncertain",
                DEFAULT_LOCALE,
                "目前无法判断宝宝的状况",
                "现有信息不足以判断宝宝的情况。请联系儿科医生说明你的担忧。如果你认为宝宝情况严重，或出现呼吸困难、叫不醒、抽搐，请立即寻求紧急医疗帮助。"));
        templates.put("health-assessment-unavailable-v1", new Template(
                "unavailable",
                DEFAULT_LOCALE,
                "暂时无法判断这段描述",
                "暂时无法判断这段描述。请联系儿科医生说明你的担忧；如果宝宝有紧急症状，请立即寻求医疗帮助。"));

        var signals = new LinkedHashMap<String, List<String>>();
        signals.put("breathing-difficulty", List.of(
                "呼吸困难", "喘不过气", "喘不上气", "喘不上来", "呼吸不畅", "呼吸费力", "呼吸急促",
                "不能呼吸", "无法呼吸", "呼吸不上来"));
        signals.put("blue-lips", List.of(
                "嘴唇发青", "嘴唇青紫", "口唇发青", "口唇青紫", "脸色发青", "脸色青紫", "发绀"));
        signals.put("cannot-wake", List.of(
                "叫不醒", "喊不醒", "唤不醒", "无法唤醒", "昏迷", "没有反应"));
        signals.put("seizure", List.of("抽搐", "痉挛", "抽风", "癫痫发作"));
        signals.put("suspected-poisoning", List.of(
                "疑似吞服", "疑似误食", "误食", "误服", "误吞", "吞服", "吞了药", "吃了药",
                "吞了清洁剂", "喝了清洁剂", "吃了清洁剂", "疑似中毒", "中毒", "毒物"));
        signals.put("child-green-vomit", List.of(
                "绿色呕吐", "吐绿色", "呕吐绿色", "吐出绿色", "绿色的呕吐物", "胆汁性呕吐"));

        return new CustomSceneSafetyProperties(
                DEFAULT_POLICY_VERSION,
                DEFAULT_CLASSIFIER_TIMEOUT,
                templates,
                signals);
    }

    private static String requiredText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("health safety " + field + " must not be blank");
        }
        return value.trim();
    }

    private static Duration requiredPositive(Duration value, String field) {
        if (value == null || value.isZero() || value.isNegative()) {
            throw new IllegalArgumentException("health safety " + field + " must be positive");
        }
        return value;
    }

    private static Map<String, Template> immutableTemplates(
            Map<String, Template> values
    ) {
        if (values == null || values.isEmpty()) {
            throw new IllegalArgumentException("health safety templates must not be empty");
        }
        var copied = new LinkedHashMap<String, Template>();
        values.forEach((key, value) -> {
            var normalizedKey = requiredText(key, "template id");
            if (value == null) {
                throw new IllegalArgumentException("health safety template must not be null");
            }
            copied.put(normalizedKey, value);
        });
        return Collections.unmodifiableMap(copied);
    }

    private static Map<String, List<String>> immutableSignals(Map<String, List<String>> values) {
        if (values == null || values.isEmpty()) {
            throw new IllegalArgumentException("health safety emergency signals must not be empty");
        }
        var copied = new LinkedHashMap<String, List<String>>();
        values.forEach((key, markers) -> {
            var normalizedKey = requiredText(key, "emergency signal");
            if (markers == null || markers.isEmpty()) {
                throw new IllegalArgumentException("health safety emergency signal markers must not be empty");
            }
            var normalizedMarkers = new ArrayList<String>();
            markers.forEach(marker -> {
                var normalizedMarker = requiredText(marker, "emergency signal marker").toLowerCase(Locale.ROOT);
                if (!normalizedMarkers.contains(normalizedMarker)) {
                    normalizedMarkers.add(normalizedMarker);
                }
            });
            if (normalizedMarkers.isEmpty()) {
                throw new IllegalArgumentException("health safety emergency signal markers must not be empty");
            }
            copied.put(normalizedKey, List.copyOf(normalizedMarkers));
        });
        return Collections.unmodifiableMap(copied);
    }

    public record Template(
            String action,
            String locale,
            String titleZh,
            String messageZh
    ) {

        public Template {
            action = requiredText(action, "template action").toLowerCase(Locale.ROOT);
            locale = requiredText(locale, "template locale");
            titleZh = requiredText(titleZh, "template title");
            messageZh = requiredText(messageZh, "template message");
            if (!DEFAULT_LOCALE.equals(locale)) {
                throw new IllegalArgumentException("health safety template locale must be zh-CN");
            }
            if (TREATMENT_FIELDS.stream().anyMatch(messageZh::contains)) {
                throw new IllegalArgumentException("health safety template message must not contain treatment fields");
            }
        }
    }
}
