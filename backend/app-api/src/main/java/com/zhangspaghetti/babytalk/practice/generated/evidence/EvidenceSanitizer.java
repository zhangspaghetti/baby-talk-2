package com.zhangspaghetti.babytalk.practice.generated.evidence;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Optional;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public class EvidenceSanitizer {

    public static final String VERSION = "evidence-sanitizer-v1";
    private static final int MAX_CODE_POINTS = 280;
    private static final Pattern EMAIL = Pattern.compile(
            "(?i)(?<![\\p{L}\\p{N}._%+-])[\\p{L}\\p{N}._%+-]+@[\\p{L}\\p{N}.-]+\\.[\\p{L}]{2,}(?![\\p{L}\\p{N}._%+-])");
    private static final Pattern PHONE = Pattern.compile("(?<!\\d)(?:\\+?86[- ]?)?1[3-9]\\d{9}(?!\\d)");
    private static final Pattern NATIONAL_ID = Pattern.compile("(?<!\\d)\\d{17}[0-9Xx](?![0-9Xx])");
    private static final Pattern MARKDOWN_LINK = Pattern.compile("\\[([^]\\r\\n]+)]\\([^)]*\\)");
    private static final Pattern URL = Pattern.compile("(?i)(?:https?://|www\\.)\\S+");
    private static final Pattern HTML_TAG = Pattern.compile("<[^>]*>");
    private static final Pattern LIST_MARKER = Pattern.compile("(?m)^\\s*(?:[-*+]\\s+|\\d+[.)]\\s+)");
    private static final Pattern MARKDOWN_MARKER = Pattern.compile("(?m)^\\s{0,3}#{1,6}\\s+|[*_`~]");
    private static final Pattern INSTRUCTION = Pattern.compile(
            "(?i)(?:忽略(?:以上|前文|之前)(?:的)?(?:指令|内容|说明)?|"
                    + "(?:执行|遵循)(?:以下|这些)(?:指令|命令)|"
                    + "ignore\\s+(?:all\\s+)?(?:previous|prior|above)\\s+(?:instructions?|content)|"
                    + "system\\s+prompt|developer\\s+message)");
    private static final Pattern WHITESPACE = Pattern.compile("\\s+");
    private static final Pattern GRAPHEME = Pattern.compile("\\X");

    public Optional<EvidenceSummary> sanitize(String rawSummary) {
        if (rawSummary == null || rawSummary.isBlank() || containsPii(rawSummary)) {
            return Optional.empty();
        }
        var sanitized = MARKDOWN_LINK.matcher(rawSummary).replaceAll("$1");
        sanitized = HTML_TAG.matcher(sanitized).replaceAll(" ");
        sanitized = URL.matcher(sanitized).replaceAll(" ");
        sanitized = LIST_MARKER.matcher(sanitized).replaceAll("");
        sanitized = MARKDOWN_MARKER.matcher(sanitized).replaceAll("");
        sanitized = INSTRUCTION.matcher(sanitized).replaceAll(" ");
        sanitized = WHITESPACE.matcher(sanitized).replaceAll(" ").trim();
        sanitized = truncateGraphemeSafe(sanitized, MAX_CODE_POINTS);
        if (sanitized.isBlank()) {
            return Optional.empty();
        }
        return Optional.of(new EvidenceSummary(sanitized, sha256(sanitized)));
    }

    private boolean containsPii(String value) {
        return EMAIL.matcher(value).find()
                || PHONE.matcher(value).find()
                || NATIONAL_ID.matcher(value).find();
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
