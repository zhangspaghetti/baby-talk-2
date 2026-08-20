"""Fail-closed acceptance gate for one frozen Mobile QA candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import quote, urlencode, urlsplit
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener


SCHEMA_VERSION = "BTQA_CANDIDATE_ACCEPTANCE_V3"
CASE_RECEIPT_SCHEMA_VERSION = "BTQA_CASE_RECEIPT_V2"
REQUIRED_CASE_IDS = (
    "idempotent_account_sync",
    "two_account_household",
    "android_notification",
    "android_audio",
    "android_deep_link",
)
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
_CASE_KEYS = {"id", "runner"}
_RECEIPT_KEYS = {
    "schema_version",
    "candidate_id",
    "apk_sha256",
    "case_id",
    "android_device_identity_sha256",
    "android_version",
    "package_id",
    "synthetic_identity_fingerprints",
    "evidence",
    "observations",
}
_EVIDENCE_KEYS = {"server", "adb", "user_visible"}
_SCENARIO_TIMEOUT_SECONDS = 30
_QA_VERIFICATION_CODE = "246810"
_QA_CONSENT_VERSION = "pipl-v1"
_QA_PHONE_PREFIX = "139"
_TRUSTED_QA_GATEWAY_HOSTS = frozenset(
    {"127.0.0.1", "localhost", "::1", "api.babytalk.example.com"}
)
_SECRET_RESPONSE_KEY = re.compile(
    r"(?:access|refresh)?token|password|phone|authorization|sessionid|challengeid",
    re.IGNORECASE,
)


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
class CaseEvidence:
    """Evidence collected by harness after a fixed runner completes."""

    server_response_sha256: str
    adb_state_sha256: str
    user_visible_sha256: str

    def to_receipt(self) -> dict[str, dict[str, str]]:
        return {
            "server": {
                "response_sha256": self.server_response_sha256,
            },
            "adb": {"state_sha256": self.adb_state_sha256},
            "user_visible": {"surface_sha256": self.user_visible_sha256},
        }


@dataclass(frozen=True)
class CaseExecutionContext:
    candidate_id: str
    apk_sha256: str
    gateway_url: str
    package_id: str
    device_identity_sha256: str
    android_version: str
    identity_fingerprints: dict[str, str]
    # The serial is copied from the validated manifest/device evidence. It is
    # deliberately not read from the environment so a runner cannot drift to
    # another device halfway through a case.
    device_serial: str = ""


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


class _RejectRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, request, file, code, msg, headers, newurl):  # type: ignore[no-untyped-def]
        return None


_NO_REDIRECT_OPENER = build_opener(_RejectRedirectHandler)


def read_gateway_compatibility(gateway_url: str) -> dict[str, object]:
    endpoint = f"{gateway_url.rstrip('/')}/qa/candidate-compatibility"
    request = Request(endpoint, headers={"Accept": "application/json"}, method="GET")
    try:
        with _NO_REDIRECT_OPENER.open(request, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        if 300 <= error.code < 400:
            raise ValueError("gateway compatibility redirect rejected") from error
        raise
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
    context = _case_execution_context(
        candidate=candidate,
        device=android_device,
        device_evidence=device_evidence,
        identity_fingerprints=identity_fingerprints,
    )
    try:
        installed_identity_matches = _verify_installed_candidate_identity(context)
    except _ScenarioBlocked:
        return AcceptanceReport(
            ["apk_candidate_identity_blocked"],
            _base_evidence(candidate, compatibility, synthetic_identities, device_evidence),
        )
    if not installed_identity_matches:
        return AcceptanceReport(
            ["apk_candidate_identity_mismatch"],
            _base_evidence(candidate, compatibility, synthetic_identities, device_evidence),
        )
    for case in cases:
        try:
            result = run_case_command(case["runner"], context=context)
        except Exception as error:
            result = CaseCommandResult(127, "", f"case runner error: {type(error).__name__}: {error}")
        status = "PASS" if result.exit_code == 0 else "BLOCKED" if result.exit_code == 77 else "FAIL"
        try:
            case_evidence = (
                collect_case_evidence(
                    candidate=candidate,
                    device=android_device,
                    device_evidence=device_evidence,
                    case_id=case["id"],
                    compatibility=compatibility,
                    context=context,
                )
                if status == "PASS"
                else None
            )
        except Exception:
            case_evidence = None
        if status == "PASS" and case_evidence is None:
            status = "BLOCKED"
            violations.append("missing_case_evidence")
        receipt = _validate_case_receipt(
            result.stdout,
            case_id=case["id"],
            candidate_id=candidate["id"],
            apk_sha256=candidate["apk_sha256"],
            device_evidence=device_evidence,
            identity_fingerprints=identity_fingerprints,
            expected_evidence=case_evidence,
        ) if status == "PASS" and case_evidence is not None else None
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
            "evidence": case_evidence.to_receipt() if case_evidence is not None else None,
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


def _case_execution_context(
    *,
    candidate: dict[str, str],
    device: dict[str, str],
    device_evidence: AndroidDeviceEvidence,
    identity_fingerprints: dict[str, str],
) -> CaseExecutionContext:
    if (
        device_evidence.device_identity_sha256 is None
        or device_evidence.android_version is None
        or device_evidence.package_id is None
    ):
        raise ValueError("passing device evidence is incomplete")
    return CaseExecutionContext(
        candidate_id=candidate["id"],
        apk_sha256=candidate["apk_sha256"],
        gateway_url=candidate["gateway_url"],
        package_id=device["package_id"],
        device_identity_sha256=device_evidence.device_identity_sha256,
        android_version=device_evidence.android_version,
        identity_fingerprints=identity_fingerprints,
        device_serial=device["serial"],
    )


def collect_case_evidence(
    *,
    candidate: dict[str, str],
    device: dict[str, str],
    device_evidence: AndroidDeviceEvidence,
    case_id: str,
    compatibility: dict[str, object],
    context: CaseExecutionContext,
) -> CaseEvidence | None:
    """Collect independent server, ADB, and user-visible evidence.

    No receipt-provided value is used as an input. The runner may drive the
    scenario, but the harness owns all evidence hashes used for acceptance.
    """
    try:
        observed_compatibility = read_gateway_compatibility(candidate["gateway_url"])
    except Exception:
        return None
    if observed_compatibility != compatibility:
        return None
    try:
        business_result = _collect_case_business_result(context, case_id)
    except _ScenarioBlocked:
        return None

    serial = device["serial"]
    state = run_device_command(["adb", "-s", serial, "get-state"])
    version = run_device_command(["adb", "-s", serial, "shell", "getprop", "ro.build.version.release"])
    package_path = run_device_command(["adb", "-s", serial, "shell", "pm", "path", device["package_id"]])
    if (
        state.exit_code != 0
        or state.stdout.strip() != "device"
        or version.exit_code != 0
        or version.stdout.strip() != device_evidence.android_version
        or package_path.exit_code != 0
        or not package_path.stdout.strip().startswith("package:")
    ):
        return None

    ui_dump = run_device_command(["adb", "-s", serial, "shell", "uiautomator", "dump", "/dev/tty"])
    screenshot = _run_binary_command(["adb", "-s", serial, "exec-out", "screencap", "-p"])
    if ui_dump.exit_code != 0 or screenshot.exit_code != 0 or not screenshot.stdout:
        return None

    adb_state = "\n".join(
        (
            state.stdout.strip(),
            version.stdout.strip(),
            package_path.stdout.strip(),
            device_evidence.device_identity_sha256 or "",
            device_evidence.package_id or "",
            candidate["apk_sha256"],
        )
    )
    try:
        user_visible = _case_user_visible_projection(case_id, ui_dump.stdout)
    except _ScenarioBlocked:
        return None
    return CaseEvidence(
        server_response_sha256=_canonical_json_sha256(
            {
                "case_id": case_id,
                "compatibility": observed_compatibility,
                "business_result": _redact_business_payload(business_result),
            }
        ),
        adb_state_sha256=_text_sha256(adb_state),
        user_visible_sha256=_canonical_json_sha256(user_visible),
    )


class _ScenarioBlocked(RuntimeError):
    """The fixed scenario could not start or lacked required public evidence."""


@dataclass(frozen=True)
class _ScenarioHttpResponse:
    status_code: int
    payload: object


@dataclass(frozen=True)
class _QaSession:
    account_id: str
    session_id: str
    access_token: str
    refresh_token: str
    installation_id: str


def _redact_business_payload(value: object) -> object:
    """Canonical secret-safe projection used for receipt hashing."""
    if isinstance(value, dict):
        return {
            str(key): (
                "[REDACTED]"
                if _SECRET_RESPONSE_KEY.search(str(key))
                else _redact_business_payload(item)
            )
            for key, item in sorted(value.items(), key=lambda entry: str(entry[0]))
        }
    if isinstance(value, list):
        return [_redact_business_payload(item) for item in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    raise _ScenarioBlocked("business result is not canonical JSON")


def _collect_case_business_result(
    context: CaseExecutionContext,
    case_id: str,
) -> dict[str, object]:
    """Re-observe the case result without trusting receipt observations."""
    if case_id == "idempotent_account_sync":
        session: _QaSession | None = None
        try:
            session = _authenticate_fixed_identity(context, "primary_account_ref")
            event_key = _stable_event_key(context, session.installation_id)
            bootstrap = _require_json_object(
                _scenario_json_request(
                    context=context,
                    method="GET",
                    path="/api/v1/bootstrap",
                    query={"installationId": session.installation_id},
                    access_token=session.access_token,
                ),
                statuses=(200,),
            )
            events = bootstrap.get("events")
            matching = [
                event
                for event in events
                if isinstance(event, dict) and event.get("eventKey") == event_key
            ] if isinstance(events, list) else []
            if bootstrap.get("eventCount") != 1 or len(matching) != 1:
                raise _ScenarioBlocked("independent sync projection is unavailable")
            return {
                "projection": "idempotent_sync_v1",
                "eventCount": 1,
                "eventKeySha256": _text_sha256(event_key),
            }
        finally:
            _logout_fixed_identity(context, session)

    if case_id == "two_account_household":
        primary: _QaSession | None = None
        caregiver: _QaSession | None = None
        try:
            primary = _authenticate_fixed_identity(context, "primary_account_ref")
            caregiver = _authenticate_fixed_identity(context, "caregiver_account_ref")
            probe_invite = _require_json_object(
                _scenario_json_request(
                    context=context,
                    method="POST",
                    path="/api/v1/caregiver-invites",
                    payload={"role": "caregiver", "source": "household_settings"},
                    access_token=primary.access_token,
                ),
                statuses=(201,),
            )
            probe_token = _required_string(probe_invite, "token")
            revoke = _require_json_object(
                _scenario_json_request(
                    context=context,
                    method="POST",
                    path=f"/api/v1/caregiver-invites/{quote(probe_token, safe='')}/revoke",
                    access_token=primary.access_token,
                ),
                statuses=(200,),
            )
            rejected = _scenario_json_request(
                context=context,
                method="POST",
                path="/api/v1/caregiver-invites/accept",
                payload={"token": probe_token, "source": "household_settings"},
                access_token=caregiver.access_token,
            )
            if (
                revoke.get("applied") is not True
                or revoke.get("result") != "revoked"
                or rejected.status_code not in (400, 404, 409)
            ):
                raise _ScenarioBlocked("independent invite revoke projection is unavailable")
            shared = _require_json_object(
                _scenario_json_request(
                    context=context,
                    method="GET",
                    path="/api/v1/household/shared-context",
                    access_token=caregiver.access_token,
                ),
                statuses=(200,),
            )
            household_id = _required_string(shared, "householdId")
            return {
                "projection": "household_shared_context_v1",
                "householdIdSha256": _text_sha256(household_id),
                "role": shared.get("role"),
                "hasBabyProfile": isinstance(shared.get("babyProfile"), dict)
                or bool(shared.get("babyProfileId")),
                "revokedInviteRejectedStatus": rejected.status_code,
            }
        finally:
            _logout_fixed_identity(context, caregiver)
            _logout_fixed_identity(context, primary)

    if case_id == "android_notification":
        alarm = _dumpsys(context, "alarm")
        notification = _dumpsys(context, "notification", "--noredact")
        if not _alarm_proves_daily_reminder_delivery(alarm, context.package_id):
            raise _ScenarioBlocked("independent alarm delivery evidence is unavailable")
        if not _notification_is_posted(notification, context.package_id):
            raise _ScenarioBlocked("independent posted notification evidence is unavailable")
        return {
            "projection": "android_notification_v1",
            "alarmManagerDelivered": True,
            "notificationId": 7020,
            "channel": "daily_reminder",
        }

    if case_id == "android_audio":
        media = _dumpsys(context, "media_session")
        ui = _dump_ui(context)
        if context.package_id.lower() not in media.lower() or not re.search(
            r"state\s*=|state_?(?:playing|paused|stopped)", media, re.IGNORECASE
        ):
            raise _ScenarioBlocked("independent audio session evidence is unavailable")
        if not any(marker in ui for marker in ("暂停", "重播", "Pause", "Replay")):
            raise _ScenarioBlocked("independent audio control evidence is unavailable")
        return {
            "projection": "android_audio_v1",
            "mediaSessionObserved": True,
            "controlsVisible": True,
        }

    if case_id == "android_deep_link":
        session: _QaSession | None = None
        try:
            session = _authenticate_fixed_identity(context, "primary_account_ref")
            invite = _require_json_object(
                _scenario_json_request(
                    context=context,
                    method="POST",
                    path="/api/v1/caregiver-invites",
                    payload={"role": "caregiver", "source": "household_settings"},
                    access_token=session.access_token,
                ),
                statuses=(201,),
            )
            invite_url = _safe_invite_url(_required_string(invite, "inviteUrl"))
            invite_business_result = {
                "inviteUrlHost": (urlsplit(invite_url).hostname or "").lower(),
                "householdIdSha256": _text_sha256(_required_string(invite, "householdId")),
                "tokenPresent": bool(_required_string(invite, "token")),
            }
        finally:
            _logout_fixed_identity(context, session)
        activity = _dumpsys(context, "activity", "activities")
        ui = _dump_ui(context)
        if not _deep_link_intent_is_active(activity, context.package_id):
            raise _ScenarioBlocked("independent deep-link intent evidence is unavailable")
        if not _deep_link_invalid_fallback_is_visible(ui):
            raise _ScenarioBlocked("independent deep-link fallback evidence is unavailable")
        return {
            "projection": "android_deep_link_v1",
            "route": "invite/open",
            "invalidFallback": "safe_shell",
            **invite_business_result,
        }

    raise _ScenarioBlocked("case business evidence collector is not allow-listed")


def _scenario_json_request(
    *,
    context: CaseExecutionContext,
    method: str,
    path: str,
    payload: dict[str, object] | None = None,
    access_token: str | None = None,
    query: dict[str, str] | None = None,
) -> _ScenarioHttpResponse:
    """Call a fixed public QA API; never accept URLs or commands from a manifest."""
    if not path.startswith("/") or "?" in path or "#" in path:
        raise _ScenarioBlocked("fixed scenario path is invalid")
    if not _is_trusted_gateway_url(context.gateway_url):
        raise _ScenarioBlocked("gateway is not in the fixed QA trust boundary")
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    endpoint = f"{context.gateway_url.rstrip('/')}{path}"
    if query:
        endpoint = f"{endpoint}?{urlencode(query)}"
    request = Request(
        endpoint,
        data=body,
        headers=headers,
        method=method,
    )
    try:
        with _NO_REDIRECT_OPENER.open(request, timeout=_SCENARIO_TIMEOUT_SECONDS) as response:
            raw = response.read()
            status_code = int(response.status)
    except HTTPError as error:
        if 300 <= error.code < 400:
            raise _ScenarioBlocked("gateway redirected a fixed scenario") from error
        raw = error.read()
        status_code = int(error.code)
    except (OSError, URLError, TimeoutError, ValueError) as error:
        raise _ScenarioBlocked("gateway unavailable") from error
    try:
        decoded = json.loads(raw.decode("utf-8")) if raw else {}
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise _ScenarioBlocked("gateway returned non-JSON scenario data") from error
    return _ScenarioHttpResponse(status_code, decoded)


def _require_json_object(response: _ScenarioHttpResponse, *, statuses: tuple[int, ...]) -> dict[str, object]:
    if response.status_code not in statuses:
        raise _ScenarioBlocked(f"fixed scenario HTTP status {response.status_code}")
    if not isinstance(response.payload, dict):
        raise _ScenarioBlocked("fixed scenario response is not an object")
    return response.payload


def _required_string(payload: dict[str, object], key: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str) or not value.strip():
        raise _ScenarioBlocked(f"fixed scenario response missing {key}")
    return value.strip()


def _safe_invite_url(value: str) -> str:
    parsed = urlsplit(value)
    if (
        parsed.scheme not in {"http", "https"}
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or not parsed.path.startswith("/invite/")
    ):
        raise _ScenarioBlocked("server returned an unsafe invite URL")
    return value


def _stable_synthetic_phone(fingerprint: str) -> str:
    if not _SHA256.fullmatch(fingerprint):
        raise _ScenarioBlocked("synthetic identity fingerprint is invalid")
    suffix = int(fingerprint[:16], 16) % 100_000_000
    return f"{_QA_PHONE_PREFIX}{suffix:08d}"


def _stable_installation_id(context: CaseExecutionContext, fingerprint: str) -> str:
    digest = hashlib.sha256(
        f"{context.candidate_id}|{context.package_id}|{fingerprint}".encode("utf-8")
    ).hexdigest()
    return f"qa-install-{digest[:48]}"


def _stable_event_key(context: CaseExecutionContext, installation_id: str | None = None) -> str:
    event_fingerprint = context.identity_fingerprints.get("idempotent_event_id")
    if event_fingerprint is None:
        raise _ScenarioBlocked("idempotent event identity is missing")
    digest = hashlib.sha256(
        f"{context.candidate_id}|{context.package_id}|{event_fingerprint}".encode("utf-8")
    ).hexdigest()
    installation = installation_id or _stable_installation_id(context, event_fingerprint)
    return f"{installation}:evt-{digest[:40]}"


def _authenticate_fixed_identity(
    context: CaseExecutionContext,
    identity_key: str,
) -> _QaSession:
    fingerprint = context.identity_fingerprints.get(identity_key)
    if fingerprint is None:
        raise _ScenarioBlocked(f"synthetic identity {identity_key} is missing")
    installation_id = _stable_installation_id(context, fingerprint)
    challenge = _require_json_object(
        _scenario_json_request(
            context=context,
            method="POST",
            path="/api/v1/auth/challenges",
            payload={"phoneNumber": _stable_synthetic_phone(fingerprint)},
        ),
        statuses=(201,),
    )
    challenge_id = _required_string(challenge, "challengeId")
    session = _require_json_object(
        _scenario_json_request(
            context=context,
            method="POST",
            path="/api/v1/auth/verify",
            payload={
                "challengeId": challenge_id,
                "verificationCode": _QA_VERIFICATION_CODE,
                "installationId": installation_id,
            },
        ),
        statuses=(200,),
    )
    access_token = _required_string(session, "accessToken")
    refresh_token = _required_string(session, "refreshToken")
    account_id = _required_string(session, "accountId")
    session_id = _required_string(session, "sessionId")
    consent = _require_json_object(
        _scenario_json_request(
            context=context,
            method="POST",
            path="/api/v1/consent/accept",
            payload={"consentVersion": _QA_CONSENT_VERSION},
            access_token=access_token,
        ),
        statuses=(200,),
    )
    if consent.get("consentStatus") != "accepted":
        raise _ScenarioBlocked("fixed scenario consent was not accepted")
    return _QaSession(account_id, session_id, access_token, refresh_token, installation_id)


def _logout_fixed_identity(context: CaseExecutionContext, session: _QaSession | None) -> None:
    if session is None:
        return
    try:
        _scenario_json_request(
            context=context,
            method="POST",
            path="/api/v1/auth/logout",
            payload={"refreshToken": session.refresh_token},
        )
    except Exception:
        # Cleanup cannot turn a passing behavioral assertion into a false pass.
        # The next harness run remains isolated by its stable synthetic identity.
        return


def _run_device_step(context: CaseExecutionContext, arguments: list[str]) -> str:
    if not context.device_serial or not _ANDROID_SERIAL.fullmatch(context.device_serial):
        raise _ScenarioBlocked("fixed scenario device is unavailable")
    result = run_device_command(["adb", "-s", context.device_serial, *arguments])
    if result.exit_code != 0:
        raise _ScenarioBlocked("fixed scenario device command failed")
    return result.stdout


def _launch_app(context: CaseExecutionContext) -> None:
    _run_device_step(
        context,
        ["shell", "am", "start", "-W", "-n", f"{context.package_id}/.MainActivity"],
    )


def _dump_ui(context: CaseExecutionContext) -> str:
    output = _run_device_step(context, ["shell", "uiautomator", "dump", "/dev/tty"])
    if "<hierarchy" not in output:
        raise _ScenarioBlocked("fixed scenario did not expose user-visible UI")
    return output


def _parse_ui_nodes(xml: str) -> list[dict[str, str]]:
    nodes: list[dict[str, str]] = []
    for match in re.finditer(r"<node\b([^>]*)>", xml):
        attributes = {
            key: value
            for key, value in re.findall(r'(\w+)="([^"]*)"', match.group(1))
        }
        bounds = attributes.get("bounds", "")
        coordinates = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
        if coordinates:
            attributes["center_x"] = str((int(coordinates.group(1)) + int(coordinates.group(3))) // 2)
            attributes["center_y"] = str((int(coordinates.group(2)) + int(coordinates.group(4))) // 2)
        nodes.append(attributes)
    return nodes


def _normalized_user_visible_surface(xml: str) -> list[dict[str, str]]:
    """Stable semantic UI projection; screenshot pixels are existence-only proof."""
    surface: list[dict[str, str]] = []
    for node in _parse_ui_nodes(xml):
        semantic = {
            key: node[key].strip()
            for key in ("text", "content-desc", "class", "package")
            if node.get(key, "").strip()
        }
        if semantic:
            surface.append(semantic)
    return surface


def _case_user_visible_projection(case_id: str, xml: str) -> dict[str, object]:
    surface = _normalized_user_visible_surface(xml)
    visible = {
        value
        for node in surface
        for key, value in node.items()
        if key in {"text", "content-desc"}
    }
    if case_id in {"idempotent_account_sync", "two_account_household"}:
        if not visible:
            raise _ScenarioBlocked("case user-visible surface is unavailable")
        return {"caseId": case_id, "appSurfaceVisible": True}
    if case_id == "android_notification":
        if not any("每日提醒" in value or "提醒设置" in value for value in visible):
            raise _ScenarioBlocked("reminder surface is unavailable")
        return {"caseId": case_id, "reminderSurfaceVisible": True}
    if case_id == "android_audio":
        if not any(marker in value for value in visible for marker in ("暂停", "重播", "Pause", "Replay")):
            raise _ScenarioBlocked("audio controls surface is unavailable")
        return {"caseId": case_id, "audioControlsVisible": True}
    if case_id == "android_deep_link":
        if not _deep_link_invalid_fallback_is_visible(xml):
            raise _ScenarioBlocked("deep-link fallback surface is unavailable")
        return {"caseId": case_id, "invalidFallbackVisible": True}
    raise _ScenarioBlocked("case user-visible projection is not allow-listed")


def _tap_ui_label(context: CaseExecutionContext, labels: tuple[str, ...]) -> str:
    xml = _dump_ui(context)
    for node in _parse_ui_nodes(xml):
        visible = (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        if any(label == visible or label in visible for label in labels):
            if "center_x" not in node or "center_y" not in node:
                continue
            _run_device_step(
                context,
                [
                    "shell",
                    "input",
                    "tap",
                    node["center_x"],
                    node["center_y"],
                ],
            )
            return visible
    raise _ScenarioBlocked("fixed scenario user control is unavailable")


def _tap_ui_class(context: CaseExecutionContext, class_suffix: str) -> None:
    xml = _dump_ui(context)
    for node in _parse_ui_nodes(xml):
        if node.get("class", "").endswith(class_suffix) and "center_x" in node and "center_y" in node:
            _run_device_step(
                context,
                ["shell", "input", "tap", node["center_x"], node["center_y"]],
            )
            return
    raise _ScenarioBlocked("fixed scenario switch/control is unavailable")


def _verify_installed_candidate_identity(context: CaseExecutionContext) -> bool:
    """Read the immutable candidate ID from the installed APK's About UI."""
    _launch_app(context)
    try:
        _tap_ui_label(context, ("我的", "Me"))
    except _ScenarioBlocked:
        # The app may already be inside the settings subtree.
        pass
    try:
        _tap_ui_label(context, ("设置", "Settings"))
    except _ScenarioBlocked:
        pass
    _tap_ui_label(context, ("关于 BabyTalk",))
    nodes = _parse_ui_nodes(_dump_ui(context))
    visible = [
        (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        for node in nodes
    ]
    if "关于 BabyTalk" not in visible or "候选 ID" not in visible:
        raise _ScenarioBlocked("installed APK About identity is unavailable")
    label_index = visible.index("候选 ID")
    values = [value for value in visible[label_index + 1 : label_index + 4] if value]
    if not values:
        raise _ScenarioBlocked("installed APK candidate ID value is unavailable")
    return values[0] == context.candidate_id


def _dumpsys(context: CaseExecutionContext, service: str, *arguments: str) -> str:
    return _run_device_step(context, ["shell", "dumpsys", service, *arguments])


def _alarm_has_daily_reminder(output: str, package_id: str) -> bool:
    normalized = output.lower()
    component = re.escape("dailyreminderreceiver".lower())
    package = re.escape(package_id.lower())
    return bool(
        re.search(package + r"[^\n]{0,180}" + component, normalized)
        and re.search(r"pendingintentrecord|broadcastintent|type=.?broadcast", normalized)
        and "no scheduled dailyreminderreceiver" not in normalized
        and "not scheduled dailyreminderreceiver" not in normalized
    )


def _alarm_proves_daily_reminder_delivery(output: str, package_id: str) -> bool:
    normalized = output.lower()
    return bool(
        package_id.lower() in normalized
        and "dailyreminderreceiver" in normalized
        and re.search(r"(?:deliverycount|count|delivered)\s*[=:]\s*[1-9]\d*", normalized)
        and any(marker in normalized for marker in ("recent", "history", "wakeup"))
    )


def _notification_post_time_epoch_ms(output: str) -> int | None:
    match = re.search(r"\bposttime\s*=\s*([^\s,)]+)", output, re.IGNORECASE)
    if match is None:
        return None
    raw = match.group(1)
    if raw.isdigit():
        value = int(raw)
        return value if value >= 1_000_000_000_000 else value * 1000
    try:
        return int(datetime.fromisoformat(raw.replace("Z", "+00:00")).timestamp() * 1000)
    except ValueError:
        return None


def _notification_is_posted(
    output: str,
    package_id: str,
    *,
    not_before_epoch_ms: int | None = None,
) -> bool:
    normalized = output.lower()
    structurally_posted = bool(
        "notificationrecord(" in normalized
        and f"pkg={package_id.lower()}" in normalized
        and re.search(r"\bid\s*=\s*7020\b", normalized)
        and re.search(r"\bchannel\s*=\s*daily_reminder\b", normalized)
        and re.search(r"\bposttime\s*=\s*\S+", normalized)
    )
    if not structurally_posted:
        return False
    post_time = _notification_post_time_epoch_ms(output)
    return post_time is not None and (
        not_before_epoch_ms is None or post_time >= not_before_epoch_ms
    )


def _runner_case_evidence(context: CaseExecutionContext, case_id: str) -> CaseEvidence:
    """Capture runner-side evidence before harness performs its independent check."""
    if not context.device_serial:
        raise _ScenarioBlocked("fixed scenario device serial is missing")
    device_evidence = AndroidDeviceEvidence.passing(
        serial=context.device_serial,
        android_version=context.android_version,
        package_id=context.package_id,
    )
    if device_evidence.device_identity_sha256 != context.device_identity_sha256:
        raise _ScenarioBlocked("fixed scenario device identity changed")
    try:
        compatibility = read_gateway_compatibility(context.gateway_url)
    except Exception as error:
        raise _ScenarioBlocked("fixed scenario gateway evidence is unavailable") from error
    evidence = collect_case_evidence(
        candidate={
            "id": context.candidate_id,
            "apk_sha256": context.apk_sha256,
            "gateway_url": context.gateway_url,
        },
        device={"serial": context.device_serial, "package_id": context.package_id},
        device_evidence=device_evidence,
        case_id=case_id,
        compatibility=compatibility,
        context=context,
    )
    if evidence is None:
        raise _ScenarioBlocked("fixed scenario evidence is unavailable")
    return evidence


def _receipt_result(
    context: CaseExecutionContext,
    case_id: str,
    observations: dict[str, object],
) -> CaseCommandResult:
    evidence = _runner_case_evidence(context, case_id)
    receipt = {
        "schema_version": CASE_RECEIPT_SCHEMA_VERSION,
        "candidate_id": context.candidate_id,
        "apk_sha256": context.apk_sha256,
        "case_id": case_id,
        "android_device_identity_sha256": context.device_identity_sha256,
        "android_version": context.android_version,
        "package_id": context.package_id,
        "synthetic_identity_fingerprints": dict(context.identity_fingerprints),
        "evidence": evidence.to_receipt(),
        "observations": observations,
    }
    return CaseCommandResult(0, json.dumps(receipt, ensure_ascii=False, sort_keys=True), "")


def _run_idempotent_account_sync(context: CaseExecutionContext) -> CaseCommandResult:
    session: _QaSession | None = None
    try:
        session = _authenticate_fixed_identity(context, "primary_account_ref")
        event_key = _stable_event_key(context, session.installation_id)
        local_event_id = event_key.rsplit(":", 1)[-1]
        event = {
            "eventKey": event_key,
            "localEventId": local_event_id,
            "installationId": session.installation_id,
            "spaceId": "daily_care",
            "activityId": "bath_time",
            "phraseId": "bath_time_1",
            "reactionType": "cooperating",
            "clientTimestamp": "2026-01-01T00:00:00Z",
        }
        first = _require_json_object(
            _scenario_json_request(
                context=context,
                method="POST",
                path="/api/v1/sync/events",
                payload={"installationId": session.installation_id, "events": [event]},
                access_token=session.access_token,
            ),
            statuses=(200,),
        )
        retry = _require_json_object(
            _scenario_json_request(
                context=context,
                method="POST",
                path="/api/v1/sync/events",
                payload={"installationId": session.installation_id, "events": [event]},
                access_token=session.access_token,
            ),
            statuses=(200,),
        )
        bootstrap = _require_json_object(
            _scenario_json_request(
                context=context,
                method="GET",
                path="/api/v1/bootstrap",
                query={"installationId": session.installation_id},
                access_token=session.access_token,
            ),
            statuses=(200,),
        )
        events = bootstrap.get("events")
        if (
            first.get("acceptedCount") != 1
            or first.get("duplicateCount") != 0
            or retry.get("acceptedCount") != 0
            or retry.get("duplicateCount") != 1
            or first.get("acceptedEventKeys") != [event_key]
            or retry.get("duplicateEventKeys") != [event_key]
            or bootstrap.get("eventCount") != 1
            or not isinstance(events, list)
            or len(events) != 1
            or not isinstance(events[0], dict)
            or events[0].get("eventKey") != event_key
        ):
            raise _ScenarioBlocked("server did not prove idempotent sync")
        _launch_app(context)
        if not _dump_ui(context).strip():
            raise _ScenarioBlocked("APK did not expose external user behavior")
        return _receipt_result(
            context,
            "idempotent_account_sync",
            {
                "external_user_behavior_observed": True,
                "server_observable_observed": True,
                "first_write_status": "accepted",
                "retry_status": "duplicate",
                "server_event_count": 1,
            },
        )
    finally:
        _logout_fixed_identity(context, session)


def _ensure_profile_for_household(context: CaseExecutionContext, session: _QaSession) -> dict[str, object]:
    profile_response = _scenario_json_request(
        context=context,
        method="GET",
        path="/api/v1/onboarding/profile",
        access_token=session.access_token,
    )
    if profile_response.status_code == 200 and isinstance(profile_response.payload, dict):
        return profile_response.payload
    if profile_response.status_code != 404:
        raise _ScenarioBlocked("primary profile lookup failed")
    profile = _require_json_object(
        _scenario_json_request(
            context=context,
            method="PUT",
            path="/api/v1/onboarding/profile",
            payload={
                "babyName": "QA宝宝",
                "ageRange": "m18_23",
                "parentGoal": "calmer_care",
                "starter": {
                    "sceneId": "daily_care",
                    "momentId": "bath_time",
                    "activityId": "bath_time",
                    "utteranceId": "bath_time_1",
                    "phraseId": "bath_time_1",
                    "source": "catalog",
                },
                "onboardingState": "completed",
                "completedAt": "2026-01-01T00:00:00Z",
                "clientTraceId": f"qa-profile-{session.installation_id[-24:]}",
            },
            access_token=session.access_token,
        ),
        statuses=(200, 201),
    )
    return profile


def _run_two_account_household(context: CaseExecutionContext) -> CaseCommandResult:
    primary: _QaSession | None = None
    caregiver: _QaSession | None = None
    try:
        primary = _authenticate_fixed_identity(context, "primary_account_ref")
        profile = _ensure_profile_for_household(context, primary)
        caregiver = _authenticate_fixed_identity(context, "caregiver_account_ref")
        invite = _require_json_object(
            _scenario_json_request(
                context=context,
                method="POST",
                path="/api/v1/caregiver-invites",
                payload={"role": "caregiver", "source": "household_settings"},
                access_token=primary.access_token,
            ),
            statuses=(201,),
        )
        token = _required_string(invite, "token")
        household_id = _required_string(invite, "householdId")
        if profile.get("babyProfileId") is None:
            raise _ScenarioBlocked("profile did not initialize household context")
        accepted = _require_json_object(
            _scenario_json_request(
                context=context,
                method="POST",
                path="/api/v1/caregiver-invites/accept",
                payload={"token": token, "source": "household_settings"},
                access_token=caregiver.access_token,
            ),
            statuses=(200,),
        )
        shared = accepted.get("sharedContext")
        if (
            accepted.get("householdId") != household_id
            or accepted.get("role") != "caregiver"
            or not isinstance(shared, dict)
            or shared.get("householdId") != household_id
        ):
            raise _ScenarioBlocked("two-account invite acceptance was not shared safely")
        second_invite = _require_json_object(
            _scenario_json_request(
                context=context,
                method="POST",
                path="/api/v1/caregiver-invites",
                payload={"role": "caregiver", "source": "household_settings"},
                access_token=primary.access_token,
            ),
            statuses=(201,),
        )
        revoked_token = _required_string(second_invite, "token")
        revoked = _require_json_object(
            _scenario_json_request(
                context=context,
                method="POST",
                path=f"/api/v1/caregiver-invites/{quote(revoked_token, safe='')}/revoke",
                access_token=primary.access_token,
            ),
            statuses=(200,),
        )
        if revoked.get("applied") is not True or revoked.get("result") != "revoked":
            raise _ScenarioBlocked("invite revoke was not confirmed")
        revoked_accept = _scenario_json_request(
            context=context,
            method="POST",
            path="/api/v1/caregiver-invites/accept",
            payload={"token": revoked_token, "source": "household_settings"},
            access_token=caregiver.access_token,
        )
        if revoked_accept.status_code not in (400, 404, 409):
            raise _ScenarioBlocked("revoked invite remained acceptable")
        current_shared = _require_json_object(
            _scenario_json_request(
                context=context,
                method="GET",
                path="/api/v1/household/shared-context",
                access_token=caregiver.access_token,
            ),
            statuses=(200,),
        )
        if current_shared.get("householdId") != household_id:
            raise _ScenarioBlocked("shared context household boundary changed")
        _launch_app(context)
        if not _dump_ui(context).strip():
            raise _ScenarioBlocked("APK did not expose external household behavior")
        return _receipt_result(
            context,
            "two_account_household",
            {
                "external_user_behavior_observed": True,
                "server_observable_observed": True,
                "invite_created": True,
                "invite_accepted": True,
                "invite_revoked": True,
                "shared_context_isolated": True,
            },
        )
    finally:
        _logout_fixed_identity(context, caregiver)
        _logout_fixed_identity(context, primary)


def _run_android_notification(context: CaseExecutionContext) -> CaseCommandResult:
    _launch_app(context)
    scenario_started_epoch_ms = int(time.time() * 1000)
    try:
        _tap_ui_label(context, ("提醒设置", "每日提醒"))
    except _ScenarioBlocked:
        _tap_ui_label(context, ("我的", "Me"))
        _tap_ui_label(context, ("提醒设置", "每日提醒"))
    _tap_ui_class(context, "Switch")
    try:
        _tap_ui_label(context, ("允许", "Allow"))
    except _ScenarioBlocked:
        # Android < 13, or an already-granted permission, has no dialog.
        pass
    alarm_state = _dumpsys(context, "alarm")
    if not _alarm_has_daily_reminder(alarm_state, context.package_id):
        raise _ScenarioBlocked("Android scheduler did not expose daily reminder")
    delivery_state = _dumpsys(context, "alarm")
    if not _alarm_proves_daily_reminder_delivery(delivery_state, context.package_id):
        raise _ScenarioBlocked("AlarmManager has not actually delivered the reminder")
    notification_state = _dumpsys(context, "notification", "--noredact")
    if not _notification_is_posted(
        notification_state,
        context.package_id,
        not_before_epoch_ms=scenario_started_epoch_ms,
    ):
        raise _ScenarioBlocked("Android notification was not observable")
    _tap_ui_class(context, "Switch")
    cancelled_state = _dumpsys(context, "alarm")
    if _alarm_has_daily_reminder(cancelled_state, context.package_id):
        raise _ScenarioBlocked("disabling reminder left a stale schedule")
    visible = _dump_ui(context)
    if "每日提醒" not in visible and "提醒" not in visible:
        raise _ScenarioBlocked("reminder result was not user-visible")
    return _receipt_result(
        context,
        "android_notification",
        {
            "system_state_observed": True,
            "user_visible_result_observed": True,
            "notification_delivered": True,
        },
    )


def _run_android_audio(context: CaseExecutionContext) -> CaseCommandResult:
    _launch_app(context)
    _tap_ui_label(context, ("场景", "Scenes", "练习"))
    one_x_seconds = _measure_audio_duration(context, ("1.0x", "1x", "倍速"))
    two_x_seconds = _measure_audio_duration(context, ("2.0x", "2x", "倍速"))
    # A speed label alone is not proof of playback policy. Require a material
    # duration change from the same device-observed playback surface.
    if two_x_seconds >= one_x_seconds * 0.8:
        raise _ScenarioBlocked("audio speed effect was not observed")
    _tap_ui_label(context, ("暂停", "Pause"))
    paused_state = _dumpsys(context, "media_session")
    if _audio_state_is_playing(paused_state, context.package_id):
        raise _ScenarioBlocked("audio pause state was not observed")
    _tap_ui_label(context, ("继续", "Resume", "播放"))
    resumed_state = _dumpsys(context, "media_session")
    if not _audio_state_is_playing(resumed_state, context.package_id):
        raise _ScenarioBlocked("audio resume state was not observed")
    _tap_ui_label(context, ("重播", "Replay", "再来一次"))
    replayed_state = _dumpsys(context, "media_session")
    if not _audio_state_is_playing(replayed_state, context.package_id):
        raise _ScenarioBlocked("audio replay state was not observed")
    controls_state = _dump_ui(context)
    if not any(label in controls_state for label in ("暂停", "继续", "重播", "播放")):
        raise _ScenarioBlocked("audio controls were not observable")
    return _receipt_result(
        context,
        "android_audio",
        {
            "system_state_observed": True,
            "user_visible_result_observed": True,
            "audio_output_observed": True,
            "speed_effect_observed": True,
            "controls_observed": True,
        },
    )


def _audio_state_is_playing(output: str, package_id: str) -> bool:
    normalized = output.lower()
    return package_id.lower() in normalized and (
        "state=3" in normalized
        or "state_playing" in normalized
        or "playing" in normalized
    )


def _measure_audio_duration(context: CaseExecutionContext, speed_labels: tuple[str, ...]) -> float:
    _tap_ui_label(context, speed_labels)
    _tap_ui_label(context, ("播放", "听一遍", "播放音频"))
    started_at: float | None = None
    for _ in range(100):
        state = _dumpsys(context, "media_session")
        if _audio_state_is_playing(state, context.package_id):
            if started_at is None:
                started_at = time.monotonic()
        elif started_at is not None:
            return time.monotonic() - started_at
        time.sleep(0.2)
    raise _ScenarioBlocked("audio completion was not observable")


def _run_android_deep_link(context: CaseExecutionContext) -> CaseCommandResult:
    primary: _QaSession | None = None
    try:
        primary = _authenticate_fixed_identity(context, "primary_account_ref")
        _ensure_profile_for_household(context, primary)
        invite = _require_json_object(
            _scenario_json_request(
                context=context,
                method="POST",
                path="/api/v1/caregiver-invites",
                payload={"role": "caregiver", "source": "household_settings"},
                access_token=primary.access_token,
            ),
            statuses=(201,),
        )
        _safe_invite_url(_required_string(invite, "inviteUrl"))
        invite_token = quote(_required_string(invite, "token"), safe="")
        invite_uri = (
            f"babytalk://invite/open?token={invite_token}"
            "&source=invite_link&role=caregiver"
        )
        _run_device_step(context, ["shell", "am", "force-stop", context.package_id])
        _run_device_step(
            context,
            [
                "shell",
                "am",
                "start",
                "-W",
                "-a",
                "android.intent.action.VIEW",
                "-d",
                invite_uri,
                "-n",
                f"{context.package_id}/.MainActivity",
            ],
        )
        cold_ui = _dump_ui(context)
        cold_activity = _dumpsys(context, "activity", "activities")
        if not _deep_link_intent_is_active(cold_activity, context.package_id):
            raise _ScenarioBlocked("cold-start invite intent delivery was not observable")
        if not _deep_link_valid_destination_is_visible(cold_ui, foreground=False):
            raise _ScenarioBlocked("cold-start invite destination was not visible")
        _launch_app(context)
        _run_device_step(
            context,
            [
                "shell",
                "am",
                "start",
                "-W",
                "-a",
                "android.intent.action.VIEW",
                "-d",
                invite_uri,
                "-n",
                f"{context.package_id}/.MainActivity",
            ],
        )
        foreground_ui = _dump_ui(context)
        foreground_activity = _dumpsys(context, "activity", "activities")
        if not _deep_link_intent_is_active(foreground_activity, context.package_id):
            raise _ScenarioBlocked("foreground invite intent delivery was not observable")
        if not _deep_link_valid_destination_is_visible(foreground_ui, foreground=True):
            raise _ScenarioBlocked("foreground invite destination was not visible")
        invalid_uri = (
            "babytalk://invite/open?token=bad*"
            "&source=invite_link&role=caregiver"
        )
        _run_device_step(context, ["shell", "am", "force-stop", context.package_id])
        _run_device_step(
            context,
            [
                "shell",
                "am",
                "start",
                "-W",
                "-a",
                "android.intent.action.VIEW",
                "-d",
                invalid_uri,
                "-n",
                f"{context.package_id}/.MainActivity",
            ],
        )
        invalid_ui = _dump_ui(context)
        invalid_activity = _dumpsys(context, "activity", "activities")
        if not _deep_link_intent_is_active(invalid_activity, context.package_id):
            raise _ScenarioBlocked("invalid invite intent delivery was not observable")
        if not _deep_link_invalid_fallback_is_visible(invalid_ui):
            raise _ScenarioBlocked("invalid invite did not produce a safe message")
        return _receipt_result(
            context,
            "android_deep_link",
            {
                "system_state_observed": True,
                "user_visible_result_observed": True,
                "cold_start_destination_observed": True,
                "foreground_destination_observed": True,
                "invalid_link_message_observed": True,
            },
        )
    finally:
        _logout_fixed_identity(context, primary)


def _deep_link_intent_is_active(output: str, package_id: str) -> bool:
    normalized = output.lower()
    return bool(
        f"{package_id.lower()}/.mainactivity" in normalized
        and "android.intent.action.view" in normalized
        and "babytalk://invite/open" in normalized
    )


def _deep_link_valid_destination_is_visible(xml: str, *, foreground: bool) -> bool:
    exact_markers = {"邀请已接受，正在进入共享练习。"}
    if foreground:
        exact_markers.add("重复照护邀请链接已忽略。")
    visible = {
        (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        for node in _parse_ui_nodes(xml)
    }
    return bool(exact_markers & visible)


def _deep_link_invalid_fallback_is_visible(xml: str) -> bool:
    exact_markers = {
        "邀请链接缺少有效 token，已停留在首页安全入口。",
        "邀请链接不可用，已停留在首页安全入口。",
    }
    visible = {
        (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        for node in _parse_ui_nodes(xml)
    }
    return bool(exact_markers & visible)


def _safe_case_runner(
    runner: Callable[[CaseExecutionContext], CaseCommandResult],
    context: CaseExecutionContext,
) -> CaseCommandResult:
    try:
        return runner(context)
    except _ScenarioBlocked as error:
        return CaseCommandResult(77, "", str(error))
    except Exception as error:
        return CaseCommandResult(1, "", f"fixed case runner error: {type(error).__name__}")


def _idempotent_account_sync_runner(context: CaseExecutionContext) -> CaseCommandResult:
    return _safe_case_runner(_run_idempotent_account_sync, context)


def _two_account_household_runner(context: CaseExecutionContext) -> CaseCommandResult:
    return _safe_case_runner(_run_two_account_household, context)


def _android_notification_runner(context: CaseExecutionContext) -> CaseCommandResult:
    return _safe_case_runner(_run_android_notification, context)


def _android_audio_runner(context: CaseExecutionContext) -> CaseCommandResult:
    return _safe_case_runner(_run_android_audio, context)


def _android_deep_link_runner(context: CaseExecutionContext) -> CaseCommandResult:
    return _safe_case_runner(_run_android_deep_link, context)


_CASE_RUNNERS = {
    "idempotent_account_sync": _idempotent_account_sync_runner,
    "two_account_household": _two_account_household_runner,
    "android_notification": _android_notification_runner,
    "android_audio": _android_audio_runner,
    "android_deep_link": _android_deep_link_runner,
}


def run_case_command(case_id: str, *, context: CaseExecutionContext) -> CaseCommandResult:
    """Run only the fixed in-process runner for a required case.

    Manifest values never reach a process launcher. A runner not explicitly
    registered below is blocked, including future case IDs until reviewed.
    """
    runner = _CASE_RUNNERS.get(case_id)
    if runner is None:
        return CaseCommandResult(77, "", "case runner is not allow-listed")
    return runner(context)


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
        not _is_trusted_gateway_url(candidate["gateway_url"])
        or gateway_url.username
        or gateway_url.password
        or gateway_url.query
        or gateway_url.fragment
        or not _MIGRATION_VERSION.fullmatch(candidate["required_migration_version"])
    ):
        return None
    return candidate


def _is_trusted_gateway_url(value: str) -> bool:
    parsed = urlsplit(value)
    hostname = (parsed.hostname or "").lower()
    if (
        hostname not in _TRUSTED_QA_GATEWAY_HOSTS
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or parsed.path not in ("", "/")
    ):
        return False
    if hostname in {"127.0.0.1", "localhost", "::1"}:
        return parsed.scheme in {"http", "https"}
    return parsed.scheme == "https" and parsed.port in (None, 443)


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
        if not isinstance(value, dict) or set(value) != _CASE_KEYS:
            return None
        case_id = value.get("id")
        runner = value.get("runner")
        if (
            not isinstance(case_id, str)
            or not _CASE_ID.fullmatch(case_id)
            or case_id in ids
            or not isinstance(runner, str)
            or runner != case_id
            or runner not in _CASE_RUNNERS
        ):
            return None
        ids.add(case_id)
        cases.append({"id": case_id, "runner": runner})
    return cases if ids == set(REQUIRED_CASE_IDS) else None


def _validate_case_receipt(
    raw: str,
    *,
    case_id: str,
    candidate_id: str,
    apk_sha256: str,
    device_evidence: AndroidDeviceEvidence,
    identity_fingerprints: dict[str, str],
    expected_evidence: CaseEvidence,
) -> dict[str, object] | None:
    try:
        receipt = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if not isinstance(receipt, dict) or set(receipt) != _RECEIPT_KEYS:
        return None
    if (
        receipt.get("schema_version") != CASE_RECEIPT_SCHEMA_VERSION
        or receipt.get("candidate_id") != candidate_id
        or receipt.get("apk_sha256") != apk_sha256
        or receipt.get("case_id") != case_id
        or receipt.get("android_device_identity_sha256") != device_evidence.device_identity_sha256
        or receipt.get("android_version") != device_evidence.android_version
        or receipt.get("package_id") != device_evidence.package_id
        or receipt.get("synthetic_identity_fingerprints") != identity_fingerprints
        or receipt.get("evidence") != expected_evidence.to_receipt()
    ):
        return None
    evidence = receipt.get("evidence")
    if not _valid_case_evidence(evidence):
        return None
    observations = receipt.get("observations")
    if not isinstance(observations, dict) or not _valid_observations(case_id, observations):
        return None
    return {"case_id": case_id, "observations": observations}


def _valid_case_evidence(value: object) -> bool:
    if not isinstance(value, dict) or set(value) != _EVIDENCE_KEYS:
        return False
    server = value.get("server")
    adb = value.get("adb")
    user_visible = value.get("user_visible")
    if (
        not isinstance(server, dict)
        or set(server) != {"response_sha256"}
        or not isinstance(server.get("response_sha256"), str)
        or not _SHA256.fullmatch(server["response_sha256"])
        or not isinstance(adb, dict)
        or set(adb) != {"state_sha256"}
        or not isinstance(adb.get("state_sha256"), str)
        or not _SHA256.fullmatch(adb["state_sha256"])
        or not isinstance(user_visible, dict)
        or set(user_visible) != {"surface_sha256"}
        or not isinstance(user_visible.get("surface_sha256"), str)
        or not _SHA256.fullmatch(user_visible["surface_sha256"])
    ):
        return False
    return True


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


@dataclass(frozen=True)
class _BinaryCommandResult:
    exit_code: int
    stdout: bytes
    stderr: bytes


def _run_binary_command(command: list[str], *, timeout_seconds: int = _DEVICE_COMMAND_TIMEOUT_SECONDS) -> _BinaryCommandResult:
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=False,
            check=False,
            timeout=timeout_seconds,
        )
        return _BinaryCommandResult(completed.returncode, completed.stdout, completed.stderr)
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout if isinstance(error.stdout, bytes) else b""
        stderr = error.stderr if isinstance(error.stderr, bytes) else b""
        return _BinaryCommandResult(124, stdout, stderr)
    except OSError as error:
        return _BinaryCommandResult(127, b"", str(error).encode())


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _text_sha256(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _bytes_sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _canonical_json_sha256(value: object) -> str:
    return _bytes_sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode())


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
