package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;

public record DraftReservation(
        PracticeGeneratedContentEntity content,
        boolean created
) {
    /** Compatibility aliases for callers migrating to the command port. */
    public PracticeGeneratedContentEntity row() {
        return content;
    }

    public boolean inserted() {
        return created;
    }
}
