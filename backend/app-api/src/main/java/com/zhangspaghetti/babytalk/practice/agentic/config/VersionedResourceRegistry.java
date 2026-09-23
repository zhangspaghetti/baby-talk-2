package com.zhangspaghetti.babytalk.practice.agentic.config;

import com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyProperties;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeMap;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.dataformat.yaml.YAMLFactory;

@Component
public class VersionedResourceRegistry {

    private static final String RESOURCE_PREFIX = "config/practice-ai/";
    private static final String DEFAULT_PROFILE = "classpath:config/practice-ai/profiles/custom-scene-generation-v7.yml";
    private static final String DEFAULT_VERSION_LOCK = "classpath:config/practice-ai/version-lock.yml";
    private static final String HEALTH_SAFETY_POLICY_VERSION = "health-safety-v1";
    private static final String HEALTH_SAFETY_POLICY_PATH = "config/practice-health-safety-v1.yml";
    private static final String VERSION_LOCK_SCHEMA = "practice-ai-version-lock-schema-v1";
    private static final String RUBRIC_SCHEMA = "judge-rubric-schema-v1";
    private static final String EVIDENCE_POLICY_SCHEMA = "evidence-policy-schema-v1";
    private static final String BASELINE_EVIDENCE_SCHEMA = "baseline-evidence-schema-v1";
    private static final List<String> REQUIRED_DIMENSIONS = List.of(
            "scene_alignment",
            "parent_speakability",
            "non_course_framing",
            "tpr_quality",
            "delivery_guidance_quality",
            "age_suitability",
            "bilingual_consistency",
            "low_pressure_support");
    private static final Set<String> REQUIRED_BASELINE_CLAIMS = Set.of(
            "parent_speakability", "age_guidance", "low_pressure_delivery");

    private final ResourceLoader resourceLoader;
    private final ObjectMapper yamlMapper = new ObjectMapper(new YAMLFactory());
    private final ObjectMapper canonicalMapper = new ObjectMapper();
    private final GenerationProfile generationProfile;
    private final QualityRubric qualityRubric;
    private final MinimumEvidencePolicy minimumEvidencePolicy;
    private final List<BaselineEvidenceDefinition> baselineEvidence;
    private final Map<PromptKind, String> prompts;
    private final Map<PromptKind, VersionedRef> promptRefs;
    private final String healthSafetyPolicyHash;

    public VersionedResourceRegistry(ResourceLoader resourceLoader) {
        this(resourceLoader, DEFAULT_PROFILE, CustomSceneSafetyProperties.defaults(), DEFAULT_VERSION_LOCK);
    }

    public VersionedResourceRegistry(ResourceLoader resourceLoader, String profilePath) {
        this(resourceLoader, profilePath, CustomSceneSafetyProperties.defaults(), DEFAULT_VERSION_LOCK);
    }

    @Autowired
    public VersionedResourceRegistry(
            ResourceLoader resourceLoader,
            @Value("${babytalk.practice.agentic.versioned-resources.profile:" + DEFAULT_PROFILE + "}") String profilePath,
            ObjectProvider<CustomSceneSafetyProperties> safetyPropertiesProvider,
            @Value("${babytalk.practice.agentic.versioned-resources.lock:" + DEFAULT_VERSION_LOCK + "}")
            String versionLockPath
    ) {
        this(
                resourceLoader,
                profilePath,
                safetyPropertiesProvider.getIfAvailable(CustomSceneSafetyProperties::defaults),
                versionLockPath);
    }

    public VersionedResourceRegistry(
            ResourceLoader resourceLoader,
            String profilePath,
            CustomSceneSafetyProperties safetyProperties
    ) {
        this(resourceLoader, profilePath, safetyProperties, DEFAULT_VERSION_LOCK);
    }

    public VersionedResourceRegistry(
            ResourceLoader resourceLoader,
            String profilePath,
            CustomSceneSafetyProperties safetyProperties,
            String versionLockPath
    ) {
        this.resourceLoader = Objects.requireNonNull(resourceLoader, "resourceLoader");
        Objects.requireNonNull(safetyProperties, "safetyProperties");
        Objects.requireNonNull(versionLockPath, "versionLockPath");
        var profileResource = requiredResource(profilePath);
        var profileDocument = yamlDocument(profileResource);
        var profileSchema = ProfileSchema.fromWireValue(
                string(profileDocument, "schema-version", "profile schema"));
        var profileVersion = string(profileDocument, "version", "profile");

        var generatorPrompt = promptRef(profileDocument, "generator-prompt");
        var judgePrompt = promptRef(profileDocument, "judge-prompt");
        var repairPrompt = promptRef(profileDocument, "repair-prompt");
        var classifierPrompt = classifierPromptRef(safetyProperties);
        verifyVersionLock(classifierPrompt, versionLockPath);
        var lockedHealthSafetyPolicyHash = verifyHealthSafetyPolicy(safetyProperties, versionLockPath);
        var rubricRef = yamlRef(profileDocument, "rubric");
        var evidencePolicyRef = yamlRef(profileDocument, "evidence-policy");
        var baselineEvidenceRef = yamlRef(profileDocument, "baseline-evidence");

        this.prompts = Map.of(
                PromptKind.GENERATOR, promptText(generatorPrompt),
                PromptKind.JUDGE, promptText(judgePrompt),
                PromptKind.REPAIR, promptText(repairPrompt),
                PromptKind.SAFETY_CLASSIFIER, promptText(classifierPrompt));
        this.promptRefs = Map.of(
                PromptKind.GENERATOR, generatorPrompt,
                PromptKind.JUDGE, judgePrompt,
                PromptKind.REPAIR, repairPrompt,
                PromptKind.SAFETY_CLASSIFIER, classifierPrompt);
        this.healthSafetyPolicyHash = lockedHealthSafetyPolicyHash;
        this.qualityRubric = readRubric(rubricRef);
        this.minimumEvidencePolicy = readEvidencePolicy(evidencePolicyRef);
        this.baselineEvidence = readBaselineEvidence(baselineEvidenceRef);
        this.generationProfile = new GenerationProfile(
                profileVersion,
                hashYaml(profileDocument),
                generatorPrompt,
                judgePrompt,
                repairPrompt,
                rubricRef,
                evidencePolicyRef,
                baselineEvidenceRef,
                string(profileDocument, "strategy-version", "profile"),
                string(profileDocument, "content-safety-policy-version", "profile"),
                string(profileDocument, "generated-output-schema-version", "profile"),
                positiveInteger(
                        profileDocument,
                        "minimum-complete-bundle-output-tokens",
                        "profile"),
                profileSchema.hasQualityJudgeOutputBudget()
                        ? positiveInteger(
                                profileDocument,
                                "minimum-quality-judge-output-tokens",
                                "profile")
                        : 0,
                profileSchema.hasRepairInferencePolicy()
                        ? inferencePolicy(profileDocument, "repair-inference-policy")
                        : null,
                profileSchema.hasGeneratorInferencePolicy()
                        ? inferencePolicy(profileDocument, "generator-inference-policy")
                        : null,
                profileSchema.hasQualityJudgeInferencePolicy()
                        ? inferencePolicy(profileDocument, "quality-judge-inference-policy")
                        : null);
    }

    public GenerationProfile currentGenerationProfile() {
        return generationProfile;
    }

    public QualityRubric qualityRubric() {
        return qualityRubric;
    }

    public MinimumEvidencePolicy minimumEvidencePolicy() {
        return minimumEvidencePolicy;
    }

    public List<BaselineEvidenceDefinition> baselineEvidence() {
        return baselineEvidence;
    }

    public String promptText(PromptKind kind) {
        var prompt = prompts.get(kind);
        if (prompt == null) {
            throw new IllegalArgumentException("unknown prompt kind");
        }
        return prompt;
    }

    public VersionedRef promptRef(PromptKind kind) {
        var prompt = promptRefs.get(kind);
        if (prompt == null) {
            throw new IllegalArgumentException("unknown prompt kind");
        }
        return prompt;
    }

    public String healthSafetyPolicyHash() {
        return healthSafetyPolicyHash;
    }

    private VersionedRef promptRef(Map<String, Object> profile, String key) {
        var ref = profileRef(profile, key);
        var fileVersion = filenameVersion(ref.resourcePath(), ".txt");
        requireEquals(ref.version(), fileVersion, "version mismatch for " + key);
        return ref;
    }

    private VersionedRef classifierPromptRef(CustomSceneSafetyProperties safetyProperties) {
        var declared = safetyProperties.classifierPrompt();
        if (declared == null
                || !declared.resourcePath().startsWith(RESOURCE_PREFIX)
                || !declared.resourcePath().endsWith(".txt")) {
            throw new IllegalStateException("version mismatch for classifier prompt");
        }
        var fileVersion = filenameVersion(declared.resourcePath(), ".txt");
        requireEquals(declared.version(), fileVersion, "version mismatch for classifier prompt");
        var content = normalizePrompt(resourceText(
                requiredResource("classpath:" + declared.resourcePath())));
        return new VersionedRef(
                declared.version(),
                hash(content.getBytes(StandardCharsets.UTF_8)),
                declared.resourcePath());
    }

    private void verifyVersionLock(VersionedRef ref, String versionLockPath) {
        var lock = yamlDocument(requiredResource(versionLockPath));
        requireEquals(
                VERSION_LOCK_SCHEMA,
                string(lock, "schema-version", "version lock schema"),
                "version lock schema");
        var matches = new ArrayList<Map<String, Object>>();
        for (var value : list(lock.get("resources"), "version lock resources")) {
            var entry = map(value, "version lock resource");
            if (ref.version().equals(entry.get("version"))
                    || ref.resourcePath().equals(entry.get("resource-path"))) {
                matches.add(entry);
            }
        }
        if (matches.size() != 1) {
            throw new IllegalStateException("missing or duplicate version lock for classifier prompt");
        }
        var entry = matches.get(0);
        requireLockEquals(ref.version(), string(entry, "version", "classifier prompt lock"), "version");
        requireLockEquals(
                ref.resourcePath(), string(entry, "resource-path", "classifier prompt lock"), "path");
        requireLockEquals(
                ref.contentHash(), string(entry, "content-hash", "classifier prompt lock"), "hash");
    }

    private String verifyHealthSafetyPolicy(
            CustomSceneSafetyProperties safetyProperties,
            String versionLockPath
    ) {
        if (!HEALTH_SAFETY_POLICY_VERSION.equals(safetyProperties.policyVersion())) {
            throw new IllegalStateException("health safety policy version mismatch");
        }
        var policyDocument = yamlDocument(requiredResource("classpath:" + HEALTH_SAFETY_POLICY_PATH));
        var babytalk = map(policyDocument.get("babytalk"), "health safety policy");
        var practice = map(babytalk.get("practice"), "health safety policy");
        var declared = map(practice.get("health-safety"), "health safety policy");
        requireEquals(
                HEALTH_SAFETY_POLICY_VERSION,
                string(declared, "policy-version", "health safety policy"),
                "health safety policy version mismatch");

        var lock = yamlDocument(requiredResource(versionLockPath));
        requireEquals(
                VERSION_LOCK_SCHEMA,
                string(lock, "schema-version", "version lock schema"),
                "version lock schema");
        var matches = new ArrayList<Map<String, Object>>();
        for (var value : list(lock.get("resources"), "version lock resources")) {
            var entry = map(value, "version lock resource");
            if (HEALTH_SAFETY_POLICY_VERSION.equals(entry.get("version"))
                    || HEALTH_SAFETY_POLICY_PATH.equals(entry.get("resource-path"))) {
                matches.add(entry);
            }
        }
        if (matches.size() != 1) {
            throw new IllegalStateException("missing or duplicate version lock for health safety policy");
        }
        var entry = matches.get(0);
        requireHealthSafetyLockEquals(
                HEALTH_SAFETY_POLICY_VERSION,
                string(entry, "version", "health safety policy lock"),
                "health safety policy version");
        requireHealthSafetyLockEquals(
                HEALTH_SAFETY_POLICY_PATH,
                string(entry, "resource-path", "health safety policy lock"),
                "health safety policy path");
        var expectedHash = string(entry, "content-hash", "health safety policy lock");
        if (!expectedHash.matches("[0-9a-f]{64}")) {
            throw new IllegalStateException("health safety policy lock hash is invalid");
        }
        requireHealthSafetyLockEquals(
                safetyProperties.lockedContentHash(),
                expectedHash,
                "hash");
        requireHealthSafetyLockEquals(
                safetyProperties.contentHash(),
                expectedHash,
                "hash");
        return expectedHash;
    }

    private VersionedRef yamlRef(Map<String, Object> profile, String key) {
        var ref = profileRef(profile, key);
        if (!ref.resourcePath().endsWith(".yml")) {
            throw new IllegalStateException("version mismatch for " + key);
        }
        return ref;
    }

    private VersionedRef profileRef(Map<String, Object> profile, String key) {
        var ref = map(profile.get(key), "profile " + key);
        var version = string(ref, "version", "profile " + key);
        var resourcePath = string(ref, "resource-path", "profile " + key);
        if (!resourcePath.startsWith(RESOURCE_PREFIX)) {
            throw new IllegalStateException("version mismatch for " + key);
        }
        if (resourcePath.endsWith(".yml")) {
            var document = yamlDocument(requiredResource("classpath:" + resourcePath));
            requireEquals(version, string(document, "version", resourcePath), "version mismatch for " + key);
            return new VersionedRef(version, hashYaml(document), resourcePath);
        }
        if (resourcePath.endsWith(".txt")) {
            return new VersionedRef(version, hash(normalizePrompt(resourceText(requiredResource("classpath:" + resourcePath)))
                    .getBytes(StandardCharsets.UTF_8)), resourcePath);
        }
        throw new IllegalStateException("version mismatch for " + key);
    }

    private String promptText(VersionedRef prompt) {
        var content = resourceText(requiredResource("classpath:" + prompt.resourcePath()));
        return normalizePrompt(content);
    }

    private QualityRubric readRubric(VersionedRef ref) {
        var document = yamlDocument(requiredResource("classpath:" + ref.resourcePath()));
        requireEquals(RUBRIC_SCHEMA, string(document, "schema-version", "rubric schema"), "rubric schema");
        var dimensions = strings(document.get("dimensions"), "rubric schema dimensions");
        if (dimensions.size() != REQUIRED_DIMENSIONS.size()
                || new LinkedHashSet<>(dimensions).size() != dimensions.size()
                || !new LinkedHashSet<>(dimensions).equals(new LinkedHashSet<>(REQUIRED_DIMENSIONS))) {
            throw new IllegalStateException("rubric schema dimensions are invalid");
        }
        var verdictPolicy = map(document.get("verdict-policy"), "rubric schema verdict-policy");
        var allowedPolicyKeys = Set.of("reject-on-fail", "repair-on-fail", "repair-on-abstain");
        if (!allowedPolicyKeys.equals(verdictPolicy.keySet())) {
            throw new IllegalStateException("rubric schema verdict policy keys are invalid");
        }
        var rejectOnFail = linkedSet(verdictPolicy.get("reject-on-fail"), "rubric schema reject-on-fail");
        var repairOnFail = linkedSet(verdictPolicy.get("repair-on-fail"), "rubric schema repair-on-fail");
        if (!dimensions.containsAll(rejectOnFail) || !dimensions.containsAll(repairOnFail)
                || !Set.of("age_suitability").equals(rejectOnFail)
                || repairOnFail.contains("age_suitability")
                || !repairOnFail.equals(new LinkedHashSet<>(REQUIRED_DIMENSIONS).stream()
                        .filter(dimension -> !rejectOnFail.contains(dimension))
                        .collect(java.util.stream.Collectors.toCollection(LinkedHashSet::new)))) {
            throw new IllegalStateException("rubric schema verdict mapping is invalid");
        }
        var repairOnAbstain = verdictPolicy.get("repair-on-abstain");
        if (!(repairOnAbstain instanceof Boolean value) || !value) {
            throw new IllegalStateException("rubric schema repair-on-abstain is invalid");
        }
        return new QualityRubric(ref.version(), ref.contentHash(), dimensions, rejectOnFail, repairOnFail, true);
    }

    private MinimumEvidencePolicy readEvidencePolicy(VersionedRef ref) {
        var document = yamlDocument(requiredResource("classpath:" + ref.resourcePath()));
        requireEquals(EVIDENCE_POLICY_SCHEMA, string(document, "schema-version", "evidence policy schema"), "evidence policy schema");
        var confidence = number(document.get("minimum-confidence"), "evidence policy minimum-confidence");
        if (confidence < 0.0d || confidence > 1.0d) {
            throw new IllegalStateException("evidence policy minimum-confidence is invalid");
        }
        var claims = strings(document.get("required-claim-coverage"), "evidence policy required-claim-coverage");
        var sources = strings(document.get("trusted-source-types"), "evidence policy trusted-source-types");
        if (claims.isEmpty() || sources.isEmpty() || hasDuplicates(claims) || hasDuplicates(sources)) {
            throw new IllegalStateException("evidence policy schema is invalid");
        }
        return new MinimumEvidencePolicy(ref.version(), ref.contentHash(), confidence, claims, sources);
    }

    private List<BaselineEvidenceDefinition> readBaselineEvidence(VersionedRef ref) {
        var document = yamlDocument(requiredResource("classpath:" + ref.resourcePath()));
        requireEquals(BASELINE_EVIDENCE_SCHEMA, string(document, "schema-version", "baseline evidence schema"), "baseline evidence schema");
        var evidence = list(document.get("evidence"), "baseline evidence");
        var ids = new LinkedHashSet<String>();
        var claimTypes = new LinkedHashSet<String>();
        var definitions = new ArrayList<BaselineEvidenceDefinition>();
        for (Object item : evidence) {
            var record = map(item, "baseline evidence item");
            var id = string(record, "evidence-id", "baseline evidence item");
            if (!ids.add(id)
                    || !ref.version().equals(string(record, "source-version", "baseline evidence item"))
                    || !"REFERENCE".equals(string(record, "evidence-kind", "baseline evidence item"))
                    || string(record, "strategy-id", "baseline evidence item").isBlank()) {
                throw new IllegalStateException("baseline evidence schema is invalid");
            }
            var summary = string(record, "summary", "baseline evidence item");
            if (summary.length() > 280 || summary.contains("\n") || summary.contains("\r")) {
                throw new IllegalStateException("baseline evidence summary is invalid");
            }
            var confidence = number(record.get("confidence"), "baseline evidence confidence");
            if (confidence < 0.0d || confidence > 1.0d) {
                throw new IllegalStateException("baseline evidence confidence is invalid");
            }
            var claimType = string(record, "claim-type", "baseline evidence item");
            claimTypes.add(claimType);
            definitions.add(new BaselineEvidenceDefinition(
                    id,
                    string(record, "source-version", "baseline evidence item"),
                    string(record, "strategy-id", "baseline evidence item"),
                    claimType,
                    summary,
                    confidence));
        }
        if (!claimTypes.equals(REQUIRED_BASELINE_CLAIMS)) {
            throw new IllegalStateException("baseline evidence claims are invalid");
        }
        return List.copyOf(definitions);
    }

    private Map<String, Object> yamlDocument(Resource resource) {
        try (InputStream input = resource.getInputStream()) {
            return map(yamlMapper.readValue(input, Map.class), resource.getDescription());
        } catch (IOException exception) {
            throw new IllegalStateException("unable to load versioned resource " + resource.getDescription(), exception);
        }
    }

    private String resourceText(Resource resource) {
        try (InputStream input = resource.getInputStream()) {
            return new String(input.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException exception) {
            throw new IllegalStateException("unable to load versioned resource " + resource.getDescription(), exception);
        }
    }

    private Resource requiredResource(String location) {
        var resource = resourceLoader.getResource(location);
        if (!resource.exists()) {
            throw new IllegalStateException("missing versioned resource " + location);
        }
        return resource;
    }

    private String hashYaml(Map<String, Object> document) {
        return hash(canonicalMapper.writeValueAsBytes(canonical(document)));
    }

    private static Object canonical(Object value) {
        if (value instanceof Map<?, ?> map) {
            var sorted = new TreeMap<String, Object>();
            map.forEach((key, item) -> sorted.put(String.valueOf(key), canonical(item)));
            return sorted;
        }
        if (value instanceof List<?> list) {
            return list.stream().map(VersionedResourceRegistry::canonical).toList();
        }
        return value;
    }

    private static String normalizePrompt(String prompt) {
        var normalized = prompt.replace("\r\n", "\n").replace('\r', '\n');
        return normalized.endsWith("\n") ? normalized.substring(0, normalized.length() - 1) : normalized;
    }

    private static String hash(byte[] bytes) {
        try {
            var digest = MessageDigest.getInstance("SHA-256").digest(bytes);
            var hex = new StringBuilder(digest.length * 2);
            for (byte value : digest) {
                hex.append(String.format("%02x", value));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    private static String filenameVersion(String resourcePath, String suffix) {
        var name = resourcePath.substring(resourcePath.lastIndexOf('/') + 1);
        return name.endsWith(suffix) ? name.substring(0, name.length() - suffix.length()) : "";
    }

    private static void requireEquals(String expected, String actual, String context) {
        if (!expected.equals(actual)) {
            throw new IllegalStateException(context + " version mismatch");
        }
    }

    private static void requireLockEquals(String expected, String actual, String field) {
        if (!expected.equals(actual)) {
            throw new IllegalStateException("classifier prompt lock " + field + " mismatch");
        }
    }

    private static void requireHealthSafetyLockEquals(String expected, String actual, String field) {
        if (!expected.equals(actual)) {
            throw new IllegalStateException("health safety policy lock " + field + " mismatch");
        }
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> map(Object value, String context) {
        if (!(value instanceof Map<?, ?> map)) {
            throw new IllegalStateException(context + " must be a mapping");
        }
        var result = new LinkedHashMap<String, Object>();
        map.forEach((key, item) -> result.put(String.valueOf(key), item));
        return result;
    }

    private static List<Object> list(Object value, String context) {
        if (!(value instanceof List<?> list)) {
            throw new IllegalStateException(context + " must be a list");
        }
        return new ArrayList<>(list);
    }

    private static List<String> strings(Object value, String context) {
        return list(value, context).stream().map(item -> {
            if (!(item instanceof String string) || string.isBlank()) {
                throw new IllegalStateException(context + " must contain non-blank strings");
            }
            return string;
        }).toList();
    }

    private static Set<String> linkedSet(Object value, String context) {
        var items = strings(value, context);
        var result = new LinkedHashSet<>(items);
        if (result.size() != items.size()) {
            throw new IllegalStateException(context + " contains duplicates");
        }
        return result;
    }

    private static boolean hasDuplicates(List<String> values) {
        return new LinkedHashSet<>(values).size() != values.size();
    }

    private static String string(Map<String, Object> document, String key, String context) {
        var value = document.get(key);
        if (!(value instanceof String string) || string.isBlank()) {
            throw new IllegalStateException(context + " requires " + key);
        }
        return string;
    }

    private static double number(Object value, String context) {
        if (!(value instanceof Number number)) {
            throw new IllegalStateException(context + " must be numeric");
        }
        return number.doubleValue();
    }

    private GenerationProfile.InferencePolicy inferencePolicy(
            Map<String, Object> profile,
            String policyKey
    ) {
        var context = "profile " + policyKey;
        var policy = map(profile.get(policyKey), context);
        if (!Set.of("provider-type", "model-names", "reasoning-effort").equals(policy.keySet())) {
            throw new IllegalStateException(context + " keys are invalid");
        }
        var providerType = string(policy, "provider-type", context);
        var modelNames = strings(policy.get("model-names"), context + " model-names");
        if (modelNames.isEmpty() || modelNames.size() > 8 || hasDuplicates(modelNames)) {
            throw new IllegalStateException(context + " model-names are invalid");
        }
        var reasoningEffort = string(policy, "reasoning-effort", context);
        PracticeAiReasoningEffort typedReasoningEffort;
        try {
            typedReasoningEffort = PracticeAiReasoningEffort.fromWireValue(reasoningEffort);
        } catch (IllegalArgumentException exception) {
            throw new IllegalStateException(context + " reasoning-effort is invalid");
        }
        return new GenerationProfile.InferencePolicy(providerType, modelNames, typedReasoningEffort);
    }

    private static int positiveInteger(Map<String, Object> document, String key, String context) {
        var value = document.get(key);
        if (!(value instanceof Number number)
                || number.longValue() <= 0
                || number.longValue() > Integer.MAX_VALUE
                || number.doubleValue() != number.longValue()) {
            throw new IllegalStateException(context + " requires a positive integer " + key);
        }
        return number.intValue();
    }

    public enum PromptKind {
        GENERATOR,
        JUDGE,
        REPAIR,
        SAFETY_CLASSIFIER
    }

    private enum ProfileSchema {
        V1("generation-profile-schema-v1", false, false, false, false),
        V2("generation-profile-schema-v2", true, false, false, false),
        V3("generation-profile-schema-v3", true, true, false, false),
        V4("generation-profile-schema-v4", true, true, true, false),
        V5("generation-profile-schema-v5", true, true, true, true);

        private final String wireValue;
        private final boolean qualityJudgeOutputBudget;
        private final boolean repairInferencePolicy;
        private final boolean generatorInferencePolicy;
        private final boolean qualityJudgeInferencePolicy;

        ProfileSchema(
                String wireValue,
                boolean qualityJudgeOutputBudget,
                boolean repairInferencePolicy,
                boolean generatorInferencePolicy,
                boolean qualityJudgeInferencePolicy
        ) {
            this.wireValue = wireValue;
            this.qualityJudgeOutputBudget = qualityJudgeOutputBudget;
            this.repairInferencePolicy = repairInferencePolicy;
            this.generatorInferencePolicy = generatorInferencePolicy;
            this.qualityJudgeInferencePolicy = qualityJudgeInferencePolicy;
        }

        private static ProfileSchema fromWireValue(String wireValue) {
            return java.util.Arrays.stream(values())
                    .filter(schema -> schema.wireValue.equals(wireValue))
                    .findFirst()
                    .orElseThrow(() -> new IllegalStateException("profile schema version mismatch"));
        }

        private boolean hasQualityJudgeOutputBudget() {
            return qualityJudgeOutputBudget;
        }

        private boolean hasRepairInferencePolicy() {
            return repairInferencePolicy;
        }

        private boolean hasGeneratorInferencePolicy() {
            return generatorInferencePolicy;
        }

        private boolean hasQualityJudgeInferencePolicy() {
            return qualityJudgeInferencePolicy;
        }
    }

    public record BaselineEvidenceDefinition(
            String evidenceId,
            String sourceVersion,
            String strategyId,
            String claimType,
            String summary,
            double confidence
    ) {
    }
}
