package com.zhangspaghetti.babytalk.practice.discovery;

import com.ibm.icu.text.Normalizer2;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public final class SceneTextCanonicalizer {

    private static final Normalizer2 DISPLAY_NORMALIZER = Normalizer2.getNFKCInstance();
    private static final Normalizer2 SECURITY_NORMALIZER = Normalizer2.getNFKCCasefoldInstance();
    private static final Pattern WHITESPACE = Pattern.compile("[\\p{Z}\\s]+", Pattern.UNICODE_CHARACTER_CLASS);
    private static final Pattern GRAPHEME = Pattern.compile("\\X");
    private static final Set<Integer> BIDI_CONTROLS = Set.of(
            0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
            0x2066, 0x2067, 0x2068, 0x2069);
    private static final Set<Integer> REMOVABLE_INVISIBLES = Set.of(
            0x200B, 0x200C, 0x2060, 0xFEFF);

    public String canonicalize(String value) {
        return derive(value).displayText();
    }

    public SceneTextForms derive(String rawText) {
        if (rawText == null) {
            return new SceneTextForms(null, null, new SceneTextRiskSignals(false, false, false, false));
        }
        var scan = scan(rawText);
        var displayText = normalize(scan.cleanedText(), DISPLAY_NORMALIZER);
        var securityText = normalize(scan.cleanedText(), SECURITY_NORMALIZER);
        return new SceneTextForms(displayText, securityText, new SceneTextRiskSignals(
                scan.bidiControlPresent(), scan.removedInvisible(), scan.mixedDigitSystems(), scan.longDigitRun()));
    }

    private String normalize(String value, Normalizer2 normalizer) {
        var normalized = normalizePreservingZwj(value, normalizer);
        normalized = WHITESPACE.matcher(normalized).replaceAll(" ").trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private String normalizePreservingZwj(String value, Normalizer2 normalizer) {
        var normalized = new StringBuilder(value.length());
        var segmentStart = 0;
        for (var index = 0; index < value.length();) {
            var codePoint = value.codePointAt(index);
            if (codePoint == 0x200D) {
                normalized.append(normalizer.normalize(value.substring(segmentStart, index)));
                normalized.appendCodePoint(codePoint);
                segmentStart = index + Character.charCount(codePoint);
            }
            index += Character.charCount(codePoint);
        }
        normalized.append(normalizer.normalize(value.substring(segmentStart)));
        return normalized.toString();
    }

    private ScanResult scan(String rawText) {
        var cleaned = new StringBuilder(rawText.length());
        var bidiControlPresent = false;
        var removedInvisible = false;
        var digitRun = new DigitRun();
        var mixedDigitSystems = false;
        var longDigitRun = false;
        for (var index = 0; index < rawText.length();) {
            var codePoint = rawText.codePointAt(index);
            if (BIDI_CONTROLS.contains(codePoint)) {
                bidiControlPresent = true;
            }
            if (REMOVABLE_INVISIBLES.contains(codePoint)) {
                removedInvisible = true;
            } else {
                cleaned.appendCodePoint(codePoint);
            }
            if (Character.getType(codePoint) == Character.DECIMAL_DIGIT_NUMBER) {
                digitRun.add(codePoint);
            } else {
                mixedDigitSystems |= digitRun.mixedDigitSystems();
                longDigitRun |= digitRun.longDigitRun();
                digitRun = new DigitRun();
            }
            index += Character.charCount(codePoint);
        }
        return new ScanResult(cleaned.toString(), bidiControlPresent, removedInvisible,
                mixedDigitSystems || digitRun.mixedDigitSystems(), longDigitRun || digitRun.longDigitRun());
    }

    private record ScanResult(
            String cleanedText,
            boolean bidiControlPresent,
            boolean removedInvisible,
            boolean mixedDigitSystems,
            boolean longDigitRun
    ) {
    }

    private static final class DigitRun {

        private int length;
        private final Set<Character.UnicodeBlock> blocks = new HashSet<>();

        private void add(int codePoint) {
            length++;
            blocks.add(Character.UnicodeBlock.of(codePoint));
        }

        private boolean mixedDigitSystems() {
            return longDigitRun() && blocks.size() > 1;
        }

        private boolean longDigitRun() {
            return length >= 7;
        }
    }

    public int graphemeLength(String value) {
        if (value == null) {
            return 0;
        }
        if (value.isEmpty()) {
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
