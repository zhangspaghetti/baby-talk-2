package com.zhangspaghetti.babytalk.practice.discovery;

import java.util.Collection;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public final class PolicyTextMatcher {

    private static final Pattern CJK = Pattern.compile("[\\p{IsHan}]");
    private final SceneTextCanonicalizer canonicalizer;

    public PolicyTextMatcher(SceneTextCanonicalizer canonicalizer) {
        this.canonicalizer = canonicalizer;
    }

    public boolean containsAny(String text, Collection<String> markers) {
        if (text == null || markers == null || markers.isEmpty()) {
            return false;
        }
        return markers.stream().anyMatch(marker -> containsMarker(text, marker));
    }

    public boolean containsMarker(String text, String marker) {
        var canonicalText = canonicalizer.canonicalize(text);
        var canonicalMarker = canonicalizer.canonicalize(marker);
        if (canonicalText == null || canonicalMarker == null) {
            return false;
        }
        var searchable = canonicalText.toLowerCase(Locale.ROOT);
        var needle = canonicalMarker.toLowerCase(Locale.ROOT);
        if (CJK.matcher(needle).find()) {
            return searchable.contains(needle);
        }
        var boundaryPattern = Pattern.compile(
                "(?<![\\p{L}\\p{N}_])" + Pattern.quote(needle)
                        + "(?![\\p{L}\\p{N}_])",
                Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);
        return boundaryPattern.matcher(searchable).find();
    }
}
