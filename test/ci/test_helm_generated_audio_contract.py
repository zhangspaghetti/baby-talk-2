import subprocess
import unittest
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
CHART = REPO_ROOT / "deploy" / "helm" / "babytalk-app"
QA_VALUES = CHART / "values-kind-qa.yaml"
OWNER_KEY_OVERRIDE = (
    "secret.BABY_TALK_PRACTICE_DISCOVERY_OWNER_KEY_SECRET="
    "contract-test-only-owner-key-32-bytes"
)


class HelmGeneratedAudioContractTest(unittest.TestCase):
    def test_qa_renders_formal_dashscope_audio_only_into_app_api(self) -> None:
        documents = self._render("-f", str(QA_VALUES), "--set-string", OWNER_KEY_OVERRIDE)
        app_api = self._deployment(documents, "app-api")
        environment = {
            item["name"]: item for item in app_api["spec"]["template"]["spec"]["containers"][0]["env"]
        }

        expected_values = {
            "BABY_TALK_GENERATED_AUDIO_ENABLED": "true",
            "BABY_TALK_GENERATED_AUDIO_PROVIDER_MODE": "dashscope",
            "BABY_TALK_GENERATED_AUDIO_TIMEOUT": "8s",
            "BABY_TALK_GENERATED_AUDIO_MAX_BYTES": "524288",
            "BABY_TALK_GENERATED_AUDIO_RESPONSE_MAX_BYTES": "16384",
            "BABY_TALK_GENERATED_AUDIO_VOICE_VERSION": "generated-dashscope-qwen-audio-v1",
            "BABY_TALK_GENERATED_AUDIO_FORMAT": "mp3",
            "BABY_TALK_GENERATED_AUDIO_BASE_URL": (
                "https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer"
            ),
            "BABY_TALK_GENERATED_AUDIO_API_KEY_ENVIRONMENT_VARIABLE": (
                "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY"
            ),
            "BABY_TALK_GENERATED_AUDIO_MODEL": "qwen-audio-3.0-tts-flash",
            "BABY_TALK_GENERATED_AUDIO_VOICE": "loongeva_v3.6",
            "BABY_TALK_GENERATED_AUDIO_PROVIDER_PROFILE": "qa-formal-v1",
            "BABY_TALK_GENERATED_AUDIO_ALLOWED_DOWNLOAD_HOSTS": (
                "dashscope-result-bj.oss-cn-beijing.aliyuncs.com"
            ),
        }
        for name, value in expected_values.items():
            self.assertEqual(value, environment[name]["value"], name)

        credential = environment["BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY"]
        self.assertNotIn("value", credential)
        self.assertEqual(
            "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY",
            credential["valueFrom"]["secretKeyRef"]["key"],
        )
        for component in ("admin-api", "admin-web", "gateway"):
            deployment = self._deployment(documents, component)
            rendered = yaml.safe_dump(deployment)
            self.assertNotIn("BABY_TALK_GENERATED_AUDIO_", rendered)
            self.assertNotIn("BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY", rendered)

    def test_default_chart_keeps_generated_audio_disabled(self) -> None:
        app_api = self._deployment(self._render(), "app-api")
        environment = {
            item["name"]: item for item in app_api["spec"]["template"]["spec"]["containers"][0]["env"]
        }
        self.assertEqual("false", environment["BABY_TALK_GENERATED_AUDIO_ENABLED"]["value"])
        self.assertEqual("disabled", environment["BABY_TALK_GENERATED_AUDIO_PROVIDER_MODE"]["value"])
        self.assertNotIn("BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY", environment)

    def test_invalid_dashscope_values_fail_closed_at_render_time(self) -> None:
        cases = (
            ("generatedAudio.enabled=false",),
            ("generatedAudio.endpoint=http://dashscope.aliyuncs.com/tts",),
            (
                "generatedAudio.endpoint=https://attacker.invalid/api/v1/services/audio/tts/SpeechSynthesizer",
            ),
            ("generatedAudio.allowedDownloadHosts[0]=*.aliyuncs.com",),
            (
                "generatedAudio.apiKeyEnvironmentVariable="
                "BABY_TALK_AI_PROVIDER_UNCONFIGURED_API_KEY",
            ),
        )
        for values in cases:
            args = ["-f", str(QA_VALUES), "--set-string", OWNER_KEY_OVERRIDE]
            for value in values:
                args.extend(("--set-string", value))
            result = self._helm(*args)
            self.assertNotEqual(0, result.returncode, value)

    def _render(self, *args: str) -> list[dict]:
        result = self._helm(*args)
        self.assertEqual(0, result.returncode, result.stderr)
        return [document for document in yaml.safe_load_all(result.stdout) if document]

    def _helm(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["helm", "template", "generated-audio-contract", str(CHART), *args],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def _deployment(self, documents: list[dict], component: str) -> dict:
        matches = [
            document
            for document in documents
            if document.get("kind") == "Deployment"
            and document.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/component")
            == component
        ]
        self.assertEqual(1, len(matches), component)
        return matches[0]


if __name__ == "__main__":
    unittest.main()
