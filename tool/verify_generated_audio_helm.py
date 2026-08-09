#!/usr/bin/env python3
"""Verify generated-audio Helm wiring without reading or printing Secret values."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import yaml


CREDENTIAL_NAME = "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY"
OWNER_KEY_OVERRIDE = (
    "secret.BABY_TALK_PRACTICE_DISCOVERY_OWNER_KEY_SECRET="
    "generated-audio-verifier-owner-key-32-bytes"
)
QA_VALUES = {
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
    "BABY_TALK_GENERATED_AUDIO_API_KEY_ENVIRONMENT_VARIABLE": CREDENTIAL_NAME,
    "BABY_TALK_GENERATED_AUDIO_MODEL": "qwen-audio-3.0-tts-flash",
    "BABY_TALK_GENERATED_AUDIO_VOICE": "loongeva_v3.6",
    "BABY_TALK_GENERATED_AUDIO_PROVIDER_PROFILE": "qa-formal-v1",
    "BABY_TALK_GENERATED_AUDIO_ALLOWED_DOWNLOAD_HOSTS": (
        "dashscope-result-bj.oss-cn-beijing.aliyuncs.com"
    ),
}


class VerificationError(RuntimeError):
    pass


def render_qa(repo_root: Path) -> str:
    chart = repo_root / "deploy" / "helm" / "babytalk-app"
    return _render(
        repo_root,
        chart,
        "-f",
        str(chart / "values-kind-qa.yaml"),
        "--set-string",
        OWNER_KEY_OVERRIDE,
    )


def render_default(repo_root: Path) -> str:
    chart = repo_root / "deploy" / "helm" / "babytalk-app"
    return _render(repo_root, chart)


def verify_repository(repo_root: Path) -> None:
    verify_default_manifest(render_default(repo_root))
    verify_qa_manifest(render_qa(repo_root))


def verify_default_manifest(manifest: str) -> None:
    documents = _documents(manifest)
    environment = _environment(_deployment(documents, "app-api"))
    _require_value(environment, "BABY_TALK_GENERATED_AUDIO_ENABLED", "false")
    _require_value(environment, "BABY_TALK_GENERATED_AUDIO_PROVIDER_MODE", "disabled")
    if CREDENTIAL_NAME in environment:
        raise VerificationError("disabled generated audio must not reference provider credentials")
    _reject_other_workload_exposure(documents)


def verify_qa_manifest(manifest: str) -> None:
    documents = _documents(manifest)
    environment = _environment(_deployment(documents, "app-api"))
    for name, expected in QA_VALUES.items():
        _require_value(environment, name, expected)

    credential = environment.get(CREDENTIAL_NAME)
    if not credential or "value" in credential:
        raise VerificationError("generated audio credential must use valueFrom")
    reference = credential.get("valueFrom", {}).get("secretKeyRef", {})
    if reference.get("key") != CREDENTIAL_NAME:
        raise VerificationError("generated audio credential must reuse the existing Secret key")
    if not str(reference.get("name", "")).endswith("-practice-ai-secret"):
        raise VerificationError("generated audio credential must reuse the Practice AI Secret")

    secret_key_occurrences = 0
    for document in documents:
        if document.get("kind") == "Secret":
            secret_key_occurrences += int(CREDENTIAL_NAME in document.get("data", {}))
    if secret_key_occurrences != 1:
        raise VerificationError("generated audio must not duplicate its provider credential")
    _reject_other_workload_exposure(documents)


def _render(repo_root: Path, chart: Path, *args: str) -> str:
    result = subprocess.run(
        ["helm", "template", "generated-audio-verifier", str(chart), *args],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise VerificationError("generated-audio Helm render failed")
    return result.stdout


def _documents(manifest: str) -> list[dict]:
    try:
        return [document for document in yaml.safe_load_all(manifest) if isinstance(document, dict)]
    except yaml.YAMLError as exception:
        raise VerificationError("generated-audio manifest is malformed") from exception


def _deployment(documents: list[dict], component: str) -> dict:
    matches = [
        document
        for document in documents
        if document.get("kind") == "Deployment"
        and document.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/component")
        == component
    ]
    if len(matches) != 1:
        raise VerificationError(f"expected one {component} Deployment")
    return matches[0]


def _environment(deployment: dict) -> dict[str, dict]:
    containers = deployment.get("spec", {}).get("template", {}).get("spec", {}).get("containers", [])
    if len(containers) != 1:
        raise VerificationError("expected one application container")
    entries = containers[0].get("env", [])
    names = [entry.get("name") for entry in entries]
    if len(names) != len(set(names)):
        raise VerificationError("duplicate environment variable")
    return {entry["name"]: entry for entry in entries if "name" in entry}


def _require_value(environment: dict[str, dict], name: str, expected: str) -> None:
    entry = environment.get(name)
    if not entry or entry.get("value") != expected or "valueFrom" in entry:
        raise VerificationError(f"invalid generated-audio environment field {name}")


def _reject_other_workload_exposure(documents: list[dict]) -> None:
    for document in documents:
        if document.get("kind") != "Deployment":
            continue
        component = document.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/component")
        if component == "app-api":
            continue
        rendered = yaml.safe_dump(document)
        if "BABY_TALK_GENERATED_AUDIO_" in rendered or CREDENTIAL_NAME in rendered:
            raise VerificationError("generated audio configuration escaped app-api")


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    try:
        verify_repository(repo_root)
    except VerificationError as exception:
        print(f"generated-audio Helm verification failed: {exception}", file=sys.stderr)
        return 1
    print("generated-audio Helm verification: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
