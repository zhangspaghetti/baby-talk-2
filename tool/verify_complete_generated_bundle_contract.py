#!/usr/bin/env python3
"""Run the deterministic Complete Generated Bundle provider-contract gates."""

from pathlib import Path
import os
import re
import subprocess
import sys


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = REPOSITORY_ROOT / "backend"
FOCUSED_TESTS = ",".join(
    (
        "CompleteGeneratedBundleContractTest",
        "AgenticCustomSceneGeneratorTest",
        "AgenticCustomSceneQualityJudgeTest",
        "AgenticCustomSceneRepairerTest",
        "JudgeWireResponseStrictOutputTest",
        "PracticeAiOperationRunnerTest",
        "PracticeAiPropertiesTest",
        "PracticeAiStructuredOutputCallerTest",
        "PracticeAiSingleRequestContractTest",
        "VersionedResourceRegistryTest",
        "CustomSceneAgenticGenerationIntegrationTest",
        "CustomSceneGenerationOrchestratorTest",
        "PracticeGeneratedContentServiceOrchestrationTest",
        "PracticeGeneratedContentStateMachineTest",
        "CustomSceneGeneratedContentValidatorTest",
        "JudgeVerdictCalculatorTest",
    )
)
SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS = 8192
SAFE_MINIMUM_QUALITY_JUDGE_OUTPUT_TOKENS = 8192
GENERATED_SOURCE_ROOT = (
    BACKEND_ROOT
    / "app-api"
    / "src"
    / "main"
    / "java"
    / "com"
    / "zhangspaghetti"
    / "babytalk"
    / "practice"
    / "generated"
)


def verify_no_production_fallback() -> bool:
    adapter_contracts = {
        "AgenticCustomSceneGenerator.java": (
            "OperationRequest.ProviderFailureStage.PROVIDER_RESPONSE_BINDING",
            "OperationRequest.ProviderFailureStage.CONTENT_STRICT_PARSER",
            "structuredOutputCaller.callRaw(",
            "CompleteGeneratedBundle.ProviderResponse.parse(content)",
            "GeneratedCareMomentBundle.fromCompleteBundle(result.value().toCompleteBundle(",
            "currentProfile.minimumCompleteBundleOutputTokens()",
            "CompleteGeneratedBundle.persistenceCodePointLimits()",
        ),
        "AgenticCustomSceneRepairer.java": (
            "OperationRequest.ProviderFailureStage.PROVIDER_RESPONSE_BINDING",
            "OperationRequest.ProviderFailureStage.CONTENT_STRICT_PARSER",
            "structuredOutputCaller.callRaw(",
            "CompleteGeneratedBundle.ProviderResponse.parse(content)",
            "GeneratedCareMomentBundle.fromCompleteBundle(result.value().toCompleteBundle(",
            "profile.minimumCompleteBundleOutputTokens()",
            "contentConstraintsPayload(request.contentConstraints())",
            "CompleteGeneratedBundle.persistenceCodePointLimits()",
            "profile.repairInferencePolicy()",
            "inferencePolicy.reasoningEffort()",
        ),
        "AgenticCustomSceneQualityJudge.java": (
            "profile.minimumQualityJudgeOutputTokens()",
            "structuredOutputCaller.call(",
            'violations.put("maxItems", ALLOWED_JUDGE_VIOLATION_CODES.size())',
            'arraySchema.put("maxItems", expected.size())',
        ),
    }
    forbidden_adapter_markers = (
        "fakeFixture(",
        "fakeSupport",
        "fixedSupport",
        "genericSupport",
        "starterOnly",
        "new CompleteGeneratedBundle.ProviderResponse",
        "new CompleteGeneratedBundle.ProviderUtterance",
        "new CompleteGeneratedBundle.ProviderUtterances",
    )
    violations: list[str] = []
    for relative_path, required_markers in adapter_contracts.items():
        source = (GENERATED_SOURCE_ROOT / relative_path).read_text(encoding="utf-8")
        for marker in required_markers:
            if marker not in source:
                violations.append(f"{relative_path}: missing strict complete-bundle marker: {marker}")
        for marker in forbidden_adapter_markers:
            if marker in source:
                violations.append(f"{relative_path}: forbidden production fallback marker: {marker}")

    orchestrator = (GENERATED_SOURCE_ROOT / "CustomSceneGenerationOrchestrator.java").read_text(
        encoding="utf-8"
    )
    required_orchestrator_markers = (
        "MAX_BRANCH_VIOLATION_DIAGNOSTICS = 174",
        "safeBranchName(",
        "safeViolationCode(",
        "gate.branchRequirements()",
        "context.branchRequirements()",
        "gate.repairableViolationDiagnostics()",
        "gate.terminalViolationDiagnostics()",
        "branchLengthDiagnostics(",
        "case PROVIDER_CONTENT_OVERFLOW",
    )
    for marker in required_orchestrator_markers:
        if marker not in orchestrator:
            violations.append(
                f"CustomSceneGenerationOrchestrator.java: missing bounded safe diagnostic marker: {marker}"
            )
    for marker in ("fakeFixture(", "fakeSupport", "fixedSupport", "genericSupport", "starterOnly"):
        if marker in orchestrator:
            violations.append(f"CustomSceneGenerationOrchestrator.java: forbidden fallback marker: {marker}")

    validator = (
        GENERATED_SOURCE_ROOT.parent / "discovery" / "CustomSceneGeneratedContentValidator.java"
    ).read_text(encoding="utf-8")
    diagnostic = (
        GENERATED_SOURCE_ROOT / "quality" / "GeneratedOutputViolationDiagnostic.java"
    ).read_text(encoding="utf-8")
    complete_bundle = (
        GENERATED_SOURCE_ROOT / "contract" / "CompleteGeneratedBundle.java"
    ).read_text(encoding="utf-8")
    generated_utterance = (
        GENERATED_SOURCE_ROOT / "GeneratedCareUtterance.java"
    ).read_text(encoding="utf-8")
    provider_identity = (
        GENERATED_SOURCE_ROOT.parent / "agentic" / "PracticeAiProviderIdentity.java"
    ).read_text(encoding="utf-8")
    provider_properties = (
        GENERATED_SOURCE_ROOT.parent / "agentic" / "PracticeAiProperties.java"
    ).read_text(encoding="utf-8")
    operation_runner = (
        GENERATED_SOURCE_ROOT.parent / "agentic" / "PracticeAiOperationRunner.java"
    ).read_text(encoding="utf-8")
    for source_name, source, markers in (
        (
            "CustomSceneGeneratedContentValidator.java",
            validator,
            (
                "providerContentOverflows(",
                "PROVIDER_CONTENT_OVERFLOW",
                "FieldPath.GENERATION_SOURCE",
                "evaluateProvenance(",
                "LengthUnit.GRAPHEME",
                "GeneratedOutputViolationCode.DATABASE_OVERFLOW",
            ),
        ),
        (
            "GeneratedOutputViolationDiagnostic.java",
            diagnostic,
            (
                "enum FieldPath",
                "fromWireValue(",
                "enum LengthUnit",
                'CODE_POINT("code_point")',
                'GRAPHEME("grapheme")',
                "actualLength",
                "limit",
                "auditCode()",
            ),
        ),
        (
            "CompleteGeneratedBundle.java",
            complete_bundle,
            (
                "PersistenceCodePointLimits",
                "@Schema(maxLength = SPACE_TITLE_ZH_MAX_CODE_POINTS)",
                "@Schema(maxLength = ENGLISH_TEXT_MAX_CODE_POINTS)",
                "@Schema(maxLength = DELIVERY_GUIDANCE_ZH_MAX_CODE_POINTS)",
                "PROVIDER_NAME_MAX_CODE_POINTS",
                "MODEL_NAME_MAX_CODE_POINTS",
            ),
        ),
        (
            "GeneratedCareUtterance.java",
            generated_utterance,
            ('requireText(englishText, "englishText")',),
        ),
        (
            "PracticeAiProviderIdentity.java",
            provider_identity,
            (
                "PROVIDER_NAME_MAX_CODE_POINTS = 64",
                "MODEL_NAME_MAX_CODE_POINTS = 96",
                "requireProviderName(",
                "requireModelName(",
            ),
        ),
        (
            "PracticeAiProperties.java",
            provider_properties,
            (
                "requireProviderName(entry.getKey())",
                "requireModelName(model.trim())",
            ),
        ),
    ):
        for marker in markers:
            if marker not in source:
                violations.append(f"{source_name}: missing overflow contract marker: {marker}")

    provider_authored_fields = (
        "spaceTitleZh",
        "activityTitleZh",
        "sceneTagEn",
        "englishText",
        "chineseText",
        "pronunciationHint",
        "tprActionZh",
        "deliveryGuidanceZh",
        "difficulty",
    )
    for field_name in provider_authored_fields:
        pre_gate_bound = re.compile(
            rf'requireText\s*\(\s*{field_name}\s*,\s*"{field_name}"\s*,'
        )
        if pre_gate_bound.search(complete_bundle):
            violations.append(
                "CompleteGeneratedBundle.java: provider-authored persistence bound "
                f"for {field_name} must be enforced by Gate"
            )
        if field_name not in {"spaceTitleZh", "activityTitleZh", "sceneTagEn"} \
                and pre_gate_bound.search(generated_utterance):
            violations.append(
                "GeneratedCareUtterance.java: provider-authored persistence bound "
                f"for {field_name} must be enforced by Gate"
            )

    for marker in (
        "PracticeAiProviderIdentity.requireProviderName(provider.providerName())",
        "PracticeAiProviderIdentity.requireModelName(provider.modelName())",
    ):
        if marker not in operation_runner:
            violations.append(
                f"PracticeAiOperationRunner.java: missing pre-audit provider identity guard: {marker}"
            )
    identity_guard = operation_runner.find(
        "PracticeAiProviderIdentity.requireProviderName(provider.providerName())"
    )
    audit_write = operation_runner.find("auditPort.insertOperationRun(")
    if identity_guard < 0 or audit_write < 0 or identity_guard > audit_write:
        violations.append(
            "PracticeAiOperationRunner.java: provider identity guard must precede audit writes"
        )

    orchestrator_contract_test = (
        BACKEND_ROOT
        / "app-api"
        / "src"
        / "test"
        / "java"
        / "com"
        / "zhangspaghetti"
        / "babytalk"
        / "practice"
        / "generated"
        / "CustomSceneGenerationOrchestratorTest.java"
    ).read_text(encoding="utf-8")
    for marker in (
        "rawWireOverflowFlowsThroughGeneratorGateAndWholeBundleRepair",
        '"空".repeat(121)',
        '"汉".repeat(121)',
        "fieldPath=spaceTitleZh",
        "fieldPath=chineseText",
    ):
        if marker not in orchestrator_contract_test:
            violations.append(
                f"CustomSceneGenerationOrchestratorTest.java: missing raw overflow coverage: {marker}"
            )

    repairer = (GENERATED_SOURCE_ROOT / "AgenticCustomSceneRepairer.java").read_text(
        encoding="utf-8"
    )
    typed_repair_package = (
        GENERATED_SOURCE_ROOT / "quality" / "TypedRepairPackage.java"
    ).read_text(encoding="utf-8")
    for source_name, source, markers in (
        (
            "AgenticCustomSceneRepairer.java",
            repairer,
            (
                "repairPackage.branchRequirements()",
                "BranchRequirementPayload",
                "EvidenceActionConsistencyPolicyPayload.strict()",
                "orderedSanitizedEvidenceSummaries",
                "requireEachTprActionSupportedByGrounding",
                "forbidUnmentionedObjectsOrBodyActions",
                "repairAllTprBranchesWhenJudgeReportsInconsistency",
            ),
        ),
        (
            "TypedRepairPackage.java",
            typed_repair_package,
            ("List<BranchRequirement> branchRequirements", "public enum Branch"),
        ),
    ):
        for marker in markers:
            if marker not in source:
                violations.append(f"{source_name}: missing typed branch repair marker: {marker}")

    judge = (GENERATED_SOURCE_ROOT / "AgenticCustomSceneQualityJudge.java").read_text(
        encoding="utf-8"
    )
    judge_contract_test = (
        BACKEND_ROOT
        / "app-api"
        / "src"
        / "test"
        / "java"
        / "com"
        / "zhangspaghetti"
        / "babytalk"
        / "practice"
        / "agentic"
        / "JudgeWireResponseStrictOutputTest.java"
    ).read_text(encoding="utf-8")
    for source_name, source, markers in (
        (
            "AgenticCustomSceneQualityJudge.java",
            judge,
            (
                "@PracticeAiJsonSchemaPublisher.RefinedBy(JudgeWireResponseSchemaRefiner.class)",
                "List<String> DIMENSION_KEYS",
                "List<String> ALLOWED_JUDGE_VIOLATION_CODES",
                'dimensions.put("additionalProperties", false)',
                'confidence.put("minimum", 0.0d)',
                'confidence.put("maximum", 1.0d)',
                "requireExactKeywords",
                "custom_scene_quality_judge_provider_schema_invalid",
            ),
        ),
        (
            "JudgeWireResponseStrictOutputTest.java",
            judge_contract_test,
            (
                "publishedJudgeSchemaMatchesStrictConverterContract",
                "judgeSchemaRefinerRejectsDimensionMapBaseSchemaDrift",
                "judgeSchemaRefinerRejectsTopLevelPropertyAndRequiredDrift",
                "judgeSchemaRefinerRejectsBrokenLocalEnumReference",
                "judgeSchemaRefinerRejectsConfidenceBaseSchemaDrift",
                "judgeSchemaRefinerRejectsUnknownBaseSchemaKeywords",
                'Arguments.of("unknown violation code"',
                "publishedJudgeSchemaStaysInsidePublisherSafetyBudget",
            ),
        ),
    ):
        for marker in markers:
            if marker not in source:
                violations.append(f"{source_name}: missing strict Judge schema marker: {marker}")

    agentic_integration_test = (
        BACKEND_ROOT
        / "app-api"
        / "src"
        / "test"
        / "java"
        / "com"
        / "zhangspaghetti"
        / "babytalk"
        / "practice"
        / "generated"
        / "CustomSceneAgenticGenerationIntegrationTest.java"
    ).read_text(encoding="utf-8")
    for marker in (
        "judgeTprFailureRepairsWithEvidenceActionContractThenFreshJudgeActivates",
        'List.of("TPR_QUALITY_FAILED")',
        '"judge_evidence_action_inconsistent"',
        "evidenceActionConsistencyPolicy",
        '"select status from practice_generated_content"',
        'isEqualTo("active")',
    ):
        if marker not in agentic_integration_test:
            violations.append(
                "CustomSceneAgenticGenerationIntegrationTest.java: "
                f"missing TPR repair consistency coverage: {marker}"
            )

    structured_caller = (
        GENERATED_SOURCE_ROOT.parent / "agentic" / "PracticeAiStructuredOutputCaller.java"
    ).read_text(encoding="utf-8")
    structured_caller_test = (
        BACKEND_ROOT
        / "app-api"
        / "src"
        / "test"
        / "java"
        / "com"
        / "zhangspaghetti"
        / "babytalk"
        / "practice"
        / "agentic"
        / "PracticeAiStructuredOutputCallerTest.java"
    ).read_text(encoding="utf-8")
    for source_name, source, markers in (
        (
            "PracticeAiStructuredOutputCaller.java",
            structured_caller,
            (
                "EnumFeature.FAIL_ON_NUMBERS_FOR_ENUMS",
                "MapperFeature.ALLOW_COERCION_OF_SCALARS",
            ),
        ),
        (
            "PracticeAiStructuredOutputCallerTest.java",
            structured_caller_test,
            ("strictConversionRejectsStringToNumberAndBooleanCoercion",),
        ),
    ):
        for marker in markers:
            if marker not in source:
                violations.append(f"{source_name}: missing strict scalar coercion marker: {marker}")

    fake_fixture_allowlist = {
        str(Path("generated") / "GeneratedCareMomentBundle.java"),
        str(Path("discovery") / "FakeCustomSceneGenerationService.java"),
    }
    practice_root = GENERATED_SOURCE_ROOT.parent
    for source_path in practice_root.rglob("*.java"):
        source = source_path.read_text(encoding="utf-8")
        if "fakeFixture(" not in source:
            continue
        relative_path = str(source_path.relative_to(practice_root))
        if relative_path not in fake_fixture_allowlist:
            violations.append(f"{relative_path}: fakeFixture is restricted to the fake provider path")

    for violation in violations:
        print(violation, file=sys.stderr)
    return not violations


def verify_versioned_output_budget() -> bool:
    violations: list[str] = []
    profile_path = (
        BACKEND_ROOT
        / "app-api"
        / "src"
        / "main"
        / "resources"
        / "config"
        / "practice-ai"
        / "profiles"
        / "custom-scene-generation-v5.yml"
    )
    profile = profile_path.read_text(encoding="utf-8")
    profile_match = re.search(
        r"(?m)^minimum-complete-bundle-output-tokens:\s*(\d+)\s*$", profile
    )
    profile_budget: int | None = None
    if profile_match is None:
        violations.append(f"{profile_path.name}: missing versioned complete-bundle output budget")
    else:
        profile_budget = int(profile_match.group(1))
        if profile_budget < SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS:
            violations.append(f"{profile_path.name}: complete-bundle output budget is below safe minimum")

    judge_budget_match = re.search(
        r"(?m)^minimum-quality-judge-output-tokens:\s*(\d+)\s*$", profile
    )
    judge_budget: int | None = None
    if judge_budget_match is None:
        violations.append(f"{profile_path.name}: missing versioned Quality Judge output budget")
    else:
        judge_budget = int(judge_budget_match.group(1))
        if judge_budget < SAFE_MINIMUM_QUALITY_JUDGE_OUTPUT_TOKENS:
            violations.append(f"{profile_path.name}: Quality Judge output budget is below safe minimum")

    repair_inference_markers = (
        "schema-version: generation-profile-schema-v3",
        "repair-inference-policy:",
        "provider-type: openai-compatible",
        "model-names: [glm-5.2]",
        "reasoning-effort: none",
    )
    for marker in repair_inference_markers:
        if marker not in profile:
            violations.append(
                f"{profile_path.name}: missing bounded Repair inference compatibility marker: {marker}"
            )

    for relative_path in (
        Path("deploy/helm/babytalk-app/values-kind-qa.yaml"),
        Path("deploy/helm/babytalk-app/values-production.yaml"),
    ):
        text = (REPOSITORY_ROOT / relative_path).read_text(encoding="utf-8")
        limit_match = re.search(
            r"(?m)^\s+(?:maxTokens|maxCompletionTokens):\s*(\d+)\s*$", text
        )
        if limit_match is None:
            violations.append(f"{relative_path}: missing typed Practice AI output-token limit")
        elif int(limit_match.group(1)) < max(
            profile_budget or SAFE_MINIMUM_COMPLETE_BUNDLE_OUTPUT_TOKENS,
            judge_budget or SAFE_MINIMUM_QUALITY_JUDGE_OUTPUT_TOKENS,
        ):
            violations.append(
                f"{relative_path}: Practice AI output-token limit is below the versioned profile budget"
            )

    prompt_contracts = {
        Path("backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-generator-v3.txt"): (
            "all six canonical branches",
            "For every branch, tprActionZh",
            "For every branch, deliveryGuidanceZh",
            "Each tprActionZh must directly enact its own branch English and Chinese utterance",
        ),
        Path("backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-repair-v3.txt"): (
            "Apply every structured branchRequirements item",
            "MISSING_TPR_ACTION",
            "MISSING_DELIVERY_GUIDANCE",
            "judge_evidence_action_inconsistent",
            "evidenceActionConsistencyPolicy.groundingSources",
        ),
        Path("backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-quality-judge-v3.txt"): (
            "semantic triangle",
            "Do not emit TPR_QUALITY_EVIDENCE_MISSING only because",
            "Do not relax any rubric dimension",
            "Each enum array must contain unique items only",
            "Never repeat an enum item",
        ),
    }
    for relative_path, markers in prompt_contracts.items():
        prompt = (REPOSITORY_ROOT / relative_path).read_text(encoding="utf-8")
        for marker in markers:
            if marker not in prompt:
                violations.append(f"{relative_path}: missing branch field requirement marker: {marker}")

    for violation in violations:
        print(violation, file=sys.stderr)
    return not violations


def main() -> int:
    if not verify_no_production_fallback() or not verify_versioned_output_budget():
        return 1
    arguments = [
        "-pl",
        "app-api",
        "-am",
        f"-Dtest={FOCUSED_TESTS}",
        "-Dsurefire.failIfNoSpecifiedTests=false",
        "test",
    ]
    command = (
        ["cmd.exe", "/d", "/c", "mvnw.cmd", *arguments]
        if os.name == "nt"
        else ["./mvnw", *arguments]
    )
    result = subprocess.run(command, cwd=BACKEND_ROOT, check=False)
    if result.returncode != 0:
        return result.returncode
    print("Complete Generated Bundle provider contract verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
