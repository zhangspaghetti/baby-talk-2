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


class ClientVersionContractTest(unittest.TestCase):
    def test_application_fallback_is_new_mobile_contract(self) -> None:
        self.assertIn(
            "min-supported-version: ${BABY_TALK_MIN_SUPPORTED_VERSION:1.3.0}",
            APP_CONFIG.read_text(encoding="utf-8"),
        )

    def test_helm_default_renders_new_mobile_contract(self) -> None:
        values = yaml.safe_load(APP_VALUES.read_text(encoding="utf-8"))
        self.assertEqual(MIN_VERSION, values["config"]["BABY_TALK_MIN_SUPPORTED_VERSION"])

        rendered = subprocess.run(
            ["helm", "template", "babytalk-app", str(APP_CHART), "-f", str(APP_VALUES)],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, rendered.returncode, rendered.stderr)
        configmaps = [
            document
            for document in yaml.safe_load_all(rendered.stdout)
            if document and document.get("kind") == "ConfigMap"
        ]
        self.assertTrue(configmaps)
        self.assertIn(
            MIN_VERSION,
            [
                configmap.get("data", {}).get("BABY_TALK_MIN_SUPPORTED_VERSION")
                for configmap in configmaps
            ],
        )

    def test_e2e_default_uses_client_version_accepted_by_deployable_contract(self) -> None:
        self.assertIn('APP_VERSION="${APP_VERSION:-1.3.0}"', E2E_SCRIPT.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
