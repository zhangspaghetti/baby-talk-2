#!/usr/bin/env python3
"""Run the deterministic Complete Generated Bundle provider-contract gates."""

from pathlib import Path
import os
import subprocess
import sys


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = REPOSITORY_ROOT / "backend"
FOCUSED_TESTS = ",".join(
    (
        "CompleteGeneratedBundleContractTest",
        "AgenticCustomSceneGeneratorTest",
        "AgenticCustomSceneRepairerTest",
        "PracticeAiStructuredOutputCallerTest",
        "CustomSceneAgenticGenerationIntegrationTest",
        "CustomSceneGenerationOrchestratorTest",
        "PracticeGeneratedContentServiceOrchestrationTest",
        "PracticeGeneratedContentStateMachineTest",
        "CustomSceneGeneratedContentValidatorTest",
        "JudgeVerdictCalculatorTest",
    )
)
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
            "CompleteGeneratedBundle.ProviderResponse.parse(structuredOutputCaller.callRaw(",
            "GeneratedCareMomentBundle.fromCompleteBundle(result.value().toCompleteBundle(",
        ),
        "AgenticCustomSceneRepairer.java": (
            "CompleteGeneratedBundle.ProviderResponse.parse(structuredOutputCaller.callRaw(",
            "GeneratedCareMomentBundle.fromCompleteBundle(result.value().toCompleteBundle(",
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
    for marker in ("fakeFixture(", "fakeSupport", "fixedSupport", "genericSupport", "starterOnly"):
        if marker in orchestrator:
            violations.append(f"CustomSceneGenerationOrchestrator.java: forbidden fallback marker: {marker}")

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


def main() -> int:
    if not verify_no_production_fallback():
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
