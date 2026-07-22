import os
import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
FULL_CI = REPO_ROOT / "ci" / "full-ci.sh"


class FullCiScriptContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue(FULL_CI.is_file(), "ci/full-ci.sh must exist")
        self.text = FULL_CI.read_text(encoding="utf-8")

    def test_script_is_executable_and_uses_strict_mode(self) -> None:
        self.assertTrue(os.access(FULL_CI, os.X_OK), "ci/full-ci.sh must be executable")
        self.assertTrue(self.text.startswith("#!/usr/bin/env bash\nset -euo pipefail\n"))

    def test_target_and_repository_cleanliness_are_fail_closed(self) -> None:
        self.assertIn("origin/Develop", self.text)
        self.assertNotIn("origin/main", self.text)
        status_checks = [
            match.start()
            for match in re.finditer(
                r"git status --porcelain=v1 --untracked-files=all", self.text
            )
        ]
        self.assertGreaterEqual(len(status_checks), 2)
        self.assertLess(status_checks[0], self.text.index("verify_spring_ai_2_backend_platform_test.py"))
        self.assertGreater(status_checks[-1], self.text.index("git diff --check"))
        fetch = self.text.index("git fetch --no-tags origin Develop")
        self.assertGreater(fetch, status_checks[0])
        self.assertLess(fetch, self.text.index("git rev-parse --verify 'HEAD^{commit}'"))

    def test_required_gates_stay_in_fixed_order(self) -> None:
        ordered_markers = [
            "practice-ai-version-lock-base",
            "python3 test/tool/verify_spring_ai_2_backend_platform_test.py",
            "python3 tool/verify_spring_ai_2_backend_platform.py",
            "dependency:tree",
            "--dependency-tree",
            "verify_practice_ai_version_lock.py --verify --base-lock",
            "verify_practice_generation_privacy_test.py",
            "verify_practice_generation_privacy.py",
            "dart test test/tool/verify_practice_ai_helm_test.dart",
            "dart run tool/verify_practice_ai_helm.dart",
            "bash ci/backend-test.sh",
            "GrowthServiceMapperIntegrationTest",
            "checkstyle:check",
            "bash ci/k8s-smoke.sh",
            "pnpm install --frozen-lockfile",
            "pnpm --filter admin-web typecheck",
            "pnpm --filter admin-web lint",
            "pnpm --filter admin-web format",
            "pnpm --filter admin-web test:coverage",
            "pnpm --filter admin-web install:browsers",
            "pnpm --filter admin-web test:e2e:p0 --reporter=list",
            "pnpm --filter admin-web build",
            "bash ci/mobile-analyze.sh",
            "bash ci/mobile-r4-release-gates.sh",
            "stage 'release-fixtures'",
            "verify_m006_s14_release_closure_test.dart",
            "verify_m007_schema_compatibility_test.dart",
            "verify_m007_s01_helm_baseline_test.dart",
            "dart run tool/verify_m007_s02_release_boundaries.dart",
            "dart run tool/verify_m007_s06_docs_coherence.dart",
            "refresh identical Flutter Windows plugin registrant metadata",
            "git diff --check",
        ]
        positions = [self.text.index(marker) for marker in ordered_markers]
        self.assertEqual(positions, sorted(positions))

    def test_environment_sanitizer_uses_prefix_and_exact_rules(self) -> None:
        for pattern in (
            "${!BABY_TALK_@}",
            "${!SPRING_@}",
            "${!MVNW_@}",
            "${!DB_@}",
            "${!MINIO_@}",
            "${!JWT_@}",
            "${!KUBE_@}",
            "${!KUBERNETES_@}",
            "${!HELM_@}",
            "${!TESTCONTAINERS_@}",
        ):
            self.assertIn(pattern, self.text)
        for variable in (
            "SSY_API_KEY",
            "SPRING_APPLICATION_JSON",
            "DATABASE_URL",
            "JDBC_DATABASE_URL",
            "REDIS_URL",
            "PGPASSWORD",
            "PGPASSFILE",
            "PGSERVICE",
            "JAVA_TOOL_OPTIONS",
            "_JAVA_OPTIONS",
            "JDK_JAVA_OPTIONS",
            "MAVEN_OPTS",
            "MAVEN_ARGS",
            "MAVEN_USER_HOME",
            "MAVEN_EXT_CLASS_PATH",
            "CLASSPATH",
            "KUBECONFIG",
            "KUBE_TOKEN",
            "GITHUB_TOKEN",
            "GH_TOKEN",
            "NPM_TOKEN",
            "DOCKER_HOST",
            "DOCKER_CONTEXT",
        ):
            self.assertIn(variable, self.text)
        self.assertIn('unset "$env_name"', self.text)
        self.assertIn("initialize_ci_environment", self.text)
        self.assertNotIn("CI_ENV=(", self.text)

    def test_owned_kubeconfig_and_ryuk_defaults_are_exported_and_cleaned(self) -> None:
        self.assertIn("mktemp -d", self.text)
        self.assertIn("empty_kubeconfig", self.text)
        self.assertIn("export KUBECONFIG=", self.text)
        self.assertIn("clusters: []", self.text)
        self.assertIn("export TESTCONTAINERS_RYUK_DISABLED=false", self.text)
        self.assertRegex(self.text, r"rm -f .*empty_kubeconfig")
        self.assertRegex(self.text, r"rmdir .*ci_runtime_dir")

    def test_docker_preflight_owns_only_its_scoped_relay(self) -> None:
        self.assertIn("tcp://localhost:2375", self.text)
        self.assertIn(
            "alpine/socat@sha256:d85531a29ef5ba99dfb4717485c239307e2902d522a1bc010992a2728c92cfad",
            self.text,
        )
        self.assertIn(".OSType", self.text)
        self.assertRegex(self.text, r"docker rm -f .*relay_container_id")
        self.assertNotIn("docker rm -f ci-docker-relay", self.text)
        self.assertIn(
            "MSYS_NO_PATHCONV=1 docker run -d",
            self.text,
            "Git Bash must not rewrite /var/run/docker.sock into a Windows path",
        )

    def test_required_gates_never_use_or_true(self) -> None:
        required_markers = (
            "verify_spring_ai_2_backend_platform",
            "verify_practice_ai_version_lock.py",
            "verify_practice_generation_privacy",
            "verify_practice_ai_helm",
            "dependency:tree",
            "backend-test.sh",
            "GrowthServiceMapperIntegrationTest",
            "checkstyle:check",
            "k8s-smoke.sh",
            "admin-web typecheck",
            "admin-web lint",
            "admin-web format",
            "admin-web test:coverage",
            "admin-web test:e2e:p0",
            "admin-web build",
            "mobile-analyze.sh",
            "mobile-r4-release-gates.sh",
            "flutter test",
            "verify_m007_s02_release_boundaries",
            "verify_m007_s06_docs_coherence",
            "git diff --check",
            "git status --porcelain",
        )
        for line in self.text.splitlines():
            if any(marker in line for marker in required_markers):
                self.assertNotIn("|| true", line)

    def test_custom_scene_verifiers_use_the_fresh_develop_lock_and_are_not_skippable(self) -> None:
        self.assertIn("git cat-file -e", self.text)
        self.assertIn("${ORIGIN_DEVELOP_SHA}:backend/app-api/src/main/resources/config/practice-ai/version-lock.yml", self.text)
        self.assertIn("base_version_lock=", self.text)
        self.assertIn("verify_practice_ai_version_lock.py --verify --base-lock \"$base_version_lock\"", self.text)
        self.assertIn("python3 test/tool/verify_practice_generation_privacy_test.py", self.text)
        self.assertIn("python3 tool/verify_practice_generation_privacy.py", self.text)
        self.assertIn("dart test test/tool/verify_practice_ai_helm_test.dart", self.text)
        self.assertIn("dart run tool/verify_practice_ai_helm.dart", self.text)
        self.assertNotIn("stage 'mobile-test'", self.text)
        self.assertNotIn("cd mobile && flutter test", self.text)

    def test_stable_stage_markers_cover_every_gate_in_order(self) -> None:
        gate_ids = (
            "fetch-target",
            "practice-ai-version-lock-base",
            "docker-preflight",
            "spring-ai-fixture",
            "spring-ai-live",
            "spring-ai-dependency-tree",
            "spring-ai-resolved",
            "practice-ai-version-lock",
            "practice-generation-privacy-fixture",
            "practice-generation-privacy",
            "practice-ai-helm-fixture",
            "practice-ai-helm",
            "backend-reactor",
            "growth-mapper-postgres",
            "backend-checkstyle",
            "helm-resource-parser",
            "helm-smoke",
            "admin-web-install",
            "admin-web-typecheck",
            "admin-web-lint",
            "admin-web-format",
            "admin-web-unit",
            "admin-web-browsers",
            "admin-web-e2e",
            "admin-web-build",
            "mobile-analyze",
            "mobile-r4",
            "release-fixtures",
            "m007-s02",
            "m007-s06",
            "flutter-windows-generated-metadata",
            "diff-check",
            "final-cleanliness",
        )
        positions = [self.text.index(f"stage '{gate_id}'") for gate_id in gate_ids]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("gate=%s command=%s", self.text)

    def test_flutter_windows_metadata_refresh_fails_closed_on_content_changes(self) -> None:
        refresh = self.text.index(
            "  refresh_flutter_windows_generated_metadata\n",
            self.text.index("stage 'm007-s06'"),
        )
        final_diff_check = self.text.index("stage 'diff-check'")
        self.assertLess(refresh, final_diff_check)
        self.assertIn("mobile/windows/flutter/generated_plugin_registrant.cc", self.text)
        self.assertIn("mobile/windows/flutter/generated_plugin_registrant.h", self.text)
        self.assertIn("mobile/windows/flutter/generated_plugins.cmake", self.text)
        self.assertIn('git diff --quiet -- "${generated_plugin_files[@]}"', self.text)
        self.assertIn('git add -- "${generated_plugin_files[@]}"', self.text)
        self.assertIn('git diff --cached --quiet -- "${generated_plugin_files[@]}"', self.text)
        self.assertIn("Flutter changed tracked Windows plugin registrant content", self.text)
        self.assertIn("Flutter Windows plugin registrant refresh staged content", self.text)

    def test_script_can_be_sourced_without_running_main(self) -> None:
        self.assertIn('[[ "${BASH_SOURCE[0]}" == "$0" ]]', self.text)
        self.assertIn("main \"$@\"", self.text)

    def test_success_metadata_is_only_printed_after_final_cleanliness_check(self) -> None:
        final_status = self.text.rindex("git status --porcelain=v1 --untracked-files=all")
        final_lines = [
            "target_branch=Develop",
            "commit=${HEAD_SHA}",
            "origin_develop=${ORIGIN_DEVELOP_SHA}",
            "merge_base=${MERGE_BASE_SHA}",
            "full local CI passed",
        ]
        positions = [self.text.index(line) for line in final_lines]
        self.assertEqual(positions, sorted(positions))
        self.assertTrue(all(position > final_status for position in positions))


class ActiveCiTruthContractTest(unittest.TestCase):
    def test_active_workflows_run_only_after_develop_merges_to_release_qa(self) -> None:
        workflow_jobs = {
            ".github/workflows/ci.yml": (
                "release-closure-gate",
                "mobile-analyze",
            ),
            ".github/workflows/admin-web.yml": (
                "typecheck",
                "lint",
                "unit",
                "e2e",
                "build",
            ),
            ".github/workflows/mobile-pr-validation.yml": ("analyze",),
            ".github/workflows/mobile-build.yml": ("test-full",),
        }
        release_merge_condition = (
            "github.event.pull_request.merged == true && "
            "github.event.pull_request.head.ref == 'Develop'"
        )
        for relative_path, root_jobs in workflow_jobs.items():
            text = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertNotIn("  push:\n", text, relative_path)
            self.assertIn(
                "pull_request:\n    types: [closed]\n    branches: [Release_QA]",
                text,
                relative_path,
            )
            for job in root_jobs:
                self.assertIn(
                    f"  {job}:\n    if: {release_merge_condition}\n",
                    text,
                    relative_path,
                )

    def test_current_authority_copy_names_full_ci(self) -> None:
        required_copy = (
            "bash ci/full-ci.sh is the only complete local repository CI entrypoint.",
            ".github/workflows/ci.yml is simulated locally with act.",
            "GitHub-hosted Actions are intentionally disabled.",
        )
        paths = (
            "README.md",
            "CONTRIBUTING.md",
            "docs/runbooks/m006-s14-release-closure.md",
            "tool/verify_m006_s14_release_closure.dart",
        )
        for relative_path in paths:
            text = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
            for sentence in required_copy:
                self.assertIn(sentence, text, relative_path)
if __name__ == "__main__":
    unittest.main()
