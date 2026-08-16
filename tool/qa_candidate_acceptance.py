"""Fail-closed acceptance gate for one frozen Mobile QA candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import urlopen


SCHEMA_VERSION = "BTQA_CANDIDATE_ACCEPTANCE_V2"
CASE_RECEIPT_SCHEMA_VERSION = "BTQA_CASE_RECEIPT_V1"
REQUIRED_CASE_IDS = (
    "idempotent_account_sync",
    "two_account_household",
    "android_notification",
    "android_audio",
    "android_deep_link",
)
_CASE_COMMAND_TIMEOUT_SECONDS = 600
_DEVICE_COMMAND_TIMEOUT_SECONDS = 120
_CANDIDATE_ID = re.compile(r"^[a-z0-9][a-z0-9._-]{2,127}$")
_SHA256 = re.compile(r"^[a-f0-9]{64}$")
_MIGRATION_VERSION = re.compile(r"^[0-9]+(?:_[0-9]+)?$")
_CASE_ID = re.compile(r"^[a-z0-9][a-z0-9_-]{2,127}$")
_SYNTHETIC_REFERENCE = re.compile(r"^qa-[a-z0-9][a-z0-9-]{5,127}$")
_ANDROID_SERIAL = re.compile(r"^[A-Za-z0-9._:-]{3,128}$")
_ANDROID_PACKAGE = re.compile(r"^[a-zA-Z][A-Za-z0-9_]*(?:\.[a-zA-Z][A-Za-z0-9_]*)+$")
_ANDROID_VERSION = re.compile(r"^[0-9]+(?:\.[0-9]+){0,3}$")
_TOP_LEVEL_KEYS = {"schema_version", "candidate", "android_device", "synthetic_identities", "cases"}
_SYNTHETIC_KEYS = {"primary_account_ref", "caregiver_account_ref", "idempotent_event_id"}


@dataclass(frozen=True)
class AcceptanceReport:
    violations: list[str]
    evidence: dict[str, object]

    @property
    def passes(self) -> bool:
        return not self.violations


@dataclass(frozen=True)
class CaseCommandResult:
    exit_code: int
    stdout: str
    stderr: str


@dataclass(frozen=True)
class AndroidDeviceEvidence:
    status: str
    android_version: str | None
    device_identity_sha256: str | None
    package_id: str | None
    install_stdout_sha256: str | None
    install_stderr_sha256: str | None

    @classmethod
    def passing(
        cls,
        *,
        serial: str,
        android_version: str,
        package_id: str,
        install_stdout: str = "",
        install_stderr: str = "",
    ) -> AndroidDeviceEvidence:
        return cls(
            status="PASS",
            android_version=android_version,
            device_identity_sha256=_text_sha256(serial),
            package_id=package_id,
            install_stdout_sha256=_text_sha256(install_stdout),
            install_stderr_sha256=_text_sha256(install_stderr),
        )

    @classmethod
    def blocked(cls) -> AndroidDeviceEvidence:
        return cls("BLOCKED", None, None, None, None, None)

    @classmethod
    def failed(cls, *, serial: str, package_id: str, install_stdout: str, install_stderr: str) -> AndroidDeviceEvidence:
        return cls(
            status="FAIL",
            android_version=None,
            device_identity_sha256=_text_sha256(serial),
            package_id=package_id,
            install_stdout_sha256=_text_sha256(install_stdout),
            install_stderr_sha256=_text_sha256(install_stderr),
        )

    def to_evidence(self) -> dict[str, str]:
        values = {
            "status": self.status,
            "android_version": self.android_version,
            "device_identity_sha256": self.device_identity_sha256,
            "package_id": self.package_id,
            "install_stdout_sha256": self.install_stdout_sha256,
            "install_stderr_sha256": self.install_stderr_sha256,
        }
        return {key: value for key, value in values.items() if value is not None}


def read_gateway_compatibility(gateway_url: str) -> dict[str, object]:
    endpoint = f"{gateway_url.rstrip('/')}/qa/candidate-compatibility"
    with urlopen(endpoint, timeout=10) as response:  # noqa: S310 - manifest is an explicit QA input.
        payload = json.loads(response.read().decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("gateway response is not a JSON object")
    return payload


def run_acceptance(manifest_path: Path) -> AcceptanceReport:
    manifest = _read_manifest(manifest_path)
    if manifest is None:
        return AcceptanceReport(["invalid_manifest"], {})

    candidate = _validate_candidate(manifest)
    android_device = _validate_android_device(manifest)
    synthetic_identities = _validate_synthetic_identities(manifest)
    cases = _validate_cases(manifest)
    if candidate is None or android_device is None or synthetic_identities is None or cases is None:
        return AcceptanceReport(["invalid_manifest"], {})

    apk = Path(candidate["apk_path"])
    if not apk.is_file() or _sha256(apk) != candidate["apk_sha256"]:
        return AcceptanceReport(["apk_identity_mismatch"], {})

    try:
        compatibility = read_gateway_compatibility(candidate["gateway_url"])
    except Exception:
        return AcceptanceReport(["gateway_compatibility_unavailable"], {})

    if compatibility != {
        "candidateId": candidate["id"],
        "requiredMigrationVersion": candidate["required_migration_version"],
        "status": "compatible",
    }:
        return AcceptanceReport(["candidate_identity_mismatch"], {})

    device_evidence = collect_android_device_evidence(apk=apk, device=android_device)
    if device_evidence.status != "PASS":
        violation = "android_device_blocked" if device_evidence.status == "BLOCKED" else "android_device_failed"
        return AcceptanceReport(
            [violation],
            _base_evidence(candidate, compatibility, synthetic_identities, device_evidence),
        )

    violations: list[str] = []
    executed_cases: list[dict[str, object]] = []
    identity_fingerprints = _fingerprint_identities(synthetic_identities)
    for case in cases:
        result = run_case_command(case["command"])
        status = "PASS" if result.exit_code == 0 else "BLOCKED" if result.exit_code == 77 else "FAIL"
        receipt = _validate_case_receipt(
            result.stdout,
            case_id=case["id"],
            candidate_id=candidate["id"],
            identity_fingerprints=identity_fingerprints,
        ) if status == "PASS" else None
        if status == "PASS" and receipt is None:
            status = "FAIL"
            violations.append("invalid_case_receipt")
        elif status == "BLOCKED":
            violations.append("blocked_required_case")
        elif status == "FAIL":
            violations.append("failed_required_case")
        executed_cases.append({
            "id": case["id"],
            "status": status,
            "exit_code": result.exit_code,
            "stdout_sha256": _text_sha256(result.stdout),
            "stderr_sha256": _text_sha256(result.stderr),
            "receipt": receipt,
        })

    evidence = _base_evidence(candidate, compatibility, synthetic_identities, device_evidence)
    evidence["cases"] = executed_cases
    evidence["status"] = "PASS" if not violations else "FAIL"
    return AcceptanceReport(violations, evidence)


def collect_android_device_evidence(*, apk: Path, device: dict[str, str]) -> AndroidDeviceEvidence:
    serial = device["serial"]
    package_id = device["package_id"]
    state = run_device_command(["adb", "-s", serial, "get-state"])
    if state.exit_code != 0 or state.stdout.strip() != "device":
        return AndroidDeviceEvidence.blocked()

    install = run_device_command(["adb", "-s", serial, "install", "-r", str(apk)])
    if install.exit_code != 0:
        return AndroidDeviceEvidence.failed(
            serial=serial,
            package_id=package_id,
            install_stdout=install.stdout,
            install_stderr=install.stderr,
        )

    android_version = run_device_command(["adb", "-s", serial, "shell", "getprop", "ro.build.version.release"])
    package_path = run_device_command(["adb", "-s", serial, "shell", "pm", "path", package_id])
    version = android_version.stdout.strip()
    if (
        android_version.exit_code != 0
        or package_path.exit_code != 0
        or not _ANDROID_VERSION.fullmatch(version)
        or not package_path.stdout.strip().startswith("package:")
    ):
        return AndroidDeviceEvidence.failed(
            serial=serial,
            package_id=package_id,
            install_stdout=install.stdout,
            install_stderr=install.stderr,
        )
    return AndroidDeviceEvidence.passing(
        serial=serial,
        android_version=version,
        package_id=package_id,
        install_stdout=install.stdout,
        install_stderr=install.stderr,
    )


def run_case_command(command: list[str]) -> CaseCommandResult:
    return _run_command(command, timeout_seconds=_CASE_COMMAND_TIMEOUT_SECONDS)


def run_device_command(command: list[str]) -> CaseCommandResult:
    return _run_command(command, timeout_seconds=_DEVICE_COMMAND_TIMEOUT_SECONDS)


def write_evidence(report: AcceptanceReport, evidence_path: Path) -> None:
    if evidence_path.exists():
        raise FileExistsError(f"evidence already exists: {evidence_path}")
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    evidence = {
        **report.evidence,
        "recorded_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "violations": report.violations,
    }
    evidence_path.write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _read_manifest(path: Path) -> dict[str, object] | None:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(raw, dict) or set(raw) != _TOP_LEVEL_KEYS:
        return None
    return raw


def _validate_candidate(manifest: dict[str, object]) -> dict[str, str] | None:
    if manifest.get("schema_version") != SCHEMA_VERSION:
        return None
    raw = manifest.get("candidate")
    if not isinstance(raw, dict) or set(raw) != {
        "id", "apk_path", "apk_sha256", "gateway_url", "required_migration_version",
    }:
        return None
    candidate = {key: value for key, value in raw.items() if isinstance(value, str)}
    if len(candidate) != len(raw):
        return None
    if not _CANDIDATE_ID.fullmatch(candidate["id"]) or not _SHA256.fullmatch(candidate["apk_sha256"]):
        return None
    gateway_url = urlsplit(candidate["gateway_url"])
    if (
        gateway_url.scheme not in {"http", "https"}
        or not gateway_url.hostname
        or gateway_url.username
        or gateway_url.password
        or gateway_url.query
        or gateway_url.fragment
        or not _MIGRATION_VERSION.fullmatch(candidate["required_migration_version"])
    ):
        return None
    return candidate


def _validate_android_device(manifest: dict[str, object]) -> dict[str, str] | None:
    raw = manifest.get("android_device")
    if not isinstance(raw, dict) or set(raw) != {"serial", "package_id"}:
        return None
    device = {key: value for key, value in raw.items() if isinstance(value, str)}
    if len(device) != len(raw):
        return None
    if not _ANDROID_SERIAL.fullmatch(device["serial"]) or not _ANDROID_PACKAGE.fullmatch(device["package_id"]):
        return None
    return device


def _validate_synthetic_identities(manifest: dict[str, object]) -> dict[str, str] | None:
    raw = manifest.get("synthetic_identities")
    if not isinstance(raw, dict) or set(raw) != _SYNTHETIC_KEYS:
        return None
    identities = {key: value for key, value in raw.items() if isinstance(value, str)}
    if len(identities) != len(raw) or len(set(identities.values())) != len(identities):
        return None
    if not all(_SYNTHETIC_REFERENCE.fullmatch(value) for value in identities.values()):
        return None
    return identities


def _validate_cases(manifest: dict[str, object]) -> list[dict[str, object]] | None:
    raw = manifest.get("cases")
    if not isinstance(raw, list) or len(raw) != len(REQUIRED_CASE_IDS):
        return None
    cases: list[dict[str, object]] = []
    ids: set[str] = set()
    for value in raw:
        if not isinstance(value, dict) or set(value) != {"id", "command"}:
            return None
        case_id = value.get("id")
        command = value.get("command")
        if (
            not isinstance(case_id, str)
            or not _CASE_ID.fullmatch(case_id)
            or case_id in ids
            or not isinstance(command, list)
            or not command
            or any(not isinstance(part, str) or not part for part in command)
        ):
            return None
        ids.add(case_id)
        cases.append({"id": case_id, "command": command})
    return cases if ids == set(REQUIRED_CASE_IDS) else None


def _validate_case_receipt(
    raw: str,
    *,
    case_id: str,
    candidate_id: str,
    identity_fingerprints: dict[str, str],
) -> dict[str, object] | None:
    try:
        receipt = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if not isinstance(receipt, dict) or set(receipt) != {
        "schema_version", "candidate_id", "case_id", "synthetic_identity_fingerprints", "observations",
    }:
        return None
    if (
        receipt.get("schema_version") != CASE_RECEIPT_SCHEMA_VERSION
        or receipt.get("candidate_id") != candidate_id
        or receipt.get("case_id") != case_id
        or receipt.get("synthetic_identity_fingerprints") != identity_fingerprints
    ):
        return None
    observations = receipt.get("observations")
    if not isinstance(observations, dict) or not _valid_observations(case_id, observations):
        return None
    return {"case_id": case_id, "observations": observations}


def _valid_observations(case_id: str, observations: dict[str, object]) -> bool:
    required: dict[str, dict[str, object]] = {
        "idempotent_account_sync": {
            "external_user_behavior_observed": True,
            "server_observable_observed": True,
            "first_write_status": "accepted",
            "retry_status": "duplicate",
            "server_event_count": 1,
        },
        "two_account_household": {
            "external_user_behavior_observed": True,
            "server_observable_observed": True,
            "invite_created": True,
            "invite_accepted": True,
            "invite_revoked": True,
            "shared_context_isolated": True,
        },
        "android_notification": {
            "system_state_observed": True,
            "user_visible_result_observed": True,
            "notification_delivered": True,
        },
        "android_audio": {
            "system_state_observed": True,
            "user_visible_result_observed": True,
            "audio_output_observed": True,
            "speed_effect_observed": True,
            "controls_observed": True,
        },
        "android_deep_link": {
            "system_state_observed": True,
            "user_visible_result_observed": True,
            "cold_start_destination_observed": True,
            "foreground_destination_observed": True,
            "invalid_link_message_observed": True,
        },
    }
    return observations == required.get(case_id)


def _base_evidence(
    candidate: dict[str, str],
    compatibility: dict[str, object],
    synthetic_identities: dict[str, str],
    device_evidence: AndroidDeviceEvidence,
) -> dict[str, object]:
    return {
        "schema_version": SCHEMA_VERSION,
        "candidate_id": candidate["id"],
        "apk_sha256": candidate["apk_sha256"],
        "gateway_url": candidate["gateway_url"],
        "required_migration_version": candidate["required_migration_version"],
        "gateway_compatibility": compatibility,
        "android_device": device_evidence.to_evidence(),
        "synthetic_identity_fingerprints": _fingerprint_identities(synthetic_identities),
    }


def _fingerprint_identities(identities: dict[str, str]) -> dict[str, str]:
    return {key: _text_sha256(value) for key, value in identities.items()}


def _run_command(command: list[str], *, timeout_seconds: int) -> CaseCommandResult:
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=timeout_seconds,
        )
        return CaseCommandResult(completed.returncode, completed.stdout, completed.stderr)
    except subprocess.TimeoutExpired as error:
        return CaseCommandResult(124, str(error.stdout or ""), str(error.stderr or ""))
    except OSError as error:
        return CaseCommandResult(127, "", str(error))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _text_sha256(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    arguments = parser.parse_args()
    report = run_acceptance(arguments.manifest)
    try:
        write_evidence(report, arguments.evidence)
    except OSError as error:
        print(f"qa_candidate_acceptance_status=fail\nevidence_write_error={type(error).__name__}")
        return 1
    print(f"qa_candidate_acceptance_status={'pass' if report.passes else 'fail'}")
    print(f"violations={','.join(report.violations) if report.violations else 'none'}")
    return 0 if report.passes else 1


if __name__ == "__main__":
    sys.exit(_main())
