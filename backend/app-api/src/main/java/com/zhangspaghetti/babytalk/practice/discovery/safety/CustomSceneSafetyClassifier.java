package com.zhangspaghetti.babytalk.practice.discovery.safety;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Semantic classifier port used after deterministic emergency rules. */
@FunctionalInterface
public interface CustomSceneSafetyClassifier {

    SemanticResult classify(ClassifierRequest request);

    record ClassifierRequest(
            String displayText,
            String ageRange,
            String locale,
            String policyVersion
    ) {

        @Override
        public String toString() {
            return "ClassifierRequest[displayTextPresent=" + (displayText != null && !displayText.isBlank())
                    + ", ageRangePresent=" + (ageRange != null && !ageRange.isBlank())
                    + ", locale=" + locale
                    + ", policyVersion=" + policyVersion + "]";
        }
    }

    record SemanticResult(
            CustomSceneSafetyAssessment.Intent intent,
            List<Signal> signals
    ) {

        public SemanticResult {
            signals = signals == null
                    ? null
                    : Collections.unmodifiableList(new ArrayList<>(signals));
        }
    }

    enum Signal {
        HEALTH_CONCERN,
        PROMPT_ASSESSMENT,
        AMBIGUOUS_CONCERN,
        RECOVERED,
        FICTIONAL
    }

    /** Failure marker deliberately carries no provider or user payload. */
    final class UnavailableException extends RuntimeException {

        public UnavailableException() {
            super("custom scene safety classifier unavailable");
        }

        public UnavailableException(Throwable cause) {
            super("custom scene safety classifier unavailable");
        }
    }
}
