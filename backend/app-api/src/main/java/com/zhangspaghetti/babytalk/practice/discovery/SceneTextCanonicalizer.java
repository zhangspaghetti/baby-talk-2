package com.zhangspaghetti.babytalk.practice.discovery;

import java.text.Normalizer;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public final class SceneTextCanonicalizer {

    private static final Pattern WHITESPACE = Pattern.compile("\\s+", Pattern.UNICODE_CHARACTER_CLASS);
    private static final Pattern GRAPHEME = Pattern.compile("\\X");

    public String canonicalize(String value) {
        if (value == null) {
            return null;
        }
        var normalized = Normalizer.normalize(value, Normalizer.Form.NFKC);
        normalized = WHITESPACE.matcher(normalized).replaceAll(" ").trim();
        return normalized.isEmpty() ? null : normalized;
    }

    public int graphemeLength(String value) {
        if (value == null || value.isEmpty()) {
            return 0;
        }
        var matcher = GRAPHEME.matcher(value);
        var count = 0;
        while (matcher.find()) {
            if (!WHITESPACE.matcher(matcher.group()).matches()) {
                count++;
            }
        }
        return count;
    }

    public int codePointLength(String value) {
        return value == null ? 0 : value.codePointCount(0, value.length());
    }
}
