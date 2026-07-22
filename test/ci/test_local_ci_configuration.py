import json
import os
import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
ACTRC = REPO_ROOT / ".actrc"
EVENT_FIXTURE = REPO_ROOT / ".act" / "pull_request.json"
LOCAL_ACT_WORKFLOW = REPO_ROOT / ".act" / "workflows" / "local-act-pr.yml"
GITHUB_LOCAL_ACT_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "local-act-pr.yml"
LOCAL_ACT_RUNNER = REPO_ROOT / "ci" / "run-act-pr.sh"
GITIGNORE = REPO_ROOT / ".gitignore"
LOCAL_CI_DOC = REPO_ROOT / "docs" / "development" / "local-ci.md"
LEFTHOOK_CONFIG = REPO_ROOT / "lefthook.yml"
GITATTRIBUTES = REPO_ROOT / ".gitattributes"
CI_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "ci.yml"
BACKEND_TEST_SCRIPT = REPO_ROOT / "ci" / "backend-test.sh"
PACKAGE_JSON = REPO_ROOT / "package.json"
PNPM_WORKSPACE = REPO_ROOT / "pnpm-workspace.yaml"
MOBILE_TEST_ROOT = REPO_ROOT / "mobile" / "test"
NPMRC = REPO_ROOT / ".npmrc"
DOWNLOAD_SOURCES = REPO_ROOT / "ci" / "download-sources.sh"
MAVEN_WRAPPER = REPO_ROOT / "ci" / "maven.sh"
MAVEN_SETTINGS = REPO_ROOT / "backend" / ".mvn" / "settings.xml"

ISAR_TEST_LIBRARY_CONSUMERS = (
    "app/app_composition_characterization_test.dart",
    "app/local_sensitive_data_clearance_registry_test.dart",
    "features/account/account_repository_test.dart",
    "features/garden/garden_fertilizer_notifier_test.dart",
    "features/garden/garden_fertilizer_repository_test.dart",
    "features/garden/presentation/garden_fertilizer_notifier_remote_test.dart",
    "features/mentor/mentor_repository_test.dart",
    "features/mentor/mentor_shell_panel_test.dart",
    "features/onboarding/onboarding_repository_test.dart",
    "features/practice/garden_growth_repository_test.dart",
    "features/practice/practice_repository_characterization_harness.dart",
    "features/practice/practice_repository_test.dart",
    "features/practice/practice_session_notifier_test.dart",
    "features/sync/sync_repository_test.dart",
    "smoke/app_boot_test.dart",
    "widget_test.dart",
)

RUNNER_IMAGE = (
    "ghcr.io/catthehacker/ubuntu:act-24.04@sha256:"
    "5d6a17640b25694988b9db5a4145537b9918e5430116b2cf90d84e837609b382"
)
def _walk_json(value, path="root"):
    if isinstance(value, dict):
        for key, child in value.items():
            yield f"{path}.{key}", key, child
            yield from _walk_json(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _walk_json(child, f"{path}[{index}]")


class ActConfigurationContractTest(unittest.TestCase):
    def test_actrc_pins_runner_and_isolation_contract(self) -> None:
        self.assertTrue(ACTRC.is_file(), ".actrc must exist")
        lines = ACTRC.read_text(encoding="utf-8").splitlines()

        self.assertEqual(
            lines,
            [
                "--container-architecture=linux/amd64",
                f"--platform=ubuntu-latest={RUNNER_IMAGE}",
                "--network=host",
                "--artifact-server-path=.act/artifacts",
                "--defaultbranch=Develop",
                "--env=TESTCONTAINERS_RYUK_DISABLED=false",
                "--env=TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal",
                "--env=PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT=180000",
                "--strict",
                "--rm",
            ],
        )
        joined = "\n".join(lines).lower()
        for forbidden in ("--secret", "--secret-file", "--bind", "--reuse"):
            self.assertNotIn(forbidden, joined)
        self.assertNotIn("7890", joined)

    def test_pull_request_fixture_is_a_sha_free_runtime_template(self) -> None:
        self.assertTrue(EVENT_FIXTURE.is_file(), ".act/pull_request.json template must exist")
        event = json.loads(EVENT_FIXTURE.read_text(encoding="utf-8"))

        self.assertEqual(event["action"], "synchronize")
        self.assertEqual(event["number"], 13)
        pull_request = event["pull_request"]
        self.assertEqual(pull_request["number"], 13)
        self.assertTrue(pull_request["draft"])
        self.assertFalse(pull_request["merged"])
        self.assertEqual(pull_request["base"]["ref"], "Develop")
        self.assertNotIn("sha", pull_request["base"])
        self.assertEqual(
            pull_request["base"]["repo"]["full_name"],
            "zhangspaghetti/baby-talk-2",
        )
        self.assertNotIn("ref", pull_request["head"])
        self.assertNotIn("sha", pull_request["head"])
        self.assertEqual(
            pull_request["head"]["repo"]["full_name"],
            "zhangspaghetti/baby-talk-2",
        )

        repository = event["repository"]
        self.assertEqual(repository["name"], "baby-talk-2")
        self.assertEqual(repository["full_name"], "zhangspaghetti/baby-talk-2")
        self.assertEqual(repository["default_branch"], "Develop")
        self.assertEqual(repository["owner"]["login"], "zhangspaghetti")

    def test_runtime_act_workflow_is_a_real_develop_pr_job_not_a_release_closure_replay(self) -> None:
        self.assertTrue(LOCAL_ACT_WORKFLOW.is_file())
        self.assertFalse(GITHUB_LOCAL_ACT_WORKFLOW.exists())
        self.assertTrue(LOCAL_ACT_RUNNER.is_file())
        workflow = LOCAL_ACT_WORKFLOW.read_text(encoding="utf-8")
        runner = LOCAL_ACT_RUNNER.read_text(encoding="utf-8")

        self.assertIn("pull_request:\n    branches: [Develop]", workflow)
        self.assertIn("local-pr-full-ci:", workflow)
        self.assertNotIn("if:", workflow)
        self.assertIn("run: bash ci/full-ci.sh", workflow)
        self.assertNotIn("actions/checkout", workflow)
        self.assertNotIn("git init", workflow)
        self.assertNotIn("act workspace snapshot", workflow)
        self.assertIn("EXPECTED_HEAD_SHA: ${{ github.event.local_act.head_sha }}", workflow)
        self.assertIn("test -d .git", workflow)
        self.assertIn('test "$(git rev-parse HEAD)" = "$EXPECTED_HEAD_SHA"', workflow)
        self.assertIn("act bind mount became dirty before full CI", workflow)
        self.assertIn("git -c core.autocrlf=true status", workflow)
        self.assertIn("GIT_CONFIG_KEY_0: core.autocrlf", workflow)
        self.assertIn("actions/setup-java@v4", workflow)
        self.assertIn("actions/setup-python@v5", workflow)
        self.assertIn("pip install --disable-pip-version-check PyYAML", workflow)
        self.assertIn("actions/setup-node@v4", workflow)
        self.assertIn("azure/setup-helm@v4", workflow)
        self.assertIn("subosito/flutter-action@v2", workflow)
        self.assertIn("FLUTTER_STORAGE_BASE_URL: https://storage.flutter-io.cn", workflow)
        self.assertIn("git status --porcelain=v1 --untracked-files=all", runner)
        self.assertIn("git fetch --no-tags origin Develop", runner)
        self.assertIn("git merge-base", runner)
        self.assertIn('event["pull_request"]["base"]["sha"] = origin_develop_sha', runner)
        self.assertIn('event["pull_request"]["head"]["sha"] = head_sha', runner)
        self.assertIn("fixture does not select local-pr-full-ci", runner)
        self.assertIn("local-pr-full-ci was skipped", runner)
        self.assertIn("did not report success", runner)
        self.assertEqual(runner.count("act -b"), 2)
        self.assertEqual(runner.count("2>&1 | tee \"$act_log\""), 2)

    def test_pull_request_fixture_contains_no_credentials(self) -> None:
        event = json.loads(EVENT_FIXTURE.read_text(encoding="utf-8"))
        secret_key_fragments = ("secret", "token", "password", "credential", "api_key")
        for path, key, value in _walk_json(event):
            lowered_key = key.lower()
            self.assertFalse(
                any(fragment in lowered_key for fragment in secret_key_fragments),
                f"credential-shaped key at {path}",
            )
            if isinstance(value, str):
                self.assertNotIn("BEGIN PRIVATE KEY", value)
                self.assertNotIn("7890", value)

    def test_act_artifacts_are_ignored_without_ignoring_fixture(self) -> None:
        lines = {
            line.strip()
            for line in GITIGNORE.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        self.assertIn("/.act/artifacts/", lines)
        self.assertIn(".gstack", lines)
        self.assertNotIn("/.act/", lines)
        self.assertNotIn(".act/", lines)

    def test_surefire_forks_inherit_testcontainers_host_override(self) -> None:
        for module in ("app-api", "admin-api", "db-migration"):
            pom = (REPO_ROOT / "backend" / module / "pom.xml").read_text(
                encoding="utf-8"
            )
            self.assertNotIn(
                "<TESTCONTAINERS_HOST_OVERRIDE>",
                pom,
                f"{module} must inherit the host override selected by its runner",
            )

    def test_exact_sha_reports_and_local_worktrees_are_ignored(self) -> None:
        lines = {
            line.strip()
            for line in GITIGNORE.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        self.assertIn("/docs/superpowers/reports/local-ci-*.md", lines)
        self.assertIn("/.worktrees/", lines)


class LocalCiDocumentationContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue(LOCAL_CI_DOC.is_file(), "docs/development/local-ci.md must exist")
        self.text = LOCAL_CI_DOC.read_text(encoding="utf-8")

    def test_docs_define_local_only_ci_authority(self) -> None:
        for statement in (
            "Target branch: `Develop`",
            "`bash ci/full-ci.sh` is the only complete local repository CI entrypoint.",
            "GitHub-hosted Actions: **INTENTIONALLY DISABLED**",
            "Server-side required checks: **NOT CONFIGURED**",
            "act is a local GitHub Actions simulation",
        ):
            self.assertIn(statement, self.text)
        for false_claim in (
            "remote CI passed",
            "GitHub CI passed",
            "branch protection passed",
            "required checks passed",
        ):
            self.assertNotIn(false_claim, self.text)

    def test_docs_give_the_runtime_template_wrapper_command(self) -> None:
        self.assertIn("bash ci/run-act-pr.sh", self.text)
        self.assertIn("local-pr-full-ci", self.text)
        self.assertIn("calls `bash ci/full-ci.sh`", self.text)
        self.assertIn("not PR #13 pre-merge simulation", self.text)
        self.assertIn("fixed base or head SHA", self.text)
        self.assertIn("rejects a dirty worktree", self.text)
        self.assertIn("verifies its `HEAD` equals", self.text)
        self.assertIn("`.act/workflows/local-act-pr.yml`", self.text)

    def test_docs_name_every_complete_local_ci_product_gate(self) -> None:
        for statement in (
            "six-module backend reactor",
            "Maven Checkstyle",
            "Helm smoke",
            "admin-web typecheck, lint, format, unit coverage, P0 E2E, and build",
            "mobile analyze, full test suite, and R4 release gates",
            "release/docs/schema/M006",
        ):
            self.assertIn(statement, self.text)

    def test_docs_keep_proxy_contexts_separate(self) -> None:
        self.assertIn("http://127.0.0.1:7890", self.text)
        self.assertIn("http://host.docker.internal:7890", self.text)
        self.assertIn("Do not commit proxy credentials", self.text)
        self.assertIn("TESTCONTAINERS_RYUK_DISABLED", self.text)
        self.assertIn("TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal", self.text)
        self.assertIn("PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT=180000", self.text)

    def test_docs_record_package_download_mirrors_and_non_mirrored_sources(self) -> None:
        for statement in (
            "https://mirrors.cloud.tencent.com/npm/",
            "https://npmmirror.com/mirrors/playwright",
            "https://maven.aliyun.com/repository/central",
            "https://pub.flutter-io.cn",
            "https://storage.flutter-io.cn",
            "COREPACK_NPM_REGISTRY",
            "Docker images, the act runner image, GitHub Actions source, and setup-action SDK downloads are not redirected to public mirrors.",
        ):
            self.assertIn(statement, self.text)

    def test_docs_clear_inherited_secrets_before_act_without_printing_values(self) -> None:
        for exact_name in (
            "GITHUB_TOKEN",
            "GH_TOKEN",
            "NPM_TOKEN",
            "CODECOV_TOKEN",
            "SSY_API_KEY",
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "AZURE_OPENAI_API_KEY",
            "GOOGLE_API_KEY",
            "MISTRAL_AI_API_KEY",
            "OPENAI_BASE_URL",
            "ANTHROPIC_BASE_URL",
            "AZURE_OPENAI_ENDPOINT",
            "SPRING_APPLICATION_JSON",
            "DATABASE_URL",
            "JDBC_DATABASE_URL",
            "JDBC_URL",
            "REDIS_URL",
            "REDIS_HOST",
            "REDIS_PORT",
            "REDIS_PASSWORD",
            "PGPASSWORD",
            "PGPASSFILE",
            "PGSERVICE",
            "PGSERVICEFILE",
            "PGHOST",
            "PGHOSTADDR",
            "PGPORT",
            "PGDATABASE",
            "PGUSER",
            "PGOPTIONS",
            "JAVA_TOOL_OPTIONS",
            "_JAVA_OPTIONS",
            "JDK_JAVA_OPTIONS",
            "MAVEN_OPTS",
            "MAVEN_ARGS",
            "MAVEN_USER_HOME",
            "MAVEN_EXT_CLASS_PATH",
            "M2_HOME",
            "CLASSPATH",
            "KUBECONFIG",
            "KUBE_TOKEN",
            "KUBERNETES_SERVICE_HOST",
            "KUBERNETES_SERVICE_PORT",
            "HELM_REGISTRY_CONFIG",
            "HELM_REPOSITORY_CONFIG",
            "ADMIN_ACCESS_TOKEN",
            "ADMIN_PASSWORD",
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY",
            "AWS_SESSION_TOKEN",
            "AWS_PROFILE",
            "AWS_SHARED_CREDENTIALS_FILE",
            "GOOGLE_APPLICATION_CREDENTIALS",
            "AZURE_CLIENT_SECRET",
            "DOCKER_HOST",
            "DOCKER_CONTEXT",
            "DOCKER_TLS_VERIFY",
            "DOCKER_CERT_PATH",
            "DOCKER_AUTH_CONFIG",
            "REGISTRY_AUTH_FILE",
            "HTTP_PROXY",
            "HTTPS_PROXY",
            "ALL_PROXY",
            "NO_PROXY",
            "TESTCONTAINERS_RYUK_DISABLED",
        ):
            self.assertIn(f"'{exact_name}'", self.text)
        for prefix in (
            "'BABY_TALK_'",
            "'SPRING_'",
            "'MVNW_'",
            "'DB_'",
            "'JWT_'",
            "'MINIO_'",
            "'KUBE_'",
            "'KUBERNETES_'",
            "'HELM_'",
            "'TESTCONTAINERS_'",
        ):
            self.assertIn(prefix, self.text)
        for suffix in (
            "'_API_KEY'",
            "'_API_TOKEN'",
            "'_PASSWORD'",
            "'_SECRET'",
            "'_PRIVATE_KEY'",
        ):
            self.assertIn(suffix, self.text)
        self.assertIn("Get-ChildItem Env:", self.text)
        self.assertIn('Remove-Item -LiteralPath "Env:$($entry.Name)"', self.text)
        sanitizer = self.text.index("$unsafeEnvironmentNames")
        wrapper = self.text.index("bash ci/run-act-pr.sh")
        self.assertLess(sanitizer, wrapper)
        self.assertIn("does not print removed values", self.text)

    def test_docs_clear_proxy_before_setting_safe_proxy_and_force_ryuk(self) -> None:
        proxy_clear = self.text.index("'HTTP_PROXY'")
        safe_proxy = self.text.index("$env:HTTP_PROXY = 'http://127.0.0.1:7890'")
        self.assertLess(proxy_clear, safe_proxy)
        ryuk_clear = self.text.index("'TESTCONTAINERS_RYUK_DISABLED'")
        ryuk_set = self.text.index(
            "$env:TESTCONTAINERS_RYUK_DISABLED = 'false'"
        )
        self.assertLess(ryuk_clear, ryuk_set)
        self.assertIn(
            "Environment-name comparison is case-insensitive",
            self.text,
        )
        self.assertIn(
            "`.actrc` explicitly passes `TESTCONTAINERS_RYUK_DISABLED=false`",
            self.text,
        )

    def test_docs_record_act_boundaries_and_sha_strategy(self) -> None:
        for statement in (
            "omits\nboth `pull_request.base.sha` and `pull_request.head.sha`",
            "SHA-bound runtime evidence records all three values",
            "`macos-latest` cannot run in Windows/Linux act containers",
            "ACT_UNSUPPORTED_BUT_LOCAL_EQUIVALENT_VERIFIED",
            "does not prove GitHub queueing, branch protection, required checks, or hosted-runner behavior",
        ):
            self.assertIn(statement, self.text)

    def test_docs_explain_ignored_exact_sha_evidence(self) -> None:
        for statement in (
            "`docs/superpowers/reports/local-ci-<full-head-sha>.md`",
            "is intentionally ignored",
            "committing the report would change the SHA it names",
            "The full SHA-bound evidence must be copied into the draft PR description",
        ):
            self.assertIn(statement, self.text)

    def test_docs_record_lefthook_enforcement_and_bypass_limits(self) -> None:
        for statement in (
            "Lefthook is a local convenience gate.",
            "`git push --no-verify` can bypass the pre-push hook.",
            "Any pre-push bypass must be disclosed in writing in the PR.",
            "Lefthook is not equivalent to server-side branch protection.",
            "Manual merge review must inspect the SHA-bound local CI report.",
            "GitHub-hosted Actions: **INTENTIONALLY DISABLED**",
            "Server-side required checks: **NOT CONFIGURED**",
        ):
            self.assertIn(statement, self.text)


class LefthookConfigurationContractTest(unittest.TestCase):
    def test_pre_push_runs_only_full_local_ci_without_filters(self) -> None:
        self.assertTrue(LEFTHOOK_CONFIG.is_file(), "lefthook.yml must exist")
        self.assertEqual(
            LEFTHOOK_CONFIG.read_text(encoding="utf-8"),
            "pre-push:\n"
            "  commands:\n"
            "    full-local-ci:\n"
            "      run: bash ci/full-ci.sh\n"
            '      fail_text: "Full local CI failed; push blocked."\n',
        )

        lowered = LEFTHOOK_CONFIG.read_text(encoding="utf-8").lower()
        for forbidden_key in (
            "glob:",
            "files:",
            "skip:",
            "exclude:",
            "only:",
            "root:",
        ):
            self.assertNotIn(forbidden_key, lowered)


class WindowsActCopyCompatibilityContractTest(unittest.TestCase):
    def test_workflow_node_runtime_matches_pinned_pnpm(self) -> None:
        package = json.loads(PACKAGE_JSON.read_text(encoding="utf-8"))
        self.assertEqual(package["packageManager"], "pnpm@11.1.1")
        workflow = CI_WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("node-version: '22'", workflow)
        self.assertNotIn("node-version: '20'", workflow)

    def test_pnpm_allows_only_the_reviewed_esbuild_script(self) -> None:
        self.assertEqual(
            PNPM_WORKSPACE.read_text(encoding="utf-8"),
            "packages:\n"
            "  - admin-web\n"
            "\n"
            "allowBuilds:\n"
            "  esbuild@0.21.5: true\n",
        )

    def test_playwright_install_timeout_covers_local_runner_downloads(self) -> None:
        workflow = CI_WORKFLOW.read_text(encoding="utf-8")
        self.assertIn(
            "- name: Install Playwright Chromium\n"
            "        timeout-minutes: 45\n"
            "        run: pnpm --dir admin-web exec playwright install chromium --with-deps",
            workflow,
        )

    def test_workflow_pins_audited_helm_version(self) -> None:
        workflow = CI_WORKFLOW.read_text(encoding="utf-8")
        self.assertIn(
            "- name: Install Helm\n"
            "        uses: azure/setup-helm@v4\n"
            "        with:\n"
            "          version: v4.1.4",
            workflow,
        )

    def test_backend_mirror_wrapper_is_invoked_through_bash(self) -> None:
        text = CI_WORKFLOW.read_text(encoding="utf-8")
        self.assertNotIn("./backend/mvnw", text)
        self.assertEqual(text.count("bash ci/maven.sh"), 2)
        backend_test = BACKEND_TEST_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('"$ROOT_DIR/ci/maven.sh"', backend_test)
        self.assertNotIn('\n"$BACKEND_DIR/mvnw"', backend_test)

    def test_shell_entrypoints_are_forced_to_lf(self) -> None:
        self.assertTrue(GITATTRIBUTES.is_file(), ".gitattributes must exist")
        lines = {
            line.strip()
            for line in GITATTRIBUTES.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        self.assertIn("*.sh text eol=lf", lines)
        self.assertIn("backend/mvnw text eol=lf", lines)

        for relative_path in (
            "ci/backend-test.sh",
            "ci/k8s-smoke.sh",
            "ci/mobile-analyze.sh",
            "ci/mobile-r4-release-gates.sh",
            "backend/mvnw",
        ):
            self.assertNotIn(
                b"\r\n",
                (REPO_ROOT / relative_path).read_bytes(),
                f"{relative_path} must survive act's Windows workspace copy as LF",
            )

    def test_isar_test_library_resolution_is_shared_and_host_abi_aware(self) -> None:
        consumers_with_calls = set()
        windows_library_mentions = set()

        for dart_file in MOBILE_TEST_ROOT.rglob("*.dart"):
            relative_path = dart_file.relative_to(MOBILE_TEST_ROOT).as_posix()
            text = dart_file.read_text(encoding="utf-8")
            self.assertNotIn("_resolveBundledIsarLibraryPath", text)

            if "resolveBundledIsarLibraryPath()" in text:
                consumers_with_calls.add(relative_path)
            if re.search(r"windows[\s\S]{0,100}isar\.dll", text):
                windows_library_mentions.add(relative_path)

        self.assertEqual(consumers_with_calls, set(ISAR_TEST_LIBRARY_CONSUMERS))
        self.assertEqual(
            windows_library_mentions,
            {
                "support/isar_test_library.dart",
                "support/isar_test_library_test.dart",
            },
        )

        for relative_path in ISAR_TEST_LIBRARY_CONSUMERS:
            text = (MOBILE_TEST_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertEqual(text.count("isar_test_library.dart';"), 1, relative_path)
            self.assertEqual(
                text.count("resolveBundledIsarLibraryPath()"),
                1,
                relative_path,
            )


class DownloadSourceContractTest(unittest.TestCase):
    def test_repository_ci_pins_verified_china_package_mirrors(self) -> None:
        self.assertEqual(
            NPMRC.read_text(encoding="utf-8"),
            "registry=https://mirrors.cloud.tencent.com/npm/\n",
        )

        source_text = DOWNLOAD_SOURCES.read_text(encoding="utf-8")
        self.assertIn(
            "https://mirrors.cloud.tencent.com/npm/",
            source_text,
        )
        self.assertIn("COREPACK_NPM_REGISTRY", source_text)
        self.assertIn(
            "https://npmmirror.com/mirrors/playwright",
            source_text,
        )
        self.assertIn("https://pub.flutter-io.cn", source_text)
        self.assertIn("https://storage.flutter-io.cn", source_text)

        settings_text = MAVEN_SETTINGS.read_text(encoding="utf-8")
        self.assertIn("<mirrorOf>central</mirrorOf>", settings_text)
        self.assertIn("https://maven.aliyun.com/repository/central", settings_text)
        self.assertNotIn("<mirrorOf>*</mirrorOf>", settings_text)

        for workflow_name in ("ci.yml", "admin-web.yml"):
            workflow_text = (
                REPO_ROOT / ".github" / "workflows" / workflow_name
            ).read_text(encoding="utf-8")
            self.assertIn(
                "PLAYWRIGHT_DOWNLOAD_HOST: https://npmmirror.com/mirrors/playwright",
                workflow_text,
            )
            self.assertIn(
                "COREPACK_NPM_REGISTRY: https://mirrors.cloud.tencent.com/npm/",
                workflow_text,
            )

        admin_dockerfile = (REPO_ROOT / "admin-web" / "Dockerfile").read_text(
            encoding="utf-8"
        )
        self.assertIn("COPY .npmrc ./", admin_dockerfile)
        self.assertIn(
            "COREPACK_NPM_REGISTRY=https://mirrors.cloud.tencent.com/npm/",
            admin_dockerfile,
        )

    def test_full_ci_routes_maven_and_flutter_through_project_sources(self) -> None:
        full_ci = (REPO_ROOT / "ci" / "full-ci.sh").read_text(encoding="utf-8")
        backend_test = BACKEND_TEST_SCRIPT.read_text(encoding="utf-8")
        mobile_analyze = (REPO_ROOT / "ci" / "mobile-analyze.sh").read_text(
            encoding="utf-8"
        )
        mobile_r4 = (REPO_ROOT / "ci" / "mobile-r4-release-gates.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('source "$repo_root/ci/download-sources.sh"', full_ci)
        self.assertIn('bash ci/maven.sh', full_ci)
        self.assertIn('"$ROOT_DIR/ci/maven.sh"', backend_test)
        self.assertIn('download-sources.sh', mobile_analyze)
        self.assertIn('download-sources.sh', mobile_r4)

        self.assertTrue(MAVEN_WRAPPER.is_file())
        self.assertTrue(os.access(MAVEN_WRAPPER, os.X_OK))
        wrapper_text = MAVEN_WRAPPER.read_text(encoding="utf-8")
        self.assertIn('backend/.mvn/settings.xml', wrapper_text)
        self.assertIn('exec bash "$repo_root/backend/mvnw"', wrapper_text)


if __name__ == "__main__":
    unittest.main()
