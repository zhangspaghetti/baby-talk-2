import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


class FullCiEnvironmentProcessTest(unittest.TestCase):
    def test_child_receives_sanitized_environment_owned_kubeconfig_and_ryuk(self) -> None:
        status_before = _git_status()
        with tempfile.TemporaryDirectory(prefix="full_ci_host_env_") as temp_dir:
            hostile_kubeconfig = Path(temp_dir) / "host-kubeconfig"
            hostile_pgpass = Path(temp_dir) / "pgpass"
            hostile_kubeconfig.write_text("host production kubeconfig", encoding="utf-8")
            hostile_pgpass.write_text("prod:5432:*:admin:secret", encoding="utf-8")

            env = os.environ.copy()
            injected = {
                "BABY_TALK_DB_URL": "jdbc:postgresql://prod.example/babytalk",
                "BABY_TALK_DB_USERNAME": "prod-user",
                "BABY_TALK_DB_PASSWORD": "prod-password",
                "BABY_TALK_AI_API_KEY": "prod-ai-key",
                "BABY_TALK_EMBEDDING_API_KEY": "prod-embedding-key",
                "BABY_TALK_MINIO_ACCESS_KEY": "prod-minio-access",
                "BABY_TALK_MINIO_SECRET_KEY": "prod-minio-secret",
                "BABY_TALK_ADMIN_JWT_SECRET": "prod-admin-jwt",
                "BABY_TALK_CONSUMER_JWT_SECRET": "prod-consumer-jwt",
                "BABY_TALK_PRACTICE_DISCOVERY_OWNER_KEY_SECRET": "prod-owner-key",
                "BABY_TALK_MENTOR_PROVIDER_MODE": "openai",
                "BABY_TALK_REDIS_HOST": "prod-redis.example",
                "BABY_TALK_UNRECOGNIZED_HOST_OVERRIDE": "prod-custom.example",
                "SPRING_DATASOURCE_URL": "jdbc:postgresql://prod.example/spring",
                "SPRING_DATASOURCE_USERNAME": "spring-prod-user",
                "SPRING_DATASOURCE_PASSWORD": "spring-prod-password",
                "SPRING_AI_OPENAI_API_KEY": "spring-prod-ai-key",
                "SPRING_AI_OPENAI_BASE_URL": "https://prod-ai.example/v1",
                "SPRING_CONFIG_LOCATION": "https://prod.example/application.yml",
                "SPRING_CONFIG_IMPORT": "optional:configserver:https://prod.example",
                "SPRING_PROFILES_ACTIVE": "production",
                "SPRING_UNRECOGNIZED_HOST_OVERRIDE": "prod-spring.example",
                "SPRING_APPLICATION_JSON": json.dumps(
                    {"spring": {"datasource": {"url": "jdbc:postgresql://prod.example/json"}}}
                ),
                "DATABASE_URL": "postgresql://prod.example/babytalk",
                "JDBC_DATABASE_URL": "jdbc:postgresql://prod.example/jdbc",
                "REDIS_URL": "redis://prod-redis.example:6379",
                "DB_HOST": "prod-db.example",
                "DB_PASSWORD": "prod-generic-password",
                "JDBC_URL": "jdbc:postgresql://prod.example/generic",
                "MINIO_ENDPOINT": "https://prod-minio.example",
                "MINIO_ACCESS_KEY": "prod-generic-minio-access",
                "MINIO_SECRET_KEY": "prod-generic-minio-secret",
                "JWT_SECRET": "prod-generic-jwt",
                "OPENAI_BASE_URL": "https://prod-openai.example/v1",
                "PGPASSWORD": "prod-pg-password",
                "PGPASSFILE": str(hostile_pgpass),
                "PGSERVICE": "production",
                "JAVA_TOOL_OPTIONS": "-Dhost.injected.java.tool.options=true",
                "_JAVA_OPTIONS": "-Dhost.injected.java.options=true",
                "JDK_JAVA_OPTIONS": "-Dhost.injected.jdk.options=true",
                "MAVEN_OPTS": "-Dhost.injected.maven.opts=true",
                "MAVEN_ARGS": "-Dhost.injected.maven.args=true",
                "MAVEN_USER_HOME": str(Path(temp_dir) / "host-maven-home"),
                "MAVEN_EXT_CLASS_PATH": str(Path(temp_dir) / "host-maven-extension.jar"),
                "M2_HOME": str(Path(temp_dir) / "host-maven-install"),
                "CLASSPATH": str(Path(temp_dir) / "host-injected.jar"),
                "MVNW_USERNAME": "prod-maven-user",
                "MVNW_PASSWORD": "prod-maven-password",
                "KUBECONFIG": str(hostile_kubeconfig),
                "KUBE_TOKEN": "prod-kube-token",
                "KUBE_CONTEXT": "production",
                "KUBERNETES_SERVICE_HOST": "prod-kube.example",
                "HELM_KUBEAPISERVER": "https://prod-kube.example",
                "DOCKER_HOST": "tcp://prod-docker.example:2376",
                "DOCKER_CONTEXT": "production",
                "TESTCONTAINERS_HOST_OVERRIDE": "prod-docker.example",
                "GITHUB_TOKEN": "prod-github-token",
                "GH_TOKEN": "prod-gh-token",
                "NPM_TOKEN": "prod-npm-token",
                "CODECOV_TOKEN": "prod-codecov-token",
                "TESTCONTAINERS_RYUK_DISABLED": "true",
            }
            env.update(injected)

            command = (
                "source ci/full-ci.sh; "
                "initialize_ci_environment; "
                "python3 test/ci/fixtures/full_ci_environment_probe.py"
            )
            result = subprocess.run(
                [_bash_executable(), "-c", command],
                cwd=REPO_ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout.strip().splitlines()[-1])
            self.assertEqual(payload["leaked_names"], [])
            self.assertEqual(payload["ryuk_disabled"], "false")
            self.assertIsNone(payload["testcontainers_host_override"])
            self.assertTrue(payload["kubeconfig_exists"])
            self.assertNotEqual(payload["kubeconfig"], str(hostile_kubeconfig))
            self.assertIn("apiVersion: v1", payload["kubeconfig_text"])
            self.assertIn("clusters: []", payload["kubeconfig_text"])
            self.assertEqual(
                payload["download_sources"],
                {
                    "corepack": "https://mirrors.cloud.tencent.com/npm/",
                    "flutter": "https://storage.flutter-io.cn",
                    "npm": "https://mirrors.cloud.tencent.com/npm/",
                    "playwright": "https://npmmirror.com/mirrors/playwright",
                    "pub": "https://pub.flutter-io.cn",
                },
            )
            self.assertFalse(Path(payload["kubeconfig"]).exists())
        self.assertEqual(_git_status(), status_before)

    def test_act_safe_testcontainers_host_override_is_retained(self) -> None:
        status_before = _git_status()
        env = os.environ.copy()
        env["TESTCONTAINERS_HOST_OVERRIDE"] = "host.docker.internal"
        command = (
            "source ci/full-ci.sh; "
            "initialize_ci_environment; "
            "python3 test/ci/fixtures/full_ci_environment_probe.py"
        )
        result = subprocess.run(
            [_bash_executable(), "-c", command],
            cwd=REPO_ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout.strip().splitlines()[-1])
        self.assertEqual(
            payload["testcontainers_host_override"], "host.docker.internal"
        )
        self.assertEqual(payload["ryuk_disabled"], "false")
        self.assertEqual(_git_status(), status_before)

    def test_cleanup_failure_is_reported_without_overwriting_gate_status(self) -> None:
        status_before = _git_status()
        command = (
            "source ci/full-ci.sh; "
            "initialize_ci_environment; "
            "python3 test/ci/fixtures/full_ci_environment_probe.py; "
            "rm() { command rm \"$@\"; "
            "printf '%s\\n' simulated-sensitive-path >&2; return 1; }; "
            "exit 23"
        )
        result = subprocess.run(
            [_bash_executable(), "-c", command],
            cwd=REPO_ROOT,
            env=os.environ.copy(),
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(
            result.stderr.strip(),
            "full-ci: failed to clean owned runtime resources",
        )
        payload = json.loads(result.stdout.strip().splitlines()[-1])
        self.assertTrue(payload["kubeconfig_exists"])
        self.assertFalse(Path(payload["kubeconfig"]).exists())
        self.assertEqual(_git_status(), status_before)

    def test_cleanup_failure_turns_success_into_failure(self) -> None:
        status_before = _git_status()
        command = (
            "source ci/full-ci.sh; "
            "initialize_ci_environment; "
            "python3 test/ci/fixtures/full_ci_environment_probe.py; "
            "rm() { command rm \"$@\"; "
            "printf '%s\\n' simulated-sensitive-path >&2; return 1; }"
        )
        result = subprocess.run(
            [_bash_executable(), "-c", command],
            cwd=REPO_ROOT,
            env=os.environ.copy(),
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(
            result.stderr.strip(),
            "full-ci: failed to clean owned runtime resources",
        )
        payload = json.loads(result.stdout.strip().splitlines()[-1])
        self.assertTrue(payload["kubeconfig_exists"])
        self.assertFalse(Path(payload["kubeconfig"]).exists())
        self.assertEqual(_git_status(), status_before)


def _bash_executable() -> str:
    if os.name == "nt":
        candidates = (
            Path(os.environ.get("ProgramFiles", r"C:\Program Files"))
            / "Git"
            / "bin"
            / "bash.exe",
            Path(os.environ.get("LOCALAPPDATA", ""))
            / "Programs"
            / "Git"
            / "bin"
            / "bash.exe",
        )
        for candidate in candidates:
            if candidate.is_file():
                return str(candidate)
    return shutil.which("bash") or "bash"


def _git_status() -> str:
    return subprocess.run(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout


if __name__ == "__main__":
    unittest.main()
