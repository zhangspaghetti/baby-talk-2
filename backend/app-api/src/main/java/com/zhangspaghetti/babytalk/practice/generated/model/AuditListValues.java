package com.zhangspaghetti.babytalk.practice.generated.model;

import java.util.Collection;
import java.util.List;
import java.util.Objects;
import java.util.TreeSet;

final class AuditListValues {

    private AuditListValues() {
    }

    static List<String> sortedDistinct(Collection<String> values) {
        if (values == null || values.isEmpty()) {
            return List.of();
        }
        var sorted = new TreeSet<String>();
        values.stream().filter(Objects::nonNull).forEach(sorted::add);
        return List.copyOf(sorted);
    }
}
