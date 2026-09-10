import subprocess
import unittest
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
CHART = REPO_ROOT / "deploy" / "helm" / "babytalk-app"
QA_VALUES = CHART / "values-kind-qa.yaml"
AUTHORIZED_EVIDENCE_SIZE_BYTES = 70_735_109
ADMIN_UPLOAD_LIMIT_BYTES = 100 * 1024 * 1024


class HelmAdminWebIngestionContractTest(unittest.TestCase):
    def test_qa_admin_web_renders_body_limit_above_authorized_evidence_size(
        self,
    ) -> None:
        result = subprocess.run(
            [
                "helm",
                "template",
                "admin-ingestion-contract",
                str(CHART),
                "-f",
                str(QA_VALUES),
                "--set-string",
                (
                    "secret.BABY_TALK_PRACTICE_DISCOVERY_OWNER_KEY_SECRET="
                    "contract-test-only-owner-key-32-bytes"
                ),
                "--show-only",
                "templates/configmap.yaml",
            ],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)

        config_maps = [
            document
            for document in yaml.safe_load_all(result.stdout)
            if document
            and document.get("kind") == "ConfigMap"
            and document.get("metadata", {})
            .get("labels", {})
            .get("app.kubernetes.io/component")
            == "admin-web"
        ]
        self.assertEqual(1, len(config_maps))
        nginx_config = config_maps[0]["data"]["default.conf"]

        self.assertIn("client_max_body_size 100m;", nginx_config)
        self.assertGreater(ADMIN_UPLOAD_LIMIT_BYTES, AUTHORIZED_EVIDENCE_SIZE_BYTES)


if __name__ == "__main__":
    unittest.main()
