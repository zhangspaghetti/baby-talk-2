import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

from tool import qa_candidate_acceptance as harness


class QaCandidateAcceptanceTest(unittest.TestCase):
    def test_matching_candidate_and_required_receipts_emit_safe_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            candidate = _manifest(apk)
            manifest.write_text(json.dumps(candidate), encoding="utf-8")

            with _passing_harness(candidate):
                report = harness.run_acceptance(manifest)

            self.assertTrue(report.passes)
            self.assertEqual(report.evidence["candidate_id"], "btqa-2026-08-15")
            self.assertEqual(report.evidence["apk_sha256"], _sha256(apk))
            self.assertNotIn("apk_path", report.evidence)
            self.assertNotIn("serial", report.evidence["android_device"])
            self.assertEqual(report.evidence["android_device"]["android_version"], "14")
            self.assertEqual(len(report.evidence["cases"]), len(harness.REQUIRED_CASE_IDS))
            self.assertEqual(report.evidence["cases"][0]["status"], "PASS")
            self.assertNotIn("primary_account_ref", report.evidence)
            self.assertEqual(
                set(report.evidence["synthetic_identity_fingerprints"]),
                {"primary_account_ref", "caregiver_account_ref", "idempotent_event_id"},
            )

    def test_blocked_android_device_fails_closed_without_executing_cases(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            candidate = _manifest(apk)
            manifest.write_text(json.dumps(candidate), encoding="utf-8")

            with patch.object(
                harness,
                "read_gateway_compatibility",
                return_value=_compatibility(candidate),
            ), patch.object(
                harness,
                "collect_android_device_evidence",
                return_value=harness.AndroidDeviceEvidence.blocked(),
            ), patch.object(harness, "run_case_command") as run_case:
                report = harness.run_acceptance(manifest)

            self.assertFalse(report.passes)
            self.assertEqual(report.violations, ["android_device_blocked"])
            run_case.assert_not_called()

    def test_mismatched_case_receipt_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            candidate = _manifest(apk)
            manifest.write_text(json.dumps(candidate), encoding="utf-8")
            receipts = _receipts(candidate)
            receipts["two_account_household"]["candidate_id"] = "mixed-candidate"

            with _passing_harness(candidate, receipts=receipts):
                report = harness.run_acceptance(manifest)

            self.assertFalse(report.passes)
            self.assertIn("invalid_case_receipt", report.violations)

    def test_case_receipt_must_bind_to_apk_and_independent_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            candidate = _manifest(apk)
            manifest.write_text(json.dumps(candidate), encoding="utf-8")
            receipts = _receipts(candidate)
            receipts["android_audio"]["apk_sha256"] = _sha256_text("other-apk")
            receipts["android_audio"]["evidence"]["user_visible"]["surface_sha256"] = _sha256_text(
                "fake-screenshot"
            )

            with _passing_harness(candidate, receipts=receipts):
                report = harness.run_acceptance(manifest)

            self.assertFalse(report.passes)
            self.assertIn("invalid_case_receipt", report.violations)

    def test_blocked_required_case_fails_closed_after_device_install(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            candidate = _manifest(apk)
            manifest.write_text(json.dumps(candidate), encoding="utf-8")

            with _passing_harness(candidate), patch.object(
                harness,
                "run_case_command",
                return_value=harness.CaseCommandResult(77, "", "device scenario unavailable"),
            ):
                report = harness.run_acceptance(manifest)

            self.assertFalse(report.passes)
            self.assertEqual(report.violations, ["blocked_required_case"] * len(harness.REQUIRED_CASE_IDS))

    def test_gateway_mismatch_fails_before_device_or_case_evidence_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            candidate = _manifest(apk)
            manifest.write_text(json.dumps(candidate), encoding="utf-8")

            with patch.object(
                harness,
                "read_gateway_compatibility",
                return_value={
                    "candidateId": "mixed-candidate",
                    "requiredMigrationVersion": "34",
                    "status": "compatible",
                },
            ), patch.object(harness, "collect_android_device_evidence") as collect_device:
                report = harness.run_acceptance(manifest)

            self.assertFalse(report.passes)
            self.assertEqual(report.violations, ["candidate_identity_mismatch"])
            collect_device.assert_not_called()

    def test_manifest_rejects_arbitrary_case_command(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            candidate = _manifest(apk)
            candidate["cases"][0] = {
                "id": harness.REQUIRED_CASE_IDS[0],
                "command": ["cmd", "/c", "exit", "0"],
            }
            manifest.write_text(json.dumps(candidate), encoding="utf-8")

            report = harness.run_acceptance(manifest)

            self.assertEqual(report.violations, ["invalid_manifest"])

    def test_gateway_redirect_is_rejected(self) -> None:
        error = HTTPError(
            "http://127.0.0.1:19091/qa/candidate-compatibility",
            302,
            "redirect",
            {"Location": "https://attacker.invalid/"},
            None,
        )
        with patch.object(harness._NO_REDIRECT_OPENER, "open", side_effect=error):
            with self.assertRaisesRegex(ValueError, "redirect rejected"):
                harness.read_gateway_compatibility("http://127.0.0.1:19091")


def _passing_harness(candidate: dict[str, object], *, receipts: dict[str, dict[str, object]] | None = None):
    resolved_receipts = receipts or _receipts(candidate)

    def run_case(case_id: str, *, context: harness.CaseExecutionContext) -> harness.CaseCommandResult:
        assert case_id in context.identity_fingerprints or case_id in harness.REQUIRED_CASE_IDS
        return harness.CaseCommandResult(0, json.dumps(resolved_receipts[case_id]), "")

    def collect_case_evidence(*, case_id: str, **_: object) -> harness.CaseEvidence:
        return _case_evidence(candidate, case_id)

    return _PatchGroup(
        patch.object(harness, "read_gateway_compatibility", return_value=_compatibility(candidate)),
        patch.object(
            harness,
            "collect_android_device_evidence",
            return_value=harness.AndroidDeviceEvidence.passing(
                serial="emulator-5554",
                android_version="14",
                package_id="com.zhangspaghetti.babytalk",
            ),
        ),
        patch.object(harness, "run_case_command", side_effect=run_case),
        patch.object(harness, "collect_case_evidence", side_effect=collect_case_evidence),
    )


class _PatchGroup:
    def __init__(self, *patches: object) -> None:
        self._patches = patches

    def __enter__(self) -> None:
        for current in self._patches:
            current.__enter__()

    def __exit__(self, *arguments: object) -> None:
        for current in reversed(self._patches):
            current.__exit__(*arguments)


def _compatibility(manifest: dict[str, object]) -> dict[str, str]:
    candidate = manifest["candidate"]
    assert isinstance(candidate, dict)
    return {
        "candidateId": str(candidate["id"]),
        "requiredMigrationVersion": str(candidate["required_migration_version"]),
        "status": "compatible",
    }


def _manifest(apk: Path) -> dict[str, object]:
    identities = {
        "primary_account_ref": "qa-account-primary-20260815",
        "caregiver_account_ref": "qa-account-caregiver-20260815",
        "idempotent_event_id": "qa-event-care-turn-20260815",
    }
    return {
        "schema_version": harness.SCHEMA_VERSION,
        "candidate": {
            "id": "btqa-2026-08-15",
            "apk_path": str(apk),
            "apk_sha256": _sha256(apk),
            "gateway_url": "http://127.0.0.1:19091",
            "required_migration_version": "34",
        },
        "android_device": {
            "serial": "emulator-5554",
            "package_id": "com.zhangspaghetti.babytalk",
        },
        "synthetic_identities": identities,
        "cases": [
            {"id": case_id, "runner": case_id}
            for case_id in harness.REQUIRED_CASE_IDS
        ],
    }


def _receipts(manifest: dict[str, object]) -> dict[str, dict[str, object]]:
    identities = manifest["synthetic_identities"]
    assert isinstance(identities, dict)
    identity_fingerprints = {
        key: _sha256_text(str(value)) for key, value in identities.items()
    }
    candidate = manifest["candidate"]
    assert isinstance(candidate, dict)
    common = {
        "schema_version": harness.CASE_RECEIPT_SCHEMA_VERSION,
        "candidate_id": candidate["id"],
        "synthetic_identity_fingerprints": identity_fingerprints,
    }
    return {
        "idempotent_account_sync": {
            **common,
            "case_id": "idempotent_account_sync",
            "apk_sha256": str(candidate["apk_sha256"]),
            "android_device_identity_sha256": _sha256_text("emulator-5554"),
            "android_version": "14",
            "package_id": "com.zhangspaghetti.babytalk",
            "evidence": _case_evidence(manifest, "idempotent_account_sync").to_receipt(),
            "observations": {
                "external_user_behavior_observed": True,
                "server_observable_observed": True,
                "first_write_status": "accepted",
                "retry_status": "duplicate",
                "server_event_count": 1,
            },
        },
        "two_account_household": {
            **common,
            "case_id": "two_account_household",
            "apk_sha256": str(candidate["apk_sha256"]),
            "android_device_identity_sha256": _sha256_text("emulator-5554"),
            "android_version": "14",
            "package_id": "com.zhangspaghetti.babytalk",
            "evidence": _case_evidence(manifest, "two_account_household").to_receipt(),
            "observations": {
                "external_user_behavior_observed": True,
                "server_observable_observed": True,
                "invite_created": True,
                "invite_accepted": True,
                "invite_revoked": True,
                "shared_context_isolated": True,
            },
        },
        "android_notification": {
            **common,
            "case_id": "android_notification",
            "apk_sha256": str(candidate["apk_sha256"]),
            "android_device_identity_sha256": _sha256_text("emulator-5554"),
            "android_version": "14",
            "package_id": "com.zhangspaghetti.babytalk",
            "evidence": _case_evidence(manifest, "android_notification").to_receipt(),
            "observations": {
                "system_state_observed": True,
                "user_visible_result_observed": True,
                "notification_delivered": True,
            },
        },
        "android_audio": {
            **common,
            "case_id": "android_audio",
            "apk_sha256": str(candidate["apk_sha256"]),
            "android_device_identity_sha256": _sha256_text("emulator-5554"),
            "android_version": "14",
            "package_id": "com.zhangspaghetti.babytalk",
            "evidence": _case_evidence(manifest, "android_audio").to_receipt(),
            "observations": {
                "system_state_observed": True,
                "user_visible_result_observed": True,
                "audio_output_observed": True,
                "speed_effect_observed": True,
                "controls_observed": True,
            },
        },
        "android_deep_link": {
            **common,
            "case_id": "android_deep_link",
            "apk_sha256": str(candidate["apk_sha256"]),
            "android_device_identity_sha256": _sha256_text("emulator-5554"),
            "android_version": "14",
            "package_id": "com.zhangspaghetti.babytalk",
            "evidence": _case_evidence(manifest, "android_deep_link").to_receipt(),
            "observations": {
                "system_state_observed": True,
                "user_visible_result_observed": True,
                "cold_start_destination_observed": True,
                "foreground_destination_observed": True,
                "invalid_link_message_observed": True,
            },
        },
    }


def _case_evidence(manifest: dict[str, object], case_id: str) -> harness.CaseEvidence:
    candidate = manifest["candidate"] if "candidate" in manifest else manifest
    assert isinstance(candidate, dict)
    compatibility = {
        "candidateId": str(candidate["id"]),
        "requiredMigrationVersion": str(candidate["required_migration_version"]),
        "status": "compatible",
    }
    return harness.CaseEvidence(
        server_response_sha256=harness._canonical_json_sha256(
            {"case_id": case_id, "compatibility": compatibility}
        ),
        adb_state_sha256=_sha256_text(
            "\n".join(
                (
                    "device",
                    "14",
                    "package:/data/app/com.zhangspaghetti.babytalk/base.apk",
                    _sha256_text("emulator-5554"),
                    "com.zhangspaghetti.babytalk",
                    str(candidate["apk_sha256"]),
                )
            )
        ),
        user_visible_sha256=_sha256_text("fixed-visible-surface"),
    )


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


if __name__ == "__main__":
    unittest.main()
