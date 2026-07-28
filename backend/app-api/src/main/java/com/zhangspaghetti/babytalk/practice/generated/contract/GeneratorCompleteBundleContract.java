package com.zhangspaghetti.babytalk.practice.generated.contract;

import java.util.Objects;

/** Typed generator boundary: request selects one supported schema and response is one complete bundle. */
public final class GeneratorCompleteBundleContract {

    private GeneratorCompleteBundleContract() {
    }

    public record Request(String requiredBundleSchemaVersion) {
        public Request {
            CompleteGeneratedBundle.requireSupportedSchemaVersion(requiredBundleSchemaVersion);
        }
    }

    public record Response(CompleteGeneratedBundle bundle) {
        public Response {
            Objects.requireNonNull(bundle, "bundle");
            CompleteGeneratedBundle.requireSupportedSchemaVersion(bundle.schemaVersion());
        }
    }
}
