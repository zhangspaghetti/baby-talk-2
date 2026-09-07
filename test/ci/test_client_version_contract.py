import os
import shutil
import subprocess
import unittest
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
APP_VALUES = REPO_ROOT / "deploy" / "helm" / "babytalk-app" / "values.yaml"
APP_CHART = REPO_ROOT / "deploy" / "helm" / "babytalk-app"
APP_CONFIG = REPO_ROOT / "backend" / "app-api" / "src" / "main" / "resources" / "application.yml"
E2E_SCRIPT = REPO_ROOT / "scripts" / "verify-e2e.sh"
MIN_VERSION = "1.3.0"
BASH = shutil.which("bash") or "bash"
HELM_AGENTIC_OWNER_KEY = "test-only-owner-key-for-helm-contract-32"
HELM_OVERLAYS = (
    ("default", None),
    ("kind", APP_CHART / "values-kind.yaml"),
    ("qa", APP_CHART / "values-kind-qa.yaml"),
    ("production", APP_CHART / "values-production.yaml"),
)


class ClientVersionContractTest(unittest.TestCase):
    def test_application_fallback_is_new_mobile_contract(self) -> None:
        self.assertIn(
            "min-supported-version: ${BABY_TALK_MIN_SUPPORTED_VERSION:1.3.0}",
            APP_CONFIG.read_text(encoding="utf-8"),
        )

    def test_helm_default_and_deployment_overlays_render_new_mobile_contract(self) -> None:
        values = yaml.safe_load(APP_VALUES.read_text(encoding="utf-8"))
        self.assertEqual(MIN_VERSION, values["config"]["BABY_TALK_MIN_SUPPORTED_VERSION"])

        for overlay_name, overlay in HELM_OVERLAYS:
            overlay_args = []
            if overlay is not None:
                overlay_args.extend(["-f", str(overlay)])
            if overlay_name in {"qa", "production"}:
                overlay_args.extend([
                    "--set-string",
                    f"secret.BABY_TALK_PRACTICE_DISCOVERY_OWNER_KEY_SECRET={HELM_AGENTIC_OWNER_KEY}",
                ])
            linted = subprocess.run(
                ["helm", "lint", str(APP_CHART), "-f", str(APP_VALUES), *overlay_args],
                cwd=REPO_ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, linted.returncode, f"{overlay_name}: {linted.stderr}")

            command = [
                "helm", "template", f"babytalk-app-{overlay_name}", str(APP_CHART),
                "-f", str(APP_VALUES), *overlay_args,
            ]
            rendered = subprocess.run(
                command,
                cwd=REPO_ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, rendered.returncode, f"{overlay_name}: {rendered.stderr}")
            configmaps = [
                document
                for document in yaml.safe_load_all(rendered.stdout)
                if document and document.get("kind") == "ConfigMap"
            ]
            self.assertTrue(configmaps, overlay_name)
            self.assertIn(
                MIN_VERSION,
                [
                    configmap.get("data", {}).get("BABY_TALK_MIN_SUPPORTED_VERSION")
                    for configmap in configmaps
                ],
                overlay_name,
            )

    def test_e2e_default_uses_client_version_accepted_by_deployable_contract(self) -> None:
        default_environment = os.environ.copy()
        default_environment.pop("APP_VERSION", None)
        default_version = subprocess.run(
            [BASH, str(E2E_SCRIPT), "--print-app-version"],
            cwd=REPO_ROOT,
            env=default_environment,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, default_version.returncode, default_version.stderr)
        self.assertEqual(MIN_VERSION, default_version.stdout.strip())

        override_environment = default_environment | {"APP_VERSION": "9.9.9"}
        override_version = subprocess.run(
            [BASH, str(E2E_SCRIPT), "--print-app-version"],
            cwd=REPO_ROOT,
            env=override_environment,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, override_version.returncode, override_version.stderr)
        self.assertEqual("9.9.9", override_version.stdout.strip())


if __name__ == "__main__":
    unittest.main()
