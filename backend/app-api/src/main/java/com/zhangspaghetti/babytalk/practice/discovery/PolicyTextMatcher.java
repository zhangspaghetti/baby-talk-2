package com.zhangspaghetti.babytalk.practice.discovery;

import java.util.Collection;
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

    public boolean containsAnyLiteral(String text, Collection<String> markers) {
        if (text == null || markers == null || markers.isEmpty()) {
            return false;
        }
        var canonicalText = canonicalizer.derive(text).securityText();
        if (canonicalText == null) {
            return false;
        }
        return markers.stream()
                .map(canonicalizer::derive)
                .map(SceneTextForms::securityText)
                .filter(java.util.Objects::nonNull)
                .anyMatch(canonicalText::contains);
    }

    public boolean containsMarker(String text, String marker) {
        var canonicalText = canonicalizer.derive(text).securityText();
        var canonicalMarker = canonicalizer.derive(marker).securityText();
        if (canonicalText == null || canonicalMarker == null) {
            return false;
        }
        var searchable = canonicalText;
        var needle = canonicalMarker;
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
