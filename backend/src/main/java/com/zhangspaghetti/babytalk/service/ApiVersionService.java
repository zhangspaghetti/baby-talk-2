package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.BabyTalkPayloads;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class ApiVersionService {

    private final String currentVersion;
    private final String minSupportedVersion;

    public ApiVersionService(
            @Value("${app.api.current-version}") String currentVersion,
            @Value("${app.api.min-supported-version}") String minSupportedVersion
    ) {
        this.currentVersion = normalizeVersion(currentVersion);
        this.minSupportedVersion = normalizeVersion(minSupportedVersion);
    }

    public String currentVersion() {
        return currentVersion;
    }

    public String minSupportedVersion() {
        return minSupportedVersion;
    }

    public boolean isSupported(String requestedVersion) {
        if (requestedVersion == null || requestedVersion.isBlank()) {
            return false;
        }

        return compareVersions(requestedVersion, minSupportedVersion) >= 0;
    }

    public BabyTalkPayloads.ApiVersionResponse versionStatus(String requestedVersion) {
        String normalizedRequestedVersion = normalizeNullableVersion(requestedVersion);
        boolean upgradeRequired = normalizedRequestedVersion != null && !isSupported(normalizedRequestedVersion);

        return new BabyTalkPayloads.ApiVersionResponse(
                currentVersion,
                minSupportedVersion,
                normalizedRequestedVersion,
                upgradeRequired,
                upgradeRequired ? unsupportedMessage(normalizedRequestedVersion) : "当前版本可继续使用。"
        );
    }

    public BabyTalkPayloads.ApiVersionResponse upgradeRequiredResponse(String requestedVersion) {
        String normalizedRequestedVersion = normalizeNullableVersion(requestedVersion);

        return new BabyTalkPayloads.ApiVersionResponse(
                currentVersion,
                minSupportedVersion,
                normalizedRequestedVersion,
                true,
                unsupportedMessage(normalizedRequestedVersion)
        );
    }

    private String unsupportedMessage(String requestedVersion) {
        if (requestedVersion == null) {
            return "缺少 X-App-Version 请求头，请升级客户端后重试。";
        }

        return "当前 App 版本 " + requestedVersion + " 过旧，请升级到 " + minSupportedVersion + " 或更高版本。";
    }

    private int compareVersions(String left, String right) {
        List<Integer> leftParts = parseVersion(left);
        List<Integer> rightParts = parseVersion(right);
        int length = Math.max(leftParts.size(), rightParts.size());

        for (int index = 0; index < length; index += 1) {
            int leftPart = index < leftParts.size() ? leftParts.get(index) : 0;
            int rightPart = index < rightParts.size() ? rightParts.get(index) : 0;
            if (leftPart != rightPart) {
                return Integer.compare(leftPart, rightPart);
            }
        }

        return 0;
    }

    private List<Integer> parseVersion(String value) {
        String normalized = normalizeVersion(value);
        String[] tokens = normalized.split("\\.");
        List<Integer> parts = new ArrayList<>();

        for (String token : tokens) {
            parts.add(Integer.parseInt(token));
        }

        return parts;
    }

    private String normalizeVersion(String value) {
        if (value == null || value.isBlank()) {
            return "0.0.0";
        }

        String trimmed = value.trim();
        int buildSeparator = trimmed.indexOf('+');
        if (buildSeparator >= 0) {
            trimmed = trimmed.substring(0, buildSeparator);
        }

        int preReleaseSeparator = trimmed.indexOf('-');
        if (preReleaseSeparator >= 0) {
            trimmed = trimmed.substring(0, preReleaseSeparator);
        }

        String[] rawTokens = trimmed.split("\\.");
        List<String> normalizedTokens = new ArrayList<>();

        for (String rawToken : rawTokens) {
            String digitsOnly = rawToken.replaceAll("[^0-9]", "");
            normalizedTokens.add(digitsOnly.isEmpty() ? "0" : digitsOnly);
        }

        while (normalizedTokens.size() < 3) {
            normalizedTokens.add("0");
        }

        return String.join(".", normalizedTokens);
    }

    private String normalizeNullableVersion(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }

        return normalizeVersion(value);
    }
}