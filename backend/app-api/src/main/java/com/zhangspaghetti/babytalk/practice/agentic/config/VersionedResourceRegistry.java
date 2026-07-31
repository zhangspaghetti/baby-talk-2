package com.zhangspaghetti.babytalk.practice.agentic.config;

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
    private static final String DEFAULT_PROFILE = "classpath:config/practice-ai/profiles/custom-scene-generation-v1.yml";
    private static final String PROFILE_SCHEMA = "generation-profile-schema-v1";
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

    public VersionedResourceRegistry(ResourceLoader resourceLoader) {
        this(resourceLoader, DEFAULT_PROFILE);
    }

    @Autowired
    public VersionedResourceRegistry(
            ResourceLoader resourceLoader,
            @Value("${babytalk.practice.agentic.versioned-resources.profile:" + DEFAULT_PROFILE + "}") String profilePath
    ) {
        this.resourceLoader = Objects.requireNonNull(resourceLoader, "resourceLoader");
        var profileResource = requiredResource(profilePath);
        var profileDocument = yamlDocument(profileResource);
        requireEquals(PROFILE_SCHEMA, string(profileDocument, "schema-version", "profile schema"), "profile schema");
        var profileVersion = string(profileDocument, "version", "profile");

        var generatorPrompt = promptRef(profileDocument, "generator-prompt");
        var judgePrompt = promptRef(profileDocument, "judge-prompt");
        var repairPrompt = promptRef(profileDocument, "repair-prompt");
        var rubricRef = yamlRef(profileDocument, "rubric");
        var evidencePolicyRef = yamlRef(profileDocument, "evidence-policy");
        var baselineEvidenceRef = yamlRef(profileDocument, "baseline-evidence");

        this.prompts = Map.of(
                PromptKind.GENERATOR, promptText(generatorPrompt),
                PromptKind.JUDGE, promptText(judgePrompt),
                PromptKind.REPAIR, promptText(repairPrompt));
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
                        "profile"));
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

    private VersionedRef promptRef(Map<String, Object> profile, String key) {
        var ref = profileRef(profile, key);
        var fileVersion = filenameVersion(ref.resourcePath(), ".txt");
        requireEquals(ref.version(), fileVersion, "version mismatch for " + key);
        return ref;
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
        REPAIR
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
