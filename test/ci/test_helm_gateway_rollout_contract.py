import subprocess
import unittest
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
CHART = REPO_ROOT / "deploy" / "helm" / "babytalk-app"


class HelmGatewayRolloutContractTest(unittest.TestCase):
    def test_gateway_rolls_when_shared_config_changes(self) -> None:
        first = self._render_gateway("http://127.0.0.1:3001")
        second = self._render_gateway("http://127.0.0.1:3003")

        first_annotations = first["spec"]["template"]["metadata"]["annotations"]
        second_annotations = second["spec"]["template"]["metadata"]["annotations"]

        self.assertRegex(first_annotations["checksum/config"], r"^[0-9a-f]{64}$")
        self.assertRegex(first_annotations["checksum/secret"], r"^[0-9a-f]{64}$")
        self.assertNotEqual(
            first_annotations["checksum/config"],
            second_annotations["checksum/config"],
        )
        self.assertEqual(
            first_annotations["checksum/secret"],
            second_annotations["checksum/secret"],
        )

    def _render_gateway(self, admin_web_origin: str) -> dict:
        result = subprocess.run(
            [
                "helm",
                "template",
                "gateway-rollout-contract",
                str(CHART),
                "--show-only",
                "templates/deployment.yaml",
                "--set-string",
                f"config.BABY_TALK_ADMIN_WEB_ORIGIN={admin_web_origin}",
            ],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        deployments = [
            document
            for document in yaml.safe_load_all(result.stdout)
            if document
            and document.get("kind") == "Deployment"
            and document.get("metadata", {})
            .get("labels", {})
            .get("app.kubernetes.io/component")
            == "gateway"
        ]
        self.assertEqual(1, len(deployments))
        return deployments[0]


if __name__ == "__main__":
    unittest.main()
