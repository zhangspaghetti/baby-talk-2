package com.zhangspaghetti.babytalk.config;

import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ApiVersionService {

    public boolean isSupported(String providedVersion, String minimumSupportedVersion) {
        return compareVersions(providedVersion, minimumSupportedVersion) >= 0;
    }

    public int compareVersions(String left, String right) {
        var leftParts = parseVersion(left);
        var rightParts = parseVersion(right);
        var size = Math.max(leftParts.size(), rightParts.size());
        for (var index = 0; index < size; index++) {
            var leftValue = index < leftParts.size() ? leftParts.get(index) : 0;
            var rightValue = index < rightParts.size() ? rightParts.get(index) : 0;
            if (leftValue != rightValue) {
                return Integer.compare(leftValue, rightValue);
            }
        }
        return 0;
    }

    public List<Integer> parseVersion(String version) {
        if (version == null || version.isBlank()) {
            throw new IllegalArgumentException("X-App-Version 不能为空。");
        }
        var parts = version.trim().split("\\.");
        var parsed = new ArrayList<Integer>(parts.length);
        for (var part : parts) {
            if (!part.matches("\\d+")) {
                throw new IllegalArgumentException("X-App-Version 必须是数字点分版本，例如 1.2.0。");
            }
            parsed.add(Integer.parseInt(part));
        }
        return parsed;
    }
}
