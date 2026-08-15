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


SCHEMA_VERSION = "BTQA_CANDIDATE_ACCEPTANCE_V1"
_CANDIDATE_ID = re.compile(r"^[a-z0-9][a-z0-9._-]{2,127}$")
_SHA256 = re.compile(r"^[a-f0-9]{64}$")
_MIGRATION_VERSION = re.compile(r"^[0-9]+(?:_[0-9]+)?$")
_CASE_ID = re.compile(r"^[a-z0-9][a-z0-9_-]{2,127}$")


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
    cases = _validate_cases(manifest)
    if candidate is None or cases is None:
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

    violations = []
    executed_cases = []
    for case in cases:
        result = run_case_command(case["command"])
        status = "PASS" if result.exit_code == 0 else "BLOCKED" if result.exit_code == 77 else "FAIL"
        executed_cases.append({
            "id": case["id"],
            "status": status,
            "exit_code": result.exit_code,
            "stdout_sha256": hashlib.sha256(result.stdout.encode()).hexdigest(),
            "stderr_sha256": hashlib.sha256(result.stderr.encode()).hexdigest(),
        })
        if status == "BLOCKED":
            violations.append("blocked_required_case")
        elif status != "PASS":
            violations.append("failed_required_case")

    evidence: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "candidate_id": candidate["id"],
        "apk_sha256": candidate["apk_sha256"],
        "gateway_url": candidate["gateway_url"],
        "required_migration_version": candidate["required_migration_version"],
        "gateway_compatibility": compatibility,
        "cases": executed_cases,
        "status": "PASS" if not violations else "FAIL",
    }
    return AcceptanceReport(violations, evidence)


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
    return raw if isinstance(raw, dict) else None


def _validate_candidate(manifest: dict[str, object]) -> dict[str, str] | None:
    if manifest.get("schema_version") != SCHEMA_VERSION:
        return None
    raw = manifest.get("candidate")
    if not isinstance(raw, dict) or set(raw) != {
        "id",
        "apk_path",
        "apk_sha256",
        "gateway_url",
        "required_migration_version",
    }:
        return None
    candidate = {key: value for key, value in raw.items() if isinstance(value, str)}
    if len(candidate) != len(raw):
        return None
    if not _CANDIDATE_ID.fullmatch(candidate["id"]):
        return None
    if not _SHA256.fullmatch(candidate["apk_sha256"]):
        return None
    gateway_url = urlsplit(candidate["gateway_url"])
    if (
        gateway_url.scheme not in {"http", "https"}
        or not gateway_url.hostname
        or gateway_url.username
        or gateway_url.password
        or gateway_url.query
        or gateway_url.fragment
    ):
        return None
    if not _MIGRATION_VERSION.fullmatch(candidate["required_migration_version"]):
        return None
    return candidate


def run_case_command(command: list[str]) -> CaseCommandResult:
    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
        return CaseCommandResult(completed.returncode, completed.stdout, completed.stderr)
    except OSError as error:
        return CaseCommandResult(127, "", str(error))


def _validate_cases(manifest: dict[str, object]) -> list[dict[str, object]] | None:
    raw = manifest.get("cases")
    if not isinstance(raw, list) or not raw:
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
    return cases


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


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
