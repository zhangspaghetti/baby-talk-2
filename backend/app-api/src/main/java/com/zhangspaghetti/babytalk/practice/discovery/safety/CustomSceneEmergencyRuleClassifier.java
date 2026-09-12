package com.zhangspaghetti.babytalk.practice.discovery.safety;

import com.zhangspaghetti.babytalk.practice.discovery.SceneTextForms;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Action.EMERGENCY;
import static com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyAssessment.Intent.REAL_HEALTH_CONCERN;

@Component
public final class CustomSceneEmergencyRuleClassifier {

    private static final Pattern CLAUSE_BOUNDARY = Pattern.compile("[，。！？；\\n\\r,.!?;:]");
    private static final Pattern NEGATION_MARKER = Pattern.compile(
            "没|没有|并没有|不是|不|无|未|未见|不再|不曾|从未|否认|并未|未曾|没有出现");
    private static final Pattern UNCERTAINTY_MARKER = Pattern.compile(
            "不知道是不是|不知道有没有|不知道有沒有|不确定是否|不确定有没有|会不会|可能是");
    private static final Pattern HISTORICAL_MARKER = Pattern.compile("曾经|曾經|以前|之前|过去|過去");
    private static final Pattern FICTIONAL_MARKER = Pattern.compile(
            "故事里|故事中|小说里|小說裡|小说中|小說中|剧情里|劇情裡|剧情中|劇情中|"
                    + "假设|假設|假装|假裝|游戏里|遊戲裡|游戏中|遊戲中|只是游戏|只是遊戲|玩医生游戏");
    private static final Pattern CURRENT_CUE = Pattern.compile(
            "现在|目前|此刻|正在|刚刚|剛剛|刚才|剛才|现实|現實|真实|真實|真的|实际|實際|事实上|事實上");
    private static final Pattern CONTRAST_MARKER = Pattern.compile("但|但是|可是|不过|不過|然而|而");
    private static final Pattern KNOWLEDGE_QUERY = Pattern.compile(
            "什么是|什么叫|如何预防|怎么预防|怎样预防|如何避免|怎么避免|怎样避免|"
                    + "如何判断|怎么判断|怎样判断|预防|預防");
    private static final Pattern RECOVERY_AFTER = Pattern.compile(
            "^(?:(?:但|但是|可是|不过|而)\\s*)?(?:(?:现在|目前|后来|之后|随后)\\s*)?"
                    + "(?:(?:已经|已)\\s*)?(?:好了|恢复了?|康复了?|没事了?|正常了?|消失了?|缓解了?|不再了?)");
    private static final Pattern RECOVERY_CONTINUATION = Pattern.compile(
            "^[，,\\s]*(?:(?:现在|目前|后来|之后|随后)?(?:已经|已)?"
                    + "(?:好了|恢复了?|康复了?|没事了?|正常了?|消失了?|缓解了?|不再了?))");
    private static final Pattern FICTIONAL_AFTER = Pattern.compile(
            ".*(?:只是故事|只是小說|只是小说|只是剧情|只是劇情|不是现实|不是現實|现实没有|現實沒有|只是游戏|只是遊戲).*"
                    + "$");

    private final String policyVersion;
    private final Map<String, List<String>> emergencySignals;

    public CustomSceneEmergencyRuleClassifier() {
        this(CustomSceneSafetyProperties.defaults());
    }

    @Autowired
    public CustomSceneEmergencyRuleClassifier(CustomSceneSafetyProperties properties) {
        this.policyVersion = properties.policyVersion();
        this.emergencySignals = properties.emergencySignals();
    }

    public Optional<CustomSceneSafetyAssessment> classify(SceneTextForms forms) {
        if (forms == null) {
            return Optional.empty();
        }
        var text = forms.securityText();
        if (text == null || text.isBlank()) {
            text = forms.displayText();
        }
        if (text == null || text.isBlank()) {
            return Optional.empty();
        }
        var normalizedText = text.toLowerCase(Locale.ROOT);
        if (emergencySignals.values().stream().anyMatch(markers -> hasActiveMarker(normalizedText, markers))) {
            return Optional.of(new CustomSceneSafetyAssessment(
                    REAL_HEALTH_CONCERN,
                    EMERGENCY,
                    "health-emergency-v1",
                    policyVersion));
        }
        return Optional.empty();
    }

    private boolean hasActiveMarker(String text, List<String> markers) {
        for (var marker : markers) {
            for (var start = text.indexOf(marker); start >= 0; start = text.indexOf(marker, start + marker.length())) {
                if (isActiveOccurrence(text, start, marker.length())) {
                    return true;
                }
            }
        }
        return false;
    }

    private boolean isActiveOccurrence(String text, int start, int markerLength) {
        var end = start + markerLength;
        var clauseStart = clauseStart(text, start);
        var clauseEnd = clauseEnd(text, end);
        var before = text.substring(clauseStart, start);
        var after = text.substring(end, clauseEnd);
        var scope = text.substring(clauseStart, clauseEnd);
        if (KNOWLEDGE_QUERY.matcher(scope).find()
                || negatedBefore(before)
                || uncertainBefore(before)
                || scopedMarkerBefore(before, HISTORICAL_MARKER)) {
            return false;
        }
        if (fictionalPrefix(before)
                || FICTIONAL_AFTER.matcher(after).matches()) {
            return false;
        }
        if (RECOVERY_AFTER.matcher(after).find()) {
            return false;
        }
        var continuationEnd = Math.min(text.length(), clauseEnd + 32);
        return !RECOVERY_CONTINUATION.matcher(text.substring(clauseEnd, continuationEnd)).find();
    }

    private boolean negatedBefore(String before) {
        return scopedMarkerBefore(before, NEGATION_MARKER);
    }

    private boolean uncertainBefore(String before) {
        return scopedMarkerBefore(before, UNCERTAINTY_MARKER);
    }

    private boolean scopedMarkerBefore(String before, Pattern markerPattern) {
        var matcher = markerPattern.matcher(before);
        var lastMarkerEnd = -1;
        while (matcher.find()) {
            lastMarkerEnd = matcher.end();
        }
        if (lastMarkerEnd < 0) {
            return false;
        }
        var suffix = before.substring(lastMarkerEnd);
        return !CONTRAST_MARKER.matcher(suffix).find()
                && !CURRENT_CUE.matcher(suffix).find();
    }

    private boolean fictionalPrefix(String before) {
        var matcher = FICTIONAL_MARKER.matcher(before);
        var lastMarkerEnd = -1;
        while (matcher.find()) {
            lastMarkerEnd = matcher.end();
        }
        return lastMarkerEnd >= 0
                && !CURRENT_CUE.matcher(before.substring(lastMarkerEnd)).find();
    }

    private int clauseStart(String text, int index) {
        for (var cursor = index - 1; cursor >= 0; cursor--) {
            if (CLAUSE_BOUNDARY.matcher(text.substring(cursor, cursor + 1)).matches()) {
                return cursor + 1;
            }
        }
        return 0;
    }

    private int clauseEnd(String text, int index) {
        for (var cursor = index; cursor < text.length(); cursor++) {
            if (CLAUSE_BOUNDARY.matcher(text.substring(cursor, cursor + 1)).matches()) {
                return cursor;
            }
        }
        return text.length();
    }
}
