package com.zhangspaghetti.babytalk.practice.generated.contract;

import java.util.Objects;

/** Typed repair boundary: repair consumes and returns one complete bundle under one schema. */
public final class RepairCompleteBundleContract {

    private RepairCompleteBundleContract() {
    }

    public record Request(String requiredBundleSchemaVersion, CompleteGeneratedBundle previousBundle) {
        public Request {
            CompleteGeneratedBundle.requireSupportedSchemaVersion(requiredBundleSchemaVersion);
            Objects.requireNonNull(previousBundle, "previousBundle");
            if (!requiredBundleSchemaVersion.equals(previousBundle.schemaVersion())) {
                throw new IllegalArgumentException("repair bundle schema version must match request schema version");
            }
        }
    }

    public record Response(CompleteGeneratedBundle bundle) {
        public Response {
            Objects.requireNonNull(bundle, "bundle");
            CompleteGeneratedBundle.requireSupportedSchemaVersion(bundle.schemaVersion());
        }
    }
}
