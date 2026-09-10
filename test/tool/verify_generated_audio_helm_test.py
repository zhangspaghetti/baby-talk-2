import sys
import unittest
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tool"))

import verify_generated_audio_helm as verifier  # noqa: E402


class GeneratedAudioHelmVerifierTest(unittest.TestCase):
    def test_repository_profiles_satisfy_generated_audio_contract(self) -> None:
        verifier.verify_repository(REPO_ROOT)

    def test_rejects_direct_credential_value_and_non_app_api_exposure(self) -> None:
        manifest = verifier.render_qa(REPO_ROOT)
        documents = list(yaml.safe_load_all(manifest))
        app_api = next(
            document
            for document in documents
            if document
            and document.get("kind") == "Deployment"
            and document.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/component")
            == "app-api"
        )
        environment = app_api["spec"]["template"]["spec"]["containers"][0]["env"]
        credential = next(
            item
            for item in environment
            if item.get("name") == verifier.CREDENTIAL_NAME
        )
        credential.clear()
        credential.update(
            {"name": verifier.CREDENTIAL_NAME, "value": "credential-must-not-render"}
        )
        direct_value = yaml.safe_dump_all(documents)
        with self.assertRaises(verifier.VerificationError):
            verifier.verify_qa_manifest(direct_value)

        leaked = manifest.replace(
            "- name: BABY_TALK_APP_API_URI",
            "- name: BABY_TALK_GENERATED_AUDIO_ENABLED\n"
            '              value: "true"\n'
            "            - name: BABY_TALK_APP_API_URI",
            1,
        )
        with self.assertRaises(verifier.VerificationError):
            verifier.verify_qa_manifest(leaked)

    def test_rejects_missing_or_changed_formal_qa_identity(self) -> None:
        manifest = verifier.render_qa(REPO_ROOT)
        for invalid in (
            manifest.replace("qwen-audio-3.0-tts-flash", "wrong-model", 1),
            manifest.replace(
                "dashscope-result-bj.oss-cn-beijing.aliyuncs.com", "attacker.invalid", 1
            ),
            manifest.replace("BABY_TALK_GENERATED_AUDIO_RESPONSE_MAX_BYTES", "REMOVED", 1),
        ):
            with self.assertRaises(verifier.VerificationError):
                verifier.verify_qa_manifest(invalid)


if __name__ == "__main__":
    unittest.main()
