import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
ACTRC = REPO_ROOT / ".actrc"
EVENT_FIXTURE = REPO_ROOT / ".act" / "pull_request.json"
GITIGNORE = REPO_ROOT / ".gitignore"
LOCAL_CI_DOC = REPO_ROOT / "docs" / "development" / "local-ci.md"
LEFTHOOK_CONFIG = REPO_ROOT / "lefthook.yml"

RUNNER_IMAGE = (
    "ghcr.io/catthehacker/ubuntu:act-24.04@sha256:"
    "5d6a17640b25694988b9db5a4145537b9918e5430116b2cf90d84e837609b382"
)
ORIGIN_DEVELOP_SHA = "4f0b33462a0c7ca4b7f6f3ba0203ae776a9239cb"


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
                "--strict",
                "--rm",
            ],
        )
        joined = "\n".join(lines).lower()
        for forbidden in ("--secret", "--secret-file", "--bind", "--reuse"):
            self.assertNotIn(forbidden, joined)
        self.assertNotIn("7890", joined)

    def test_pull_request_fixture_matches_pr_13(self) -> None:
        self.assertTrue(EVENT_FIXTURE.is_file(), ".act/pull_request.json must exist")
        event = json.loads(EVENT_FIXTURE.read_text(encoding="utf-8"))

        self.assertEqual(event["action"], "synchronize")
        self.assertEqual(event["number"], 13)
        pull_request = event["pull_request"]
        self.assertEqual(pull_request["number"], 13)
        self.assertTrue(pull_request["draft"])
        self.assertEqual(pull_request["base"]["ref"], "Develop")
        self.assertEqual(pull_request["base"]["sha"], ORIGIN_DEVELOP_SHA)
        self.assertEqual(
            pull_request["base"]["repo"]["full_name"],
            "zhangspaghetti/baby-talk-2",
        )
        self.assertEqual(pull_request["head"]["ref"], "gsd/v0.1-milestone")
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
        self.assertNotIn("/.act/", lines)
        self.assertNotIn(".act/", lines)


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

    def test_docs_give_exact_listing_and_execution_commands(self) -> None:
        self.assertIn(
            "act -l pull_request `\n  -W .github/workflows/ci.yml `\n  -e .act/pull_request.json",
            self.text,
        )
        self.assertIn(
            "act pull_request `\n  -W .github/workflows/ci.yml `\n  -e .act/pull_request.json",
            self.text,
        )
        self.assertIn("release-closure-gate", self.text)
        self.assertIn("mobile-analyze", self.text)

    def test_docs_keep_proxy_contexts_separate(self) -> None:
        self.assertIn("http://127.0.0.1:7890", self.text)
        self.assertIn("http://host.docker.internal:7890", self.text)
        self.assertIn("Do not commit proxy credentials", self.text)
        self.assertIn("TESTCONTAINERS_RYUK_DISABLED", self.text)

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
        first_act = self.text.index("act -l pull_request")
        self.assertLess(sanitizer, first_act)
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
            "The tracked event fixture omits `pull_request.head.sha`",
            "runtime evidence records the exact checked-out HEAD SHA",
            "`macos-latest` cannot run in Windows/Linux act containers",
            "ACT_UNSUPPORTED_BUT_LOCAL_EQUIVALENT_VERIFIED",
            "does not prove GitHub queueing, branch protection, required checks, or hosted-runner behavior",
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


if __name__ == "__main__":
    unittest.main()
