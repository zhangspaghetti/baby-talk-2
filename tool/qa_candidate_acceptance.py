"""Fail-closed acceptance gate for one frozen Mobile QA candidate."""

from __future__ import annotations

import argparse
import hashlib
from html import unescape
import json
import re
import shlex
import subprocess
import sys
import time
import xml.etree.ElementTree as ElementTree
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
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
_APP_VERSION = re.compile(r"^[0-9]+(?:\.[0-9]+){0,3}$")
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
_UI_READY_TIMEOUT_SECONDS = 12
# `setAndAllowWhileIdle` is intentionally inexact (no exact-alarm permission).
# Android 15 may use the full ~2-minute delivery window after the fixed
# near-term target, so allow enough time for the target plus that window.
_NOTIFICATION_DELIVERY_TIMEOUT_SECONDS = 360
_ADB_VIEW_INTENT_ATTEMPTS = 2
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
_UI_DUMP_REMOTE_PATH = "/sdcard/babytalk_qa_uiautomator.xml"
_INVALID_INVITE_URI = (
    "babytalk://invite/open?token=bad*"
    "&source=invite_link&role=caregiver"
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
    # Read from the installed manifest-bound package. Never sourced from the
    # candidate manifest or environment.
    app_version: str = ""


@dataclass(frozen=True)
class AndroidDeviceEvidence:
    status: str
    android_version: str | None
    device_identity_sha256: str | None
    package_id: str | None
    install_stdout_sha256: str | None
    install_stderr_sha256: str | None
    app_version: str | None = None

    @classmethod
    def passing(
        cls,
        *,
        serial: str,
        android_version: str,
        package_id: str,
        app_version: str = "",
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
            app_version=app_version,
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
            "app_version": self.app_version,
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
    installed_package = run_device_command(["adb", "-s", serial, "shell", "dumpsys", "package", package_id])
    version = android_version.stdout.strip()
    app_version = _parse_installed_app_version(installed_package.stdout)
    if installed_package.exit_code != 0 or app_version is None:
        return AndroidDeviceEvidence.blocked()
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
        app_version=app_version,
        install_stdout=install.stdout,
        install_stderr=install.stderr,
    )


def _parse_installed_app_version(output: str) -> str | None:
    matches = re.findall(r"(?m)^\s*versionName=([^\s\r\n]+)\s*$", output)
    if len(matches) != 1:
        return None
    version = matches[0]
    return version if _APP_VERSION.fullmatch(version) else None


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
        or device_evidence.app_version is None
        or not _APP_VERSION.fullmatch(device_evidence.app_version)
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
        app_version=device_evidence.app_version,
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

    ui_dump = _dump_ui(context)
    screenshot = _run_binary_command(["adb", "-s", serial, "exec-out", "screencap", "-p"])
    if screenshot.exit_code != 0 or not screenshot.stdout:
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
        user_visible = _case_user_visible_projection(case_id, ui_dump)
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
            attempted_event_key = _stable_event_key(context, session.installation_id)
            attempted_local_event_id = attempted_event_key.rsplit(":", 1)[-1]
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
            event = _require_idempotent_bootstrap_event(bootstrap, attempted_local_event_id)
            return {
                "projection": "idempotent_sync_v1",
                "eventCount": 1,
                "eventKeySha256": _text_sha256(_required_string(event, "eventKey")),
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
        notification_time = _notification_post_time_epoch_ms(notification)
        if not _alarm_proves_daily_reminder_delivery(
            alarm,
            context.package_id,
            not_before_epoch_ms=(notification_time - 60_000) if notification_time else None,
        ):
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
    if not _APP_VERSION.fullmatch(context.app_version):
        raise _ScenarioBlocked("installed app version is unavailable")
    body = None if payload is None else json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    headers = {
        "Accept": "application/json",
        "X-App-Version": context.app_version,
    }
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


def _server_invite_deep_link(invite_url: str, token: str) -> str:
    """Convert one validated server invite into the app's fixed URI scheme."""
    safe_url = _safe_invite_url(invite_url)
    clean_token = token.strip()
    if not re.fullmatch(r"[A-Za-z0-9_-]{12,64}", clean_token):
        raise _ScenarioBlocked("server returned an unsafe invite token")
    server_token = urlsplit(safe_url).path.rstrip("/").rsplit("/", 1)[-1]
    if server_token != clean_token:
        raise _ScenarioBlocked("server invite URL token mismatch")
    return (
        "babytalk://invite/open?token="
        f"{quote(clean_token, safe='')}"
        "&source=invite_link&role=caregiver"
    )


def _stable_synthetic_phone(fingerprint: str) -> str:
    if not _SHA256.fullmatch(fingerprint):
        raise _ScenarioBlocked("synthetic identity fingerprint is invalid")
    suffix = int(fingerprint[:16], 16) % 100_000_000
    return f"{_QA_PHONE_PREFIX}{suffix:08d}"


def _fresh_deep_link_recipient_fingerprint(
    context: CaseExecutionContext,
    invite_token: str,
) -> str:
    """Bind one isolated invite recipient to this server-issued invite only."""
    seed = context.identity_fingerprints.get("idempotent_event_id")
    if seed is None or not _SHA256.fullmatch(seed):
        raise _ScenarioBlocked("synthetic deep-link recipient is missing")
    if not re.fullmatch(r"[A-Za-z0-9_-]{12,64}", invite_token):
        raise _ScenarioBlocked("server returned an unsafe invite token")
    return hashlib.sha256(
        f"{context.candidate_id}|{context.package_id}|{seed}|{invite_token}".encode("utf-8")
    ).hexdigest()


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


def _require_idempotent_bootstrap_event(
    bootstrap: dict[str, object],
    attempted_local_event_id: str,
) -> dict[str, object]:
    """Require one server event with its projected installation reference."""
    if bootstrap.get("eventCount") != 1:
        raise _ScenarioBlocked("independent sync projection is unavailable")
    events = bootstrap.get("events")
    projected_installation_id = bootstrap.get("installationId")
    if (
        not isinstance(events, list)
        or len(events) != 1
        or not isinstance(projected_installation_id, str)
        or not projected_installation_id.strip()
    ):
        raise _ScenarioBlocked("independent sync projection is unavailable")

    matching: list[dict[str, object]] = []
    for event in events:
        if not isinstance(event, dict):
            continue
        event_key = event.get("eventKey")
        event_local_event_id = event.get("localEventId")
        event_installation_id = event.get("installationId")
        if not all(
            isinstance(value, str)
            for value in (event_key, event_local_event_id, event_installation_id)
        ):
            continue
        try:
            wire_installation_id, wire_local_event_id = event_key.rsplit(":", 1)
        except ValueError:
            continue
        if (
            event_installation_id == projected_installation_id
            and wire_installation_id == projected_installation_id
            and event_local_event_id == attempted_local_event_id
            and wire_local_event_id == attempted_local_event_id
        ):
            matching.append(event)

    if len(matching) != 1:
        raise _ScenarioBlocked("independent sync projection is unavailable")
    return matching[0]


def _authenticate_fixed_identity(
    context: CaseExecutionContext,
    identity_key: str,
) -> _QaSession:
    fingerprint = context.identity_fingerprints.get(identity_key)
    if fingerprint is None:
        raise _ScenarioBlocked(f"synthetic identity {identity_key} is missing")
    return _authenticate_synthetic_fingerprint(context, fingerprint)


def _authenticate_synthetic_fingerprint(
    context: CaseExecutionContext,
    fingerprint: str,
) -> _QaSession:
    if not _SHA256.fullmatch(fingerprint):
        raise _ScenarioBlocked("synthetic identity fingerprint is invalid")
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


def _is_safe_invite_intent_uri(value: str) -> bool:
    parsed = urlsplit(value)
    if (
        parsed.scheme != "babytalk"
        or parsed.hostname != "invite"
        or parsed.path != "/open"
        or parsed.username
        or parsed.password
        or parsed.fragment
    ):
        return False
    query_parts = parsed.query.split("&") if parsed.query else []
    if len(query_parts) != 3 or any("=" not in part for part in query_parts):
        return False
    query = dict(part.split("=", 1) for part in query_parts)
    if set(query) != {"token", "source", "role"}:
        return False
    return (
        bool(re.fullmatch(r"[A-Za-z0-9_-]{12,64}", query["token"]))
        and query["source"] == "invite_link"
        and query["role"] == "caregiver"
    )


def _run_view_intent(context: CaseExecutionContext, uri: str) -> str:
    """Send one fixed VIEW intent, retrying only bounded ADB transport failures."""
    if uri != _INVALID_INVITE_URI and not _is_safe_invite_intent_uri(uri):
        raise _ScenarioBlocked("fixed invite intent is unsafe")
    arguments = [
        "shell",
        "am start -W -a android.intent.action.VIEW -d " + shlex.quote(uri),
    ]
    last_error: _ScenarioBlocked | None = None
    for _ in range(_ADB_VIEW_INTENT_ATTEMPTS):
        try:
            return _run_device_step(context, arguments)
        except _ScenarioBlocked as error:
            last_error = error
    raise last_error or _ScenarioBlocked("fixed invite intent could not start")


def _launch_app(context: CaseExecutionContext) -> None:
    # Every fixed scenario starts from a cold MainActivity. This prevents a
    # previous case's settings/about/practice route from changing which label
    # the next allow-listed tap resolves.
    _run_device_step(context, ["shell", "am", "force-stop", context.package_id])
    _run_device_step(
        context,
        ["shell", "am", "start", "-W", "-n", f"{context.package_id}/.MainActivity"],
    )
def _require_ui_label(context: CaseExecutionContext, labels: tuple[str, ...]) -> str:
    """Require one allow-listed semantic label on the current user surface."""
    return _find_ui_label(context, labels, wait_seconds=_UI_READY_TIMEOUT_SECONDS)


def _navigate_to_reminder_controls(context: CaseExecutionContext) -> None:
    """Cold-start and enter reminder settings through fixed semantic labels."""
    _launch_app(context)
    _tap_ui_label(context, ("我", "我的", "Me"), wait_seconds=_UI_READY_TIMEOUT_SECONDS)
    _tap_ui_label(
        context,
        ("提醒设置", "每日提醒", "Reminder settings", "Daily reminder"),
        wait_seconds=_UI_READY_TIMEOUT_SECONDS,
    )
    _require_ui_label(
        context,
        ("每日提醒", "提醒设置", "Daily reminder", "Reminder settings"),
    )


def _navigate_to_care_controls(context: CaseExecutionContext) -> None:
    """Cold-start and enter one care activity before audio assertions."""
    _launch_app(context)
    _tap_ui_label(context, ("场景", "Scenes", "练习", "Practice"))
    _tap_ui_label(
        context,
        ("现在说一句", "Say one sentence", "Speak now", "Continue this activity"),
        wait_seconds=_UI_READY_TIMEOUT_SECONDS,
    )
    _find_ui_label(
        context,
        (
            "暂停",
            "暂停音频",
            "播放音频",
            "听一下",
            "Pause",
            "Play audio",
        ),
        wait_seconds=_SCENARIO_TIMEOUT_SECONDS,
    )


def _dump_ui(context: CaseExecutionContext) -> str:
    remote_path = _UI_DUMP_REMOTE_PATH
    try:
        _run_device_step(context, ["shell", "uiautomator", "dump", remote_path])
        result = _run_binary_command(
            ["adb", "-s", context.device_serial, "exec-out", "cat", remote_path]
        )
        if result.exit_code != 0 or not result.stdout:
            raise _ScenarioBlocked("fixed scenario did not expose user-visible UI")
        try:
            xml = result.stdout.decode("utf-8")
            root = ElementTree.fromstring(xml)
        except (UnicodeDecodeError, ElementTree.ParseError):
            raise _ScenarioBlocked("fixed scenario did not expose user-visible UI") from None
        if root.tag != "hierarchy":
            raise _ScenarioBlocked("fixed scenario did not expose user-visible UI")
        return xml
    finally:
        if context.device_serial and _ANDROID_SERIAL.fullmatch(context.device_serial):
            try:
                run_device_command(
                    ["adb", "-s", context.device_serial, "shell", "rm", "-f", remote_path]
                )
            except Exception:
                # Cleanup is best effort and must not hide scenario evidence failures.
                pass


def _parse_ui_nodes(xml: str) -> list[dict[str, str]]:
    nodes: list[dict[str, str]] = []
    for match in re.finditer(r"<node\b([^>]*)>", xml):
        attributes = {
            key: value
            for key, value in re.findall(r'([\w-]+)="([^"]*)"', match.group(1))
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


def _find_ui_label(
    context: CaseExecutionContext,
    labels: tuple[str, ...],
    *,
    wait_seconds: float = 0,
) -> str:
    deadline = time.monotonic() + wait_seconds
    while True:
        try:
            nodes = _parse_ui_nodes(_dump_ui(context))
        except _ScenarioBlocked:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.5)
            continue
        for node in nodes:
            visible = unescape(
                (node.get("text", "") + " " + node.get("content-desc", "")).strip()
            )
            if any(label == visible or label in visible for label in labels):
                return visible
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("fixed scenario user control is unavailable")
        time.sleep(0.5)


def _tap_ui_label(
    context: CaseExecutionContext,
    labels: tuple[str, ...],
    *,
    wait_seconds: float = 0,
) -> str:
    deadline = time.monotonic() + wait_seconds
    while True:
        try:
            nodes = _parse_ui_nodes(_dump_ui(context))
        except _ScenarioBlocked:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.5)
            continue
        for node in nodes:
            if node.get("clickable", "true").lower() == "false":
                continue
            visible = unescape(
                (node.get("text", "") + " " + node.get("content-desc", "")).strip()
            )
            if (
                any(label == visible or label in visible for label in labels)
                and "center_x" in node
                and "center_y" in node
            ):
                _run_device_step(
                    context,
                    ["shell", "input", "tap", node["center_x"], node["center_y"]],
                )
                return visible
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("fixed scenario user control is unavailable")
        time.sleep(0.5)


def _tap_signed_in_account_card(context: CaseExecutionContext) -> None:
    """Open the signed-in Me card without retaining its masked phone value."""
    for node in _parse_ui_nodes(_dump_ui(context)):
        if node.get("clickable", "true").lower() == "false":
            continue
        visible = unescape(
            (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        )
        if re.search(r"1\d{2}\*{4}\d{4}", visible) and "center_x" in node and "center_y" in node:
            _tap_ui_node(context, node)
            return
    raise _ScenarioBlocked("fixed scenario signed-in account card is unavailable")


def _tap_ui_label_after_scroll(
    context: CaseExecutionContext,
    labels: tuple[str, ...],
    *,
    scroll_attempts: int = 3,
) -> str:
    """Find one account action after bounded visible ScrollView movement."""
    try:
        return _tap_ui_label(context, labels, wait_seconds=0)
    except _ScenarioBlocked:
        pass
    for _ in range(scroll_attempts):
        scroll_view = next(
            (
                node
                for node in _parse_ui_nodes(_dump_ui(context))
                if node.get("class", "").endswith("ScrollView")
                and "center_x" in node
                and "bounds" in node
            ),
            None,
        )
        if scroll_view is None:
            break
        bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", scroll_view["bounds"])
        if bounds is None:
            break
        _, top, _, bottom = (int(value) for value in bounds.groups())
        if bottom - top < 240:
            break
        _run_device_step(
            context,
            [
                "shell",
                "input",
                "swipe",
                scroll_view["center_x"],
                str(bottom - 120),
                scroll_view["center_x"],
                str(top + 120),
                "250",
            ],
        )
        try:
            return _tap_ui_label(context, labels, wait_seconds=2)
        except _ScenarioBlocked:
            continue
    raise _ScenarioBlocked("fixed scenario user control is unavailable")


def _tap_ui_class(context: CaseExecutionContext, class_suffix: str) -> None:
    xml = _dump_ui(context)
    for node in _parse_ui_nodes(xml):
        if node.get("class", "").endswith(class_suffix) and "center_x" in node and "center_y" in node:
            _tap_ui_node(context, node)
            return
    raise _ScenarioBlocked("fixed scenario switch/control is unavailable")


def _tap_ui_class_at(
    context: CaseExecutionContext,
    class_suffix: str,
    index: int,
    *,
    wait_seconds: float = _UI_READY_TIMEOUT_SECONDS,
) -> None:
    deadline = time.monotonic() + wait_seconds
    while True:
        matches = [
            node
            for node in _parse_ui_nodes(_dump_ui(context))
            if node.get("class", "").endswith(class_suffix)
            and node.get("clickable", "true").lower() != "false"
        ]
        if index < len(matches):
            _tap_ui_node(context, matches[index])
            return
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("fixed scenario user control is unavailable")
        time.sleep(0.5)


def _replace_focused_text(context: CaseExecutionContext, value: str) -> None:
    if not re.fullmatch(r"[0-9]{1,16}", value):
        raise _ScenarioBlocked("fixed scenario input is invalid")
    _run_device_step(context, ["shell", "input", "keyevent", "123"])
    time.sleep(0.25)
    for _ in range(16):
        _run_device_step(context, ["shell", "input", "keyevent", "67"])
        time.sleep(0.25)
    _run_device_step(context, ["shell", "input", "text", value])


def _sign_in_apk_identity(
    context: CaseExecutionContext,
    identity_key: str,
    *,
    recipient_fingerprint: str | None = None,
) -> None:
    """Create a persisted APK session through the same visible auth UI as a user."""
    fingerprint = (
        recipient_fingerprint
        if recipient_fingerprint is not None
        else context.identity_fingerprints.get(identity_key)
    )
    if fingerprint is None:
        raise _ScenarioBlocked("synthetic deep-link recipient is missing")
    if not _SHA256.fullmatch(fingerprint):
        raise _ScenarioBlocked("synthetic deep-link recipient is invalid")

    def run_stage(stage: str, action: Callable[[], object]) -> object:
        try:
            return action()
        except _ScenarioBlocked as error:
            raise _ScenarioBlocked(f"deep-link sign-in {stage}: {error}") from error

    _launch_app(context)
    try:
        _tap_ui_label(
            context,
            ("我", "我的", "Me"),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        )
    except _ScenarioBlocked as me_error:
        try:
            _tap_ui_label(
                context,
                ("返回", "Back"),
                wait_seconds=_UI_READY_TIMEOUT_SECONDS,
            )
        except _ScenarioBlocked:
            raise _ScenarioBlocked(f"deep-link sign-in me: {me_error}") from me_error
        run_stage(
            "me",
            lambda: _tap_ui_label(
                context,
                ("我", "我的", "Me"),
                wait_seconds=_UI_READY_TIMEOUT_SECONDS,
            ),
        )
    try:
        account_entry = run_stage(
            "account",
            lambda: _tap_ui_label(
                context,
                ("登录后同步数据", "已用 ", "登录", "Sign in"),
                wait_seconds=_UI_READY_TIMEOUT_SECONDS,
            ),
        )
        has_signed_in_account = "已用 " in str(account_entry)
    except _ScenarioBlocked:
        run_stage("signed_in_account", lambda: _tap_signed_in_account_card(context))
        has_signed_in_account = True
    if has_signed_in_account:
        run_stage(
            "sign_out",
            lambda: _tap_ui_label_after_scroll(
                context,
                ("退出为未登录", "Sign out", "Log out"),
            ),
        )
        run_stage(
            "sign_out_confirm",
            lambda: _tap_ui_label(
                context,
                ("确认退出", "Confirm sign out", "Confirm log out"),
                wait_seconds=_UI_READY_TIMEOUT_SECONDS,
            ),
        )
        auth_form_ready = False
        try:
            _find_ui_label(
                context,
                (
                    "账号入口已可见，但你还没有登录",
                    "当前未登录账号",
                    "Not signed in",
                ),
                wait_seconds=_UI_READY_TIMEOUT_SECONDS,
            )
        except _ScenarioBlocked as signed_out_error:
            # AuthScreen may be the post-logout destination for a deep-link
            # account entry. It is already the required fresh form; avoid
            # sending a second launch/back sequence that loses that route.
            try:
                _find_ui_label(
                    context,
                    ("验证码登录", "验证码登录页面", "Code sign-in", "Sign-in"),
                    wait_seconds=_UI_READY_TIMEOUT_SECONDS,
                )
                auth_form_ready = True
            except _ScenarioBlocked:
                raise signed_out_error
        if not auth_form_ready:
            _launch_app(context)
            run_stage(
                "me_after_sign_out",
                lambda: _tap_ui_label(
                    context,
                    ("我", "我的", "Me"),
                    wait_seconds=_UI_READY_TIMEOUT_SECONDS,
                ),
            )
            run_stage(
                "account_after_sign_out",
                lambda: _tap_ui_label(
                    context,
                    ("登录后同步数据", "登录", "Sign in"),
                    wait_seconds=_UI_READY_TIMEOUT_SECONDS,
                ),
            )
    run_stage("phone_field", lambda: _tap_ui_class_at(context, "EditText", 0))
    run_stage("phone_value", lambda: _replace_focused_text(context, _stable_synthetic_phone(fingerprint)))
    # The form starts with only phone input. Request the challenge through the
    # same visible CAPTCHA flow as a real user before looking for OTP input.
    run_stage(
        "close_phone_keyboard",
        lambda: _run_device_step(context, ["shell", "input", "keyevent", "4"]),
    )
    run_stage(
        "request_code",
        lambda: _tap_ui_label(
            context,
            ("获取验证码", "发送验证码", "Get verification code", "Send code"),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        ),
    )
    run_stage(
        "captcha",
        lambda: _tap_ui_label(
            context,
            (
                "模拟验证通过",
                "模拟人机校验通过并发送验证码",
                "Pass CAPTCHA",
                "Complete verification",
            ),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        ),
    )
    run_stage("code_field", lambda: _tap_ui_class_at(context, "EditText", 1))
    run_stage("code_value", lambda: _replace_focused_text(context, _QA_VERIFICATION_CODE))
    # Pinput dismisses the IME when the sixth digit completes the field. Do
    # not send an unconditional Android back key here: on the candidate
    # emulator the IME is already hidden, so that key would pop the auth route
    # before the consent row is scrolled into view.
    # The V11 auth page exposes the terms row as one merged Flutter semantics
    # node (`android.view.View`), so a native CheckBox class lookup is not
    # stable on Android. Tap the user-visible consent label instead.
    run_stage(
        "consent",
        lambda: _tap_ui_label_after_scroll(
            context,
            (
                "同意服务条款和隐私协议",
                "Agree to the terms and privacy policy",
                "I agree to the terms and privacy policy",
            ),
        ),
    )
    run_stage(
        "submit",
        lambda: _tap_ui_label(
            context,
            (
                "登录并同意",
                "提交验证码登录",
                "提交验证码完成注册",
                "Sign in and agree",
                "Submit verification code",
                "登录 / 注册",
            ),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        ),
    )
    try:
        _find_ui_label(
            context,
            ("已登录", "退出登录", "Account settings", "账号设置"),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        )
    except _ScenarioBlocked:
        run_stage(
            "confirmed",
            lambda: _find_ui_label(
                context,
                ("播放音频", "重播", "听一下", "现在说一句"),
                wait_seconds=_UI_READY_TIMEOUT_SECONDS,
            ),
        )


def _verify_installed_candidate_identity(context: CaseExecutionContext) -> bool:
    """Read the immutable candidate ID from the installed APK's About UI."""
    _launch_app(context)
    try:
        _tap_ui_label(
            context,
            ("我的", "我", "Me"),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        )
    except _ScenarioBlocked:
        # The app may already be inside the settings subtree.
        pass
    try:
        _tap_ui_label(
            context,
            ("设置", "Settings"),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        )
    except _ScenarioBlocked:
        pass
    try:
        _tap_ui_label(
            context,
            ("关于 BabyTalk",),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        )
    except _ScenarioBlocked:
        # Settings is a bounded ScrollView on the release APK; the About tile
        # can be below the initial viewport after a cold launch or a prior
        # scenario. Retry through the shared bounded-scroll helper so identity
        # verification does not depend on whatever route happened to be open.
        _tap_ui_label_after_scroll(
            context,
            ("关于 BabyTalk",),
            scroll_attempts=5,
        )
    nodes = _parse_ui_nodes(_dump_ui(context))
    visible = [
        unescape((node.get("text", "") + " " + node.get("content-desc", "")).strip())
        for node in nodes
    ]
    if not any("关于 BabyTalk" in value for value in visible):
        raise _ScenarioBlocked("installed APK About identity is unavailable")
    flattened = [line.strip() for value in visible for line in value.splitlines() if line.strip()]
    if "候选 ID" not in flattened:
        raise _ScenarioBlocked("installed APK candidate ID value is unavailable")
    label_index = flattened.index("候选 ID")
    values = flattened[label_index + 1 : label_index + 4]
    if not values:
        raise _ScenarioBlocked("installed APK candidate ID value is unavailable")
    return values[0] == context.candidate_id


def _dumpsys(context: CaseExecutionContext, service: str, *arguments: str) -> str:
    return _run_device_step(context, ["shell", "dumpsys", service, *arguments])


def _alarm_has_daily_reminder(output: str, package_id: str) -> bool:
    normalized = output.lower()
    pending = normalized
    pending_match = re.search(
        r"\b\d+\s+pending alarms:(?P<body>[\s\S]*?)"
        r"\n\s*pending alarms per uid:",
        normalized,
    )
    if pending_match is not None:
        pending = pending_match.group("body")
    else:
        # Keep historical snapshots and Alarm Stats from looking like a live
        # PendingIntent when an alarm has just been cancelled.
        pending = re.split(r"\n\s*(?:app alarm history|alarm stats):", normalized, maxsplit=1)[0]
    component = re.escape("dailyreminderreceiver".lower())
    package = re.escape(package_id.lower())
    return bool(
        re.search(package + r"[^\n]{0,180}" + component, pending)
        and re.search(r"pendingintentrecord|broadcastintent|type=.?broadcast", pending)
        and "no scheduled dailyreminderreceiver" not in pending
        and "not scheduled dailyreminderreceiver" not in pending
    )


def _alarm_proves_daily_reminder_delivery(
    output: str,
    package_id: str,
    *,
    not_before_epoch_ms: int | None = None,
) -> bool:
    normalized = output.lower()
    history_count = re.search(
        r"(?:deliverycount|count|delivered)\s*[=:]\s*[1-9]\d*",
        normalized,
    )
    # Android 15's `dumpsys alarm` does not expose a per-PendingIntent
    # delivery counter. Once an inexact repeating RTC alarm has fired, it
    # retains the scheduled `origWhen` while reporting a negative elapsed
    # trigger; pair that system transition with an exact newly-posted
    # NotificationRecord below before accepting the case.
    due_repeating_alarm = re.search(
        re.escape(package_id.lower())
        + r"[\s\S]{0,360}dailyreminderreceiver[\s\S]{0,360}"
        + r"type=rtc_wakeup[\s\S]{0,360}whenelapsed=-\d",
        normalized,
    )
    # The app intentionally uses a one-shot `setAndAllowWhileIdle` alarm so
    # Android 15 can deliver an imminent reminder without exact-alarm access.
    # DailyReminderReceiver cancels that fired PendingIntent before scheduling
    # the next day, so AlarmManager exposes the delivery as a recent
    # `Removal history` snapshot rather than a repeating due alarm.
    one_shot_removal_history = re.search(
        r"removal history:[\s\S]{0,5000}"
        + re.escape(package_id.lower())
        + r"/\.dailyreminderreceiver[\s\S]{0,240}"
        + r"reason=(?:pi_)?cancelled",
        normalized,
    )
    recent_one_shot_removal = False
    if one_shot_removal_history:
        if not_before_epoch_ms is None:
            recent_one_shot_removal = True
        else:
            for raw in re.findall(
                r"rtc=(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d{1,3})?)",
                one_shot_removal_history.group(0),
            ):
                try:
                    removal_time = datetime.fromisoformat(raw).replace(tzinfo=UTC)
                except ValueError:
                    continue
                if int(removal_time.timestamp() * 1000) >= not_before_epoch_ms:
                    recent_one_shot_removal = True
                    break
    return bool(
        package_id.lower() in normalized
        and "dailyreminderreceiver" in normalized
        and (history_count or due_repeating_alarm or recent_one_shot_removal)
        and any(marker in normalized for marker in ("history", "wakeup"))
    )


def _notification_post_time_epoch_ms(output: str) -> int | None:
    return _notification_post_time_epoch_ms_with_offset(output)


def _notification_post_time_epoch_ms_with_offset(
    output: str,
    *,
    elapsed_epoch_offset_ms: int | None = None,
) -> int | None:
    match = re.search(r"\bposttime\s*=\s*([^\s,)]+)", output, re.IGNORECASE)
    if match is None:
        elapsed_match = re.search(
            r"\bposttimeelapsedms\s*=\s*(\d+)",
            output,
            re.IGNORECASE,
        )
        if elapsed_match is None or elapsed_epoch_offset_ms is None:
            return None
        return int(elapsed_match.group(1)) + elapsed_epoch_offset_ms
    raw = match.group(1)
    if raw.isdigit():
        value = int(raw)
        return value if value >= 1_000_000_000_000 else value * 1000
    try:
        return int(datetime.fromisoformat(raw.replace("Z", "+00:00")).timestamp() * 1000)
    except ValueError:
        return None


def _alarm_elapsed_epoch_offset_ms(output: str) -> int | None:
    match = re.search(
        r"nowrtc\s*=\s*(\d+)=.*?nowelapsed\s*=\s*(\d+)",
        output,
        re.IGNORECASE | re.DOTALL,
    )
    if match is None:
        return None
    return int(match.group(1)) - int(match.group(2))


def _notification_is_posted(
    output: str,
    package_id: str,
    *,
    not_before_epoch_ms: int | None = None,
    elapsed_epoch_offset_ms: int | None = None,
) -> bool:
    normalized = output.lower()
    has_post_time = bool(
        re.search(r"\bposttime(?:elapsedms)?\s*=\s*\S+", normalized)
    )
    structurally_posted = bool(
        "notificationrecord(" in normalized
        and f"pkg={package_id.lower()}" in normalized
        and re.search(r"\bid\s*=\s*7020\b", normalized)
        and re.search(r"\bchannel\s*=\s*daily_reminder\b", normalized)
        and has_post_time
    )
    if not structurally_posted:
        return False
    if not_before_epoch_ms is None:
        return True
    post_time = _notification_post_time_epoch_ms_with_offset(
        output,
        elapsed_epoch_offset_ms=elapsed_epoch_offset_ms,
    )
    return post_time is not None and post_time >= not_before_epoch_ms


def _runner_case_evidence(context: CaseExecutionContext, case_id: str) -> CaseEvidence:
    """Capture runner-side evidence before harness performs its independent check."""
    if not context.device_serial:
        raise _ScenarioBlocked("fixed scenario device serial is missing")
    device_evidence = AndroidDeviceEvidence.passing(
        serial=context.device_serial,
        android_version=context.android_version,
        package_id=context.package_id,
        app_version=context.app_version,
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
        _require_idempotent_bootstrap_event(bootstrap, local_event_id)
        first_created = (
            first.get("acceptedCount") == 1
            and first.get("duplicateCount") == 0
            and first.get("acceptedEventKeys") == [event_key]
        )
        first_already_persisted = (
            first.get("acceptedCount") == 0
            and first.get("duplicateCount") == 1
            and first.get("duplicateEventKeys") == [event_key]
        )
        retry_is_duplicate = (
            retry.get("acceptedCount") == 0
            and retry.get("duplicateCount") == 1
            and retry.get("duplicateEventKeys") == [event_key]
        )
        # A frozen manifest intentionally reuses one event identity. A second
        # acceptance run must prove that exact persisted event remains a
        # duplicate rather than failing merely because a prior run created it.
        if not (first_created or first_already_persisted) or not retry_is_duplicate:
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
                "first_write_status": "accepted" if first_created else "already_persisted",
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
                # Keep this deterministic synthetic trace independent of the
                # installation digest. A hex tail can contain an 11-digit
                # run and is correctly rejected as phone-like private data.
                "clientTraceId": "qa-profile-v1",
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
        acceptance_response = _scenario_json_request(
            context=context,
            method="POST",
            path="/api/v1/caregiver-invites/accept",
            payload={"token": token, "source": "household_settings"},
            access_token=caregiver.access_token,
        )
        if acceptance_response.status_code == 200:
            accepted = _require_json_object(acceptance_response, statuses=(200,))
            shared = accepted.get("sharedContext")
            if (
                accepted.get("householdId") != household_id
                or accepted.get("role") != "caregiver"
                or not isinstance(shared, dict)
                or shared.get("householdId") != household_id
            ):
                raise _ScenarioBlocked("two-account invite acceptance was not shared safely")
        elif acceptance_response.status_code == 409:
            # A frozen synthetic recipient can already be a member after an
            # earlier acceptance run. Prove it remains isolated to the same
            # household, then remove this run's otherwise-unused invite.
            existing_shared = _require_json_object(
                _scenario_json_request(
                    context=context,
                    method="GET",
                    path="/api/v1/household/shared-context",
                    access_token=caregiver.access_token,
                ),
                statuses=(200,),
            )
            if (
                existing_shared.get("householdId") != household_id
                or existing_shared.get("role") != "caregiver"
            ):
                raise _ScenarioBlocked("existing caregiver membership was not isolated")
            unused_invite = _require_json_object(
                _scenario_json_request(
                    context=context,
                    method="POST",
                    path=f"/api/v1/caregiver-invites/{quote(token, safe='')}/revoke",
                    access_token=primary.access_token,
                ),
                statuses=(200,),
            )
            if unused_invite.get("applied") is not True:
                raise _ScenarioBlocked("existing caregiver invite cleanup failed")
        else:
            raise _ScenarioBlocked(f"fixed scenario HTTP status {acceptance_response.status_code}")
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


def _tap_ui_node(context: CaseExecutionContext, node: dict[str, str]) -> None:
    if "center_x" not in node or "center_y" not in node:
        raise _ScenarioBlocked("fixed scenario user control is unavailable")
    x = node["center_x"]
    if node.get("class", "").endswith("Switch"):
        bounds = node.get("bounds", "")
        match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
        if match is None:
            raise _ScenarioBlocked("fixed scenario switch geometry is unavailable")
        left, _, right, _ = (int(part) for part in match.groups())
        if right - left < 48:
            raise _ScenarioBlocked("fixed scenario switch geometry is unavailable")
        # Flutter exposes a card-sized semantics bound for Switch. Its thumb is
        # at the trailing edge; a card-center tap does not toggle it.
        x = str(right - max(48, (right - left) // 10))
    _run_device_step(
        context,
        ["shell", "input", "tap", x, node["center_y"]],
    )


def _device_clock_time(context: CaseExecutionContext) -> tuple[int, int]:
    value = _run_device_step(context, ["shell", "date", "+%H:%M"]).strip()
    match = re.fullmatch(r"([01]\d|2[0-3]):([0-5]\d)", value)
    if match is None:
        raise _ScenarioBlocked("Android clock is unavailable")
    return int(match.group(1)), int(match.group(2))


def _set_time_picker_value(context: CaseExecutionContext, index: int, value: int) -> None:
    edit_fields = [
        node
        for node in _parse_ui_nodes(_dump_ui(context))
        if node.get("class", "").endswith("EditText")
        and node.get("clickable", "true").lower() != "false"
    ]
    if len(edit_fields) != 2 or index not in (0, 1):
        raise _ScenarioBlocked("Android time picker fields are unavailable")
    _tap_ui_node(context, edit_fields[index])
    # The text-mode picker opens the IME asynchronously.  Give the tapped
    # EditText time to become focused before sending keyevents; otherwise the
    # first field can retain its old value and append the replacement digit.
    time.sleep(0.5)
    _run_device_step(context, ["shell", "input", "keyevent", "123"])
    time.sleep(0.25)
    for _ in range(4):
        _run_device_step(context, ["shell", "input", "keyevent", "67"])
        time.sleep(0.25)
    _run_device_step(context, ["shell", "input", "text", f"{value:02d}"])
    time.sleep(0.5)


def _schedule_near_term_daily_reminder(context: CaseExecutionContext) -> None:
    hour, minute = _device_clock_time(context)
    target = datetime(2000, 1, 1, hour, minute) + timedelta(minutes=3)
    target_hour = target.hour
    target_minute = target.minute

    switches = [
        node
        for node in _parse_ui_nodes(_dump_ui(context))
        if node.get("class", "").endswith("Switch")
    ]
    if len(switches) != 1:
        raise _ScenarioBlocked("Android reminder switch is unavailable")
    if switches[0].get("checked", "false").lower() != "true":
        _tap_ui_node(context, switches[0])
        _allow_notification_permission_if_prompted(context)
        _find_ui_label(
            context,
            ("提醒时间", "Reminder time"),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        )

    _tap_ui_label(context, ("修改时间", "Change time"), wait_seconds=_UI_READY_TIMEOUT_SECONDS)
    _tap_ui_label(
        context,
        ("切换到文本输入模式", "Switch to text input mode"),
        wait_seconds=_UI_READY_TIMEOUT_SECONDS,
    )
    picker_xml = _dump_ui(context)
    picker_visible = {
        (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        for node in _parse_ui_nodes(picker_xml)
    }
    has_period_selector = any(
        marker in value
        for value in picker_visible
        for marker in ("上午", "下午", "AM", "PM")
    )
    _set_time_picker_value(
        context,
        0,
        (target_hour % 12 or 12) if has_period_selector else target_hour,
    )
    _set_time_picker_value(context, 1, target_minute)
    if has_period_selector:
        _tap_ui_label(
            context,
            ("上午", "AM") if target_hour < 12 else ("下午", "PM"),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        )
    _tap_ui_label(context, ("确定", "OK"), wait_seconds=_UI_READY_TIMEOUT_SECONDS)


def _allow_notification_permission_if_prompted(context: CaseExecutionContext) -> None:
    try:
        _tap_ui_label(context, ("允许", "Allow"), wait_seconds=5)
    except _ScenarioBlocked:
        # Android < 13, previously granted, or already denied permission.
        return


def _wait_for_notification_delivery(
    context: CaseExecutionContext,
    *,
    not_before_epoch_ms: int,
) -> None:
    deadline = time.monotonic() + _NOTIFICATION_DELIVERY_TIMEOUT_SECONDS
    scheduler_observed = False
    while True:
        alarm_state = _dumpsys(context, "alarm")
        scheduler_observed = scheduler_observed or _alarm_has_daily_reminder(
            alarm_state,
            context.package_id,
        )
        notification_state = _dumpsys(context, "notification", "--noredact")
        if (
            scheduler_observed
            and _alarm_proves_daily_reminder_delivery(
                alarm_state,
                context.package_id,
                not_before_epoch_ms=not_before_epoch_ms,
            )
            and _notification_is_posted(
                notification_state,
                context.package_id,
                not_before_epoch_ms=not_before_epoch_ms,
                elapsed_epoch_offset_ms=_alarm_elapsed_epoch_offset_ms(alarm_state),
            )
        ):
            return
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("Android reminder delivery was not observable")
        time.sleep(1)


def _run_android_notification(context: CaseExecutionContext) -> CaseCommandResult:
    _navigate_to_reminder_controls(context)
    _schedule_near_term_daily_reminder(context)
    scenario_started_epoch_ms = int(time.time() * 1000)
    _allow_notification_permission_if_prompted(context)
    _wait_for_notification_delivery(context, not_before_epoch_ms=scenario_started_epoch_ms)
    _tap_ui_class(context, "Switch")
    deadline = time.monotonic() + _UI_READY_TIMEOUT_SECONDS
    while _alarm_has_daily_reminder(
        _dumpsys(context, "alarm"),
        context.package_id,
    ):
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("disabling reminder left a stale schedule")
        # The notifier persists the setting and cancels AlarmManager on the
        # platform channel asynchronously after the Switch tap.
        time.sleep(0.25)
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
    def run_stage(stage: str, action: Callable[[], object]) -> object:
        try:
            return action()
        except _ScenarioBlocked as error:
            raise _ScenarioBlocked(f"android audio {stage}: {error}") from error

    run_stage("configure_1x", lambda: _configure_audio_playback(context, speed=1.0))
    run_stage("care_controls_1x", lambda: _navigate_to_care_controls(context))
    one_x_seconds = run_stage("measure_1x", lambda: _measure_audio_duration(context))
    run_stage("configure_2x", lambda: _configure_audio_playback(context, speed=2.0))
    run_stage("care_controls_2x", lambda: _navigate_to_care_controls(context))
    two_x_seconds = run_stage("measure_2x", lambda: _measure_audio_duration(context))
    if not isinstance(one_x_seconds, float) or not isinstance(two_x_seconds, float):
        raise _ScenarioBlocked("android audio duration measurement is invalid")
    # A speed label alone is not proof of playback policy. Require a material
    # duration change from the same device-observed playback surface.
    if two_x_seconds >= one_x_seconds * 0.8:
        raise _ScenarioBlocked("audio speed effect was not observed")
    # The 2.0x sample is intentionally short. Re-enter the same activity at
    # the persisted 1.0x setting before exercising pause/resume/replay so the
    # UI can expose each control before playback naturally completes.
    run_stage("configure_controls_1x", lambda: _configure_audio_playback(context, speed=1.0))
    run_stage("care_controls_for_pause", lambda: _navigate_to_care_controls(context))
    pause_node = run_stage("prepare_pause", lambda: _ensure_audio_playing(context))
    if not isinstance(pause_node, dict):
        raise _ScenarioBlocked("audio pause control geometry is unavailable")
    run_stage(
        "pause",
        lambda: _tap_ui_node(context, pause_node),
    )
    run_stage("pause_state", lambda: _wait_for_audio_state(context, playing=False))
    run_stage(
        "resume",
        lambda: _tap_ui_label(
            context,
            ("继续", "Resume", "播放"),
            wait_seconds=_UI_READY_TIMEOUT_SECONDS,
        ),
    )
    run_stage("resume_state", lambda: _wait_for_audio_state(context, playing=True))
    # Replay is disabled while the turn is playing or paused. Let the resumed
    # clip complete so the current turn exposes an enabled replay control.
    replay_node = run_stage("wait_for_replay", lambda: _wait_for_replay_control(context))
    if not isinstance(replay_node, dict):
        raise _ScenarioBlocked("audio replay control geometry is unavailable")
    run_stage("replay_pause_state", lambda: _wait_for_audio_state(context, playing=False))
    run_stage(
        "replay",
        lambda: _tap_ui_node(context, replay_node),
    )
    run_stage("replay_state", lambda: _wait_for_audio_state(context, playing=True))
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


def _ensure_audio_playing(context: CaseExecutionContext) -> dict[str, str]:
    """Ensure the current care turn exposes a clickable pause control.

    A UI dump is expensive on the candidate emulator and a short clip can
    finish while the runner is polling a stale MediaSession. The pause
    control is owned by the current Flutter turn, so it is the right
    readiness signal; the following pause-state assertion still verifies the
    independent system session.
    """
    play_requested = False
    deadline = time.monotonic() + _UI_READY_TIMEOUT_SECONDS
    while True:
        xml = _dump_ui(context)
        pause_node = _find_clickable_ui_node_from_xml(xml, ("暂停", "Pause"))
        if pause_node is not None:
            return pause_node
        if not play_requested:
            play_node = _find_clickable_ui_node_from_xml(
                xml,
                ("播放音频", "播放", "听一遍", "听一下", "Play audio", "重播", "Replay"),
            )
            if play_node is not None:
                _tap_ui_node(context, play_node)
                play_requested = True
                continue
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("audio playback state was not observable")
        time.sleep(0.2)


def _find_clickable_ui_node_from_xml(
    xml: str,
    labels: tuple[str, ...],
) -> dict[str, str] | None:
    for node in _parse_ui_nodes(xml):
        if (
            node.get("clickable", "true").lower() == "false"
            or node.get("enabled", "true").lower() == "false"
        ):
            continue
        visible = unescape(
            (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        )
        if any(label == visible or label in visible for label in labels):
            return node
    return None


def _find_clickable_ui_node(
    context: CaseExecutionContext,
    labels: tuple[str, ...],
) -> dict[str, str] | None:
    return _find_clickable_ui_node_from_xml(_dump_ui(context), labels)


def _wait_for_replay_control(context: CaseExecutionContext) -> dict[str, str]:
    """Wait for the current turn to expose an enabled replay action."""
    deadline = time.monotonic() + _SCENARIO_TIMEOUT_SECONDS
    while True:
        replay_node = _find_clickable_ui_node(
            context,
            ("重播", "Replay", "再来一次"),
        )
        if replay_node is not None:
            return replay_node
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("audio replay control was not observable")
        time.sleep(0.2)


def _wait_for_audio_state(context: CaseExecutionContext, *, playing: bool) -> str:
    deadline = time.monotonic() + _UI_READY_TIMEOUT_SECONDS
    while True:
        state = _dumpsys(context, "media_session")
        if _audio_state_is_playing(state, context.package_id) is playing:
            return state
        if time.monotonic() >= deadline:
            marker = "playing" if playing else "paused"
            raise _ScenarioBlocked(f"audio {marker} state was not observed")
        time.sleep(0.2)


def _audio_state_is_playing(output: str, package_id: str) -> bool:
    normalized = output.lower()
    session = re.search(
        re.escape(package_id.lower()) + r"[^\n]*\n(?P<body>[\s\S]{0,1000})",
        normalized,
    )
    if session is None:
        return False
    state = re.search(
        r"state\s*=\s*playbackstate\s*\{\s*state\s*=\s*"
        r"(?P<name>[a-z_]+)(?:\((?P<code>\d+)\))?",
        session.group("body"),
    )
    return bool(
        state is not None
        and (
            state.group("name") in {"playing", "state_playing"}
            or state.group("code") == "3"
        )
    )


def _configure_audio_playback(context: CaseExecutionContext, *, speed: float) -> None:
    if speed not in {0.5, 1.0, 2.0}:
        raise _ScenarioBlocked("fixed audio speed is invalid")
    _launch_app(context)
    _tap_ui_label(context, ("我", "我的", "Me"), wait_seconds=_UI_READY_TIMEOUT_SECONDS)
    _tap_ui_label(context, ("设置", "Settings"), wait_seconds=_UI_READY_TIMEOUT_SECONDS)
    _tap_ui_label(
        context,
        ("播放偏好", "Playback preferences"),
        wait_seconds=_UI_READY_TIMEOUT_SECONDS,
    )
    settings_nodes = _parse_ui_nodes(_dump_ui(context))
    switches = [
        node
        for node in settings_nodes
        if node.get("class", "").endswith("Switch")
    ]
    if len(switches) != 1:
        raise _ScenarioBlocked("audio autoplay control is unavailable")
    if switches[0].get("checked", "false").lower() == "true":
        _tap_ui_node(context, switches[0])

    sliders = [
        node
        for node in settings_nodes
        if node.get("class", "").endswith(("SeekBar", "Slider"))
    ]
    if len(sliders) != 1:
        raise _ScenarioBlocked("audio speed slider is unavailable")
    bounds = sliders[0].get("bounds", "")
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
    if match is None:
        raise _ScenarioBlocked("audio speed slider geometry is unavailable")
    left, top, right, bottom = (int(part) for part in match.groups())
    fraction = (speed - 0.5) / 1.5
    current_percent = int(sliders[0].get("content-desc", "0%").rstrip("%"))
    expected_percent = round(fraction * 100)
    if current_percent != expected_percent:
        speed_surface = next(
            (
                node
                for node in settings_nodes
                if "语速" in node.get("content-desc", "")
                and node.get("bounds", "")
            ),
            None,
        )
        if speed_surface is None:
            raise _ScenarioBlocked("audio speed track geometry is unavailable")
        surface_match = re.fullmatch(
            r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
            speed_surface["bounds"],
        )
        if surface_match is None:
            raise _ScenarioBlocked("audio speed track geometry is unavailable")
        surface_left, _, surface_right, _ = (
            int(part) for part in surface_match.groups()
        )
        # Flutter's Slider reserves the thumb radius plus the card's inner
        # padding at either end. The semantic parent gives stable track
        # geometry even though the SeekBar node itself only bounds the thumb.
        track_margin = round((surface_right - surface_left) * 0.108)
        track_left = surface_left + track_margin
        track_right = surface_right - track_margin
        target_x = round(track_left + (track_right - track_left) * fraction)
        x = (left + right) // 2
        y = (top + bottom) // 2
        _run_device_step(
            context,
            [
                "shell",
                "input",
                "swipe",
                str(x),
                str(y),
                str(target_x),
                str(y),
                "500",
            ],
        )

    expected_slider_desc = f"{expected_percent}%"
    deadline = time.monotonic() + _UI_READY_TIMEOUT_SECONDS
    while True:
        selected = [
            node
            for node in _parse_ui_nodes(_dump_ui(context))
            if node.get("class", "").endswith(("SeekBar", "Slider"))
            and node.get("content-desc", "") == expected_slider_desc
        ]
        if selected:
            # `onChangeEnd` persists through Isar asynchronously; let the
            # write finish before the next cold-start reads playback policy.
            time.sleep(1.0)
            return
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("audio speed value was not observable")
        time.sleep(0.5)


def _measure_audio_duration(context: CaseExecutionContext) -> float:
    _tap_ui_label(
        context,
        ("播放音频", "播放", "听一遍", "听一下", "Play audio", "重播", "Replay"),
        wait_seconds=_SCENARIO_TIMEOUT_SECONDS,
    )
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
    recipient: _QaSession | None = None
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
        invite_uri = _server_invite_deep_link(
            _required_string(invite, "inviteUrl"),
            _required_string(invite, "token"),
        )
        recipient = _authenticate_synthetic_fingerprint(
            context,
            _fresh_deep_link_recipient_fingerprint(
                context,
                _required_string(invite, "token"),
            ),
        )
        pre_acceptance = _scenario_json_request(
            context=context,
            method="GET",
            path="/api/v1/household/shared-context",
            access_token=recipient.access_token,
        )
        if pre_acceptance.status_code != 403:
            raise _ScenarioBlocked("deep-link recipient is not a fresh non-member")
        try:
            _sign_in_apk_identity(
                context,
                "idempotent_event_id",
                recipient_fingerprint=_fresh_deep_link_recipient_fingerprint(
                    context,
                    _required_string(invite, "token"),
                ),
            )
        except _ScenarioBlocked as error:
            raise _ScenarioBlocked(f"android deep-link recipient_sign_in: {error}") from error
        _run_device_step(context, ["shell", "am", "force-stop", context.package_id])
        _run_view_intent(context, invite_uri)
        cold_ui = _wait_for_deep_link_surface(context, valid=True)
        cold_activity = _dumpsys(context, "activity", "activities")
        if not _deep_link_intent_is_active(cold_activity, context.package_id):
            raise _ScenarioBlocked("cold-start invite intent delivery was not observable")
        if not _deep_link_valid_destination_is_visible(cold_ui):
            raise _ScenarioBlocked("cold-start invite destination was not visible")
        # Do not restart between duplicate intents: product deduplication is
        # process-scoped and a restart would test a new delivery instead.
        _run_view_intent(context, invite_uri)
        foreground_ui = _wait_for_deep_link_surface(context, valid=True)
        foreground_activity = _dumpsys(context, "activity", "activities")
        if not _deep_link_intent_is_active(foreground_activity, context.package_id):
            raise _ScenarioBlocked("foreground invite intent delivery was not observable")
        if not _deep_link_valid_destination_is_visible(foreground_ui):
            raise _ScenarioBlocked("foreground invite destination was not visible")
        recipient_shared_context = _require_json_object(
            _scenario_json_request(
                context=context,
                method="GET",
                path="/api/v1/household/shared-context",
                access_token=recipient.access_token,
            ),
            statuses=(200,),
        )
        if _required_string(recipient_shared_context, "householdId") != _required_string(invite, "householdId"):
            raise _ScenarioBlocked("deep-link recipient did not join the invited household")
        _run_device_step(context, ["shell", "am", "force-stop", context.package_id])
        _run_view_intent(context, _INVALID_INVITE_URI)
        invalid_ui = _wait_for_deep_link_surface(context, valid=False)
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
                "recipient_pre_acceptance_non_member_observed": True,
                "recipient_household_join_observed": True,
                "invalid_link_message_observed": True,
            },
        )
    finally:
        _logout_fixed_identity(context, recipient)
        _logout_fixed_identity(context, primary)


def _deep_link_intent_is_active(output: str, package_id: str) -> bool:
    normalized = output.lower()
    return bool(
        f"{package_id.lower()}/.mainactivity" in normalized
        and "android.intent.action.view" in normalized
        and "babytalk://invite/open" in normalized
    )


def _wait_for_deep_link_surface(context: CaseExecutionContext, *, valid: bool) -> str:
    deadline = time.monotonic() + _UI_READY_TIMEOUT_SECONDS
    while True:
        xml = _dump_ui(context)
        visible = (
            _deep_link_valid_destination_is_visible(xml)
            if valid
            else _deep_link_invalid_fallback_is_visible(xml)
        )
        if visible:
            return xml
        if time.monotonic() >= deadline:
            raise _ScenarioBlocked("deep-link user-visible destination was not available")
        time.sleep(0.5)


def _deep_link_valid_destination_is_visible(xml: str) -> bool:
    exact_markers = {
        "播放音频",
        "重播",
        "暂停",
        "Play audio",
        "Replay",
        "Pause",
        "现在说一句",
        "Say one sentence",
        "Speak now",
        "Continue this activity",
    }
    visible = {
        (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        for node in _parse_ui_nodes(xml)
    }
    return any(marker in value for marker in exact_markers for value in visible)


def _deep_link_invalid_fallback_is_visible(xml: str) -> bool:
    exact_markers = {
        "邀请链接缺少有效 token，已停留在首页安全入口。",
        "邀请链接不可用，已停留在首页安全入口。",
    }
    visible = {
        (node.get("text", "") + " " + node.get("content-desc", "")).strip()
        for node in _parse_ui_nodes(xml)
    }
    return any(marker in value for marker in exact_markers for value in visible)


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
    if case_id == "idempotent_account_sync":
        return observations in (
            {
                "external_user_behavior_observed": True,
                "server_observable_observed": True,
                "first_write_status": "accepted",
                "retry_status": "duplicate",
                "server_event_count": 1,
            },
            {
                "external_user_behavior_observed": True,
                "server_observable_observed": True,
                "first_write_status": "already_persisted",
                "retry_status": "duplicate",
                "server_event_count": 1,
            },
        )
    required: dict[str, dict[str, object]] = {
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
            "recipient_pre_acceptance_non_member_observed": True,
            "recipient_household_join_observed": True,
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
