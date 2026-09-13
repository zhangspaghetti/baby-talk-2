package com.zhangspaghetti.babytalk.practice.discovery.safety;

import com.zhangspaghetti.babytalk.practice.discovery.SceneTextForms;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Objects;

/** Result of the safety gate. Only generated results carry an admission. */
public final class CustomSceneSafetyDecision {

    private static final String HEALTH_SAFETY_POLICY_VERSION = "health-safety-v1";
    private static final String DEFAULT_LOCALE = "zh-CN";
    private static final String OWNER_CONTEXT_PLACEHOLDER = "<owner-context-unbound>";
    private static final String PROFILE_CONTEXT_PLACEHOLDER = "<profile-context-unbound>";

    private final ResultType resultType;
    private final CustomSceneSafetyAssessment assessment;
    private final CustomSceneSafetyProperties.Template template;
    private final Admission admission;

    private CustomSceneSafetyDecision(
            ResultType resultType,
            CustomSceneSafetyAssessment assessment,
            CustomSceneSafetyProperties.Template template,
            Admission admission
    ) {
        this.resultType = Objects.requireNonNull(resultType, "resultType");
        this.assessment = assessment;
        this.template = template;
        this.admission = admission;
        if (resultType == ResultType.GENERATED_SCENE && admission == null) {
            throw new IllegalArgumentException("generated scene decision requires admission");
        }
        if (resultType != ResultType.GENERATED_SCENE && admission != null) {
            throw new IllegalArgumentException("only generated scene decision may carry admission");
        }
    }

    public static CustomSceneSafetyDecision generatedScene(Admission admission) {
        return new CustomSceneSafetyDecision(ResultType.GENERATED_SCENE, null, null,
                Objects.requireNonNull(admission, "admission"));
    }

    public static CustomSceneSafetyDecision generated(Admission admission) {
        return generatedScene(admission);
    }

    public static CustomSceneSafetyDecision health(CustomSceneSafetyAssessment assessment) {
        return new CustomSceneSafetyDecision(
                ResultType.HEALTH_SAFETY,
                Objects.requireNonNull(assessment, "assessment"),
                null,
                null);
    }

    public static CustomSceneSafetyDecision health(
            CustomSceneSafetyAssessment assessment,
            CustomSceneSafetyProperties.Template template
    ) {
        return new CustomSceneSafetyDecision(
                ResultType.HEALTH_SAFETY,
                Objects.requireNonNull(assessment, "assessment"),
                Objects.requireNonNull(template, "template"),
                null);
    }

    public static CustomSceneSafetyDecision assessmentUnavailable(
            CustomSceneSafetyProperties.Template template
    ) {
        Objects.requireNonNull(template, "template");
        return assessmentUnavailable(new CustomSceneSafetyAssessment(
                CustomSceneSafetyAssessment.Intent.UNCERTAIN,
                CustomSceneSafetyAssessment.Action.UNCERTAIN,
                "health-assessment-unavailable-v1",
                HEALTH_SAFETY_POLICY_VERSION), template);
    }

    public static CustomSceneSafetyDecision assessmentUnavailable(
            CustomSceneSafetyAssessment assessment
    ) {
        return assessmentUnavailable(assessment, null);
    }

    public static CustomSceneSafetyDecision assessmentUnavailable(
            CustomSceneSafetyAssessment assessment,
            CustomSceneSafetyProperties.Template template
    ) {
        return new CustomSceneSafetyDecision(
                ResultType.ASSESSMENT_UNAVAILABLE,
                Objects.requireNonNull(assessment, "assessment"),
                template,
                null);
    }

    public ResultType resultType() {
        return resultType;
    }

    public CustomSceneSafetyAssessment assessment() {
        return assessment;
    }

    public CustomSceneSafetyProperties.Template template() {
        return template;
    }

    public Admission admission() {
        return admission;
    }

    @Override
    public String toString() {
        return "CustomSceneSafetyDecision[resultType=" + resultType
                + ", assessment=" + assessment
                + ", admission=" + (admission == null ? "absent" : "opaque") + "]";
    }


    public enum ResultType {
        GENERATED_SCENE,
        HEALTH_SAFETY,
        ASSESSMENT_UNAVAILABLE
    }

    /**
     * Opaque server-created token. Its constructor and digest are private so callers can only
     * transport a token issued by this package's safety policy.
     */
    public static final class Admission {

        private final String digest;
        private final boolean contextBound;

        private Admission(String digest, boolean contextBound) {
            this.digest = Objects.requireNonNull(digest, "digest");
            this.contextBound = contextBound;
        }

        static Admission forPolicy(
                SceneTextForms forms,
                String ageRange,
                String locale,
                String ownerContext,
                String profileContext,
                String policyVersion
        ) {
            var securityText = securityText(forms);
            return new Admission(digest(
                    securityText,
                    ageRange,
                    locale,
                    ownerContext,
                    profileContext,
                    policyVersion), false);
        }

        /**
         * Binds this policy admission to server-resolved owner and profile context. The original
         * placeholder token stays unbound and cannot be used as a context-bound token.
         */
        public Admission bindContext(String ownerScope, String ownerKey, String profileId) {
            if (contextBound) {
                throw new IllegalStateException("admission context already bound");
            }
            var normalizedOwnerScope = requiredContext(ownerScope, "owner scope");
            var normalizedOwnerKey = requiredContext(ownerKey, "owner key");
            var normalizedProfileId = optionalContext(profileId);
            return new Admission(boundDigest(
                    digest, normalizedOwnerScope, normalizedOwnerKey, normalizedProfileId), true);
        }

        /**
         * Validates a token against all admission inputs without exposing its digest or retaining
         * source text. Task 4 can use this method when binding the token to an owner and profile.
         */
        public boolean matches(
                String securityText,
                String ageRange,
                String locale,
                String ownerContext,
                String profileContext,
                String policyVersion
        ) {
            if (securityText == null || securityText.isBlank()) {
                return false;
            }
            return MessageDigest.isEqual(
                    digest.getBytes(StandardCharsets.US_ASCII),
                    digest(securityText, ageRange, locale, ownerContext, profileContext, policyVersion)
                            .getBytes(StandardCharsets.US_ASCII));
        }

        /** Validates a context-bound token against server-resolved owner and profile values. */
        public boolean matches(
                String securityText,
                String ageRange,
                String locale,
                String ownerScope,
                String ownerKey,
                String profileId,
                String policyVersion
        ) {
            if (!contextBound || securityText == null || securityText.isBlank()) {
                return false;
            }
            var expectedBase = digest(
                    securityText,
                    ageRange,
                    locale,
                    OWNER_CONTEXT_PLACEHOLDER,
                    PROFILE_CONTEXT_PLACEHOLDER,
                    policyVersion);
            final String expected;
            try {
                expected = boundDigest(
                        expectedBase,
                        requiredContext(ownerScope, "owner scope"),
                        requiredContext(ownerKey, "owner key"),
                        optionalContext(profileId));
            } catch (RuntimeException failure) {
                return false;
            }
            return MessageDigest.isEqual(
                    digest.getBytes(StandardCharsets.US_ASCII),
                    expected.getBytes(StandardCharsets.US_ASCII));
        }

        @Override
        public String toString() {
            return "Admission[opaque=true]";
        }

        @Override
        public boolean equals(Object other) {
            return other instanceof Admission candidate && digest.equals(candidate.digest);
        }

        @Override
        public int hashCode() {
            return digest.hashCode();
        }

        private static String securityText(SceneTextForms forms) {
            if (forms == null) {
                return "";
            }
            var securityText = forms.securityText();
            if (securityText != null && !securityText.isBlank()) {
                return securityText;
            }
            return forms.displayText() == null ? "" : forms.displayText();
        }

        private static String digest(
                String securityText,
                String ageRange,
                String locale,
                String ownerContext,
                String profileContext,
                String policyVersion
        ) {
            var material = lengthPrefix(securityText)
                    + lengthPrefix(ageRange)
                    + lengthPrefix(locale)
                    + lengthPrefix(ownerContext)
                    + lengthPrefix(profileContext)
                    + lengthPrefix(policyVersion);
            try {
                return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                        .digest(material.getBytes(StandardCharsets.UTF_8)));
            } catch (NoSuchAlgorithmException exception) {
                throw new IllegalStateException("SHA-256 digest unavailable");
            }
        }

        private static String boundDigest(
                String baseDigest,
                String ownerScope,
                String ownerKey,
                String profileId
        ) {
            return digest(
                    baseDigest,
                    ownerScope,
                    ownerKey,
                    profileId,
                    HEALTH_SAFETY_POLICY_VERSION,
                    "admission-context-v1");
        }

        private static String requiredContext(String value, String field) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException("admission " + field + " must not be blank");
            }
            return value.trim();
        }

        private static String optionalContext(String value) {
            return value == null ? "" : value.trim();
        }

        private static String lengthPrefix(String value) {
            var safe = value == null ? "" : value;
            return safe.length() + ":" + safe;
        }
    }

    /** Issues an unbound admission for the server safety policy to bind to its resolved owner. */
    public static Admission bindAdmission(SceneTextForms forms, String ageRange, String policyVersion) {
        return Admission.forPolicy(
                forms,
                ageRange,
                DEFAULT_LOCALE,
                OWNER_CONTEXT_PLACEHOLDER,
                PROFILE_CONTEXT_PLACEHOLDER,
                policyVersion);
    }

    static String ownerContextPlaceholder() {
        return OWNER_CONTEXT_PLACEHOLDER;
    }

    static String profileContextPlaceholder() {
        return PROFILE_CONTEXT_PLACEHOLDER;
    }
}
