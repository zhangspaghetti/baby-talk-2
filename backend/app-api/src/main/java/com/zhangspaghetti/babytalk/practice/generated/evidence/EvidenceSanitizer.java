package com.zhangspaghetti.babytalk.practice.generated.evidence;

import com.zhangspaghetti.babytalk.practice.discovery.PracticeDiscoveryPolicyProperties;
import com.zhangspaghetti.babytalk.practice.discovery.SceneTextCanonicalizer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Optional;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class EvidenceSanitizer {

    public static final String VERSION = "evidence-sanitizer-v1";
    private static final int MAX_CODE_POINTS = 280;
    private static final Pattern DEFAULT_EMAIL = Pattern.compile(
            "(?i)(?<![\\p{L}\\p{N}._%+-])[\\p{L}\\p{N}._%+-]+@[\\p{L}\\p{N}.-]+\\.[\\p{L}]{2,}(?![\\p{L}\\p{N}._%+-])");
    private static final Pattern DEFAULT_PHONE = Pattern.compile(
            "(?<!\\p{Nd})(?:\\p{Nd}[\\s-]?){10}\\p{Nd}(?!\\p{Nd})");
    private static final Pattern DEFAULT_BABY_NAME = Pattern.compile(
            "(?i)(?:宝宝|宝贝|孩子|娃|baby)\\s*(?:叫|名叫|名字是|名字|named|name is)\\s*[\\p{IsHan}A-Za-z]{1,16}");
    private static final Pattern NATIONAL_ID = Pattern.compile(
            "(?<!\\p{Nd})(?:\\p{Nd}{15}|\\p{Nd}{17}[0-9Xx])(?![0-9Xx\\p{Nd}])");
    private static final Pattern CONTEXTUAL_PHONE = Pattern.compile(
            "(?i)(?:phone|tel|手机号|手机|固定电话|电话)\\s*[:：=]?\\s*(?:\\+?\\p{Nd}[\\s()\\-]?){7,}\\p{Nd}");
    private static final Pattern EXPLICIT_ACCOUNT = Pattern.compile(
            "(?i)(?:account[ _-]?id|user[ _-]?id|owner[ _-]?id|installation[ _-]?id|open[ _-]?id|"
                    + "账号|账户|微信号|qq号)\\s*(?:[:：=]\\s*|\\s+)[\\p{L}\\p{N}._-]{3,}");
    private static final Pattern MARKDOWN_LINK = Pattern.compile("\\[([^]\\r\\n]+)]\\([^)]*\\)");
    private static final Pattern URL = Pattern.compile("(?i)(?:https?://|www\\.)\\S+");
    private static final Pattern HTML_TAG = Pattern.compile("<[^>]*>");
    private static final Pattern LIST_MARKER = Pattern.compile("(?m)^\\s*(?:[-*+]\\s+|\\d+[.)]\\s+)");
    private static final Pattern MARKDOWN_MARKER = Pattern.compile("(?m)^\\s{0,3}#{1,6}\\s+|[*_`~]");
    private static final Pattern INSTRUCTION = Pattern.compile(
            "(?i)(?:忽\\s*略\\s*(?:以上|前文|之前)(?:的)?(?:指令|内容|说明)?|"
                    + "(?:执行|遵循)(?:以下|这些)(?:指令|命令)|"
                    + "ignore\\s+(?:all\\s+)?(?:previous|prior|above)\\s+(?:instructions?|content)|"
                    + "system\\s+prompt|developer\\s+message)");
    private static final Pattern WHITESPACE = Pattern.compile("[\\p{Z}\\s]+", Pattern.UNICODE_CHARACTER_CLASS);
    private static final Pattern REMOVABLE_INVISIBLES = Pattern.compile("[\\u200B\\u200C\\u2060\\uFEFF]");
    private static final Pattern GRAPHEME = Pattern.compile("\\X");
    private static final Pattern SENTENCE_OR_PARAGRAPH_BOUNDARY = Pattern.compile("(?<=[。！？!?；;\\r\\n])");

    private final SceneTextCanonicalizer canonicalizer;
    private final Pattern phonePattern;
    private final Pattern emailPattern;
    private final Pattern babyNamePattern;

    public EvidenceSanitizer() {
        this(new SceneTextCanonicalizer(), DEFAULT_PHONE, DEFAULT_EMAIL, DEFAULT_BABY_NAME);
    }

    @Autowired
    public EvidenceSanitizer(
            SceneTextCanonicalizer canonicalizer,
            PracticeDiscoveryPolicyProperties policyProperties
    ) {
        this(
                canonicalizer,
                policyProperties.compiledPhonePattern(),
                policyProperties.compiledEmailPattern(),
                policyProperties.compiledBabyNamePattern());
    }

    EvidenceSanitizer(
            SceneTextCanonicalizer canonicalizer,
            Pattern phonePattern,
            Pattern emailPattern,
            Pattern babyNamePattern
    ) {
        this.canonicalizer = canonicalizer;
        this.phonePattern = phonePattern;
        this.emailPattern = emailPattern;
        this.babyNamePattern = babyNamePattern;
    }

    public Optional<EvidenceSummary> sanitize(String rawSummary) {
        if (rawSummary == null || rawSummary.isBlank()) {
            return Optional.empty();
        }
        var rawForms = canonicalizer.derive(detectionText(rawSummary));
        if (rawForms.riskSignals().bidiControlPresent()
                || rawForms.securityText() == null
                || containsPii(rawForms.securityText())) {
            return Optional.empty();
        }
        var safeSegments = new StringBuilder();
        for (var segment : SENTENCE_OR_PARAGRAPH_BOUNDARY.split(rawSummary)) {
            var segmentForms = canonicalizer.derive(detectionText(segment));
            if (segmentForms.securityText() == null || INSTRUCTION.matcher(segmentForms.securityText()).find()) {
                continue;
            }
            var cleaned = cleanDisplaySegment(REMOVABLE_INVISIBLES.matcher(segment).replaceAll(""));
            if (!cleaned.isBlank()) {
                if (!safeSegments.isEmpty()) {
                    safeSegments.append(' ');
                }
                safeSegments.append(cleaned);
            }
        }
        var sanitized = WHITESPACE.matcher(safeSegments).replaceAll(" ").trim();
        sanitized = truncateGraphemeSafe(sanitized, MAX_CODE_POINTS);
        if (sanitized.isBlank()) {
            return Optional.empty();
        }
        return Optional.of(new EvidenceSummary(sanitized, sha256(sanitized)));
    }

    private String detectionText(String value) {
        var result = HTML_TAG.matcher(value).replaceAll("");
        result = MARKDOWN_MARKER.matcher(result).replaceAll("");
        return result;
    }

    private String cleanDisplaySegment(String value) {
        if (value == null) {
            return "";
        }
        var result = MARKDOWN_LINK.matcher(value).replaceAll("$1");
        result = HTML_TAG.matcher(result).replaceAll(" ");
        result = URL.matcher(result).replaceAll(" ");
        result = LIST_MARKER.matcher(result).replaceAll("");
        result = MARKDOWN_MARKER.matcher(result).replaceAll("");
        return WHITESPACE.matcher(result).replaceAll(" ").trim();
    }

    private boolean containsPii(String securityText) {
        return emailPattern.matcher(securityText).find()
                || phonePattern.matcher(securityText).find()
                || babyNamePattern.matcher(securityText).find()
                || NATIONAL_ID.matcher(securityText).find()
                || CONTEXTUAL_PHONE.matcher(securityText).find()
                || EXPLICIT_ACCOUNT.matcher(securityText).find();
    }

    private String truncateGraphemeSafe(String value, int maximumCodePoints) {
        var matcher = GRAPHEME.matcher(value);
        var result = new StringBuilder();
        var codePoints = 0;
        while (matcher.find()) {
            var grapheme = matcher.group();
            var graphemeCodePoints = grapheme.codePointCount(0, grapheme.length());
            if (codePoints + graphemeCodePoints > maximumCodePoints) {
                break;
            }
            result.append(grapheme);
            codePoints += graphemeCodePoints;
        }
        return result.toString().stripTrailing();
    }

    static String sha256(String value) {
        try {
            var bytes = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            var result = new StringBuilder(bytes.length * 2);
            for (byte item : bytes) {
                result.append(String.format("%02x", item));
            }
            return result.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}
