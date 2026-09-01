import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
QA_UP_HELM = REPO_ROOT / "scripts" / "qa-up-helm.sh"
GIT_BASH = (
    Path(os.environ.get("ProgramFiles", "C:/Program Files"))
    / "Git"
    / "usr"
    / "bin"
    / "bash.exe"
)
BASH = str(GIT_BASH) if GIT_BASH.exists() else (shutil.which("bash") or "bash")


class QaUpHelmContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.script = QA_UP_HELM.read_text(encoding="utf-8")

    def test_candidate_mapping_covers_every_application_image(self) -> None:
        for mapping in (
            "app-api=appApi",
            "admin-api=adminApi",
            "admin-web=adminWeb",
            "gateway=gateway",
            "db-migration=dbMigration",
        ):
            with self.subTest(mapping=mapping):
                self.assertIn(f'"{mapping}"', self.script)
        self.assertIn(
            'APP_IMAGE_TAG_ARGS+=(--set-string "${value_key}.image.tag=$QA_CANDIDATE_ID")',
            self.script,
        )

    def test_candidate_images_are_preseeded_into_kind(self) -> None:
        self.assertIn('helm template "$APP_RELEASE"', self.script)
        self.assertIn('CANDIDATE_IMAGE_REFS+=("$component_image_ref")', self.script)
        self.assertIn('for image_ref in "${CANDIDATE_IMAGE_REFS[@]}"', self.script)
        self.assertIn('docker image inspect "$image_ref"', self.script)
        self.assertIn('docker save "$image_ref"', self.script)
        self.assertIn("ctr -n k8s.io images import", self.script)

    def test_old_kind_images_are_cleaned_only_after_successful_rollout(self) -> None:
        rollout_marker = 'echo "    rollout: ok"'
        cleanup_marker = 'echo "==> [images] removing superseded candidate images from kind..."'

        self.assertIn(cleanup_marker, self.script)
        self.assertLess(self.script.index(rollout_marker), self.script.index(cleanup_marker))
        self.assertIn('[[ "$image_ref" == "$current_image_ref" ]]', self.script)
        self.assertIn('if ! kind_image_refs="$(', self.script)
        self.assertIn(
            'ctr -n k8s.io images rm "$image_ref"',
            self.script,
        )

    def test_admin_web_port_override_is_forwarded_to_helm_cors_origin(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            isolated_root = Path(temp_dir)
            isolated_script = isolated_root / "scripts" / "qa-up-helm.sh"
            isolated_script.parent.mkdir(parents=True)
            shutil.copy2(QA_UP_HELM, isolated_script)
            (
                isolated_root
                / "deploy"
                / "helm"
                / "babytalk-app"
                / "values-kind-qa-secrets.yaml"
            ).parent.mkdir(parents=True)
            (
                isolated_root
                / "deploy"
                / "helm"
                / "babytalk-app"
                / "values-kind-qa-secrets.yaml"
            ).touch()
            (isolated_root / "mobile").mkdir()
            (isolated_root / "mobile" / "pubspec.yaml").write_text(
                "version: 1.2.3+4\n",
                encoding="utf-8",
            )

            fake_bin = isolated_root / "fake-bin"
            fake_bin.mkdir()
            helm_log = isolated_root / "helm.log"
            self._write_shim(
                fake_bin / "helm",
                """\
printf '%s\n' "$*" >> "$FAKE_HELM_LOG"
if [[ "${1:-}" == "template" ]] \
    || [[ "${1:-}" == "upgrade" && "$*" == *"babytalk-qa-app"* ]]; then
  if [[ "$*" != *"--set-string config.BABY_TALK_ADMIN_WEB_ORIGIN=http://127.0.0.1:3003"* ]] \
      || [[ "$*" != *"--set-string candidate.id=m2-test"* ]]; then
    exit 64
  fi
fi
if [[ "${1:-}" == "template" ]]; then
  printf '%s\n' \
    'image: "babytalk/app-api:m2-test"' \
    'image: "babytalk/admin-api:m2-test"' \
    'image: "babytalk/admin-web:m2-test"' \
    'image: "babytalk/gateway:m2-test"' \
    'image: "babytalk/db-migration:m2-test"'
fi
""",
            )
            self._write_shim(fake_bin / "docker", "exit 1\n")
            self._write_shim(fake_bin / "kubectl", "exit 0\n")
            self._write_shim(fake_bin / "flutter", "exit 0\n")
            self._write_shim(
                fake_bin / "adb",
                """\
if [[ "${1:-}" == "devices" ]]; then
  printf 'List of devices attached\n\n'
fi
""",
            )
            self._write_shim(
                fake_bin / "curl",
                """\
if [[ "$*" == *"/qa/candidate-compatibility"* ]]; then
  printf '%s\\n' '{"candidateId":"m2-test","requiredMigrationVersion":"38","status":"compatible"}'
fi
""",
            )
            self._write_shim(fake_bin / "pkill", "exit 0\n")
            self._write_shim(fake_bin / "sleep", "exit 0\n")

            env = os.environ.copy()
            env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"
            env["FAKE_HELM_LOG"] = helm_log.as_posix()
            env["QA_ADMIN_WEB_LOCAL_PORT"] = "3003"
            env["QA_CANDIDATE_ID"] = "m2-test"
            result = subprocess.run(
                [BASH, str(isolated_script)],
                cwd=isolated_root,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(0, result.returncode, result.stderr)
            invocations = helm_log.read_text(encoding="utf-8").splitlines()
            expected_override = (
                "--set-string "
                "config.BABY_TALK_ADMIN_WEB_ORIGIN=http://127.0.0.1:3003"
            )
            template_invocation = next(
                invocation
                for invocation in invocations
                if invocation.startswith("template ")
            )
            upgrade_invocation = next(
                invocation
                for invocation in invocations
                if invocation.startswith("upgrade ")
                and "babytalk-qa-app" in invocation
            )
            self.assertIn(expected_override, template_invocation)
            self.assertIn(expected_override, upgrade_invocation)

    def _write_shim(self, path: Path, body: str) -> None:
        path.write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\n" + body,
            encoding="utf-8",
        )
        path.chmod(0o755)


if __name__ == "__main__":
    unittest.main()
