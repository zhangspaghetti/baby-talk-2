import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tool import qa_candidate_acceptance as harness


class QaCandidateAcceptanceTest(unittest.TestCase):
    def test_matching_candidate_and_passing_required_case_emits_safe_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            manifest.write_text(
                json.dumps(_manifest(apk, status="PASS")),
                encoding="utf-8",
            )

            with patch.object(
                harness,
                "read_gateway_compatibility",
                return_value={
                    "candidateId": "btqa-2026-08-15",
                    "requiredMigrationVersion": "33",
                    "status": "compatible",
                },
            ):
                report = harness.run_acceptance(manifest)

            self.assertTrue(report.passes)
            self.assertEqual(report.evidence["candidate_id"], "btqa-2026-08-15")
            self.assertEqual(report.evidence["apk_sha256"], _sha256(apk))
            self.assertNotIn("apk_path", report.evidence)

    def test_blocked_required_case_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            manifest.write_text(
                json.dumps(_manifest(apk, status="BLOCKED")),
                encoding="utf-8",
            )

            with patch.object(
                harness,
                "read_gateway_compatibility",
                return_value={
                    "candidateId": "btqa-2026-08-15",
                    "requiredMigrationVersion": "33",
                    "status": "compatible",
                },
            ):
                report = harness.run_acceptance(manifest)

            self.assertFalse(report.passes)
            self.assertIn("blocked_required_case", report.violations)

    def test_gateway_mismatch_fails_before_case_evidence_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            manifest = root / "candidate.json"
            manifest.write_text(
                json.dumps(_manifest(apk, status="PASS")),
                encoding="utf-8",
            )

            with patch.object(
                harness,
                "read_gateway_compatibility",
                return_value={
                    "candidateId": "mixed-candidate",
                    "requiredMigrationVersion": "33",
                    "status": "compatible",
                },
            ):
                report = harness.run_acceptance(manifest)

            self.assertFalse(report.passes)
            self.assertEqual(report.violations, ["candidate_identity_mismatch"])


def _manifest(apk: Path, *, status: str) -> dict[str, object]:
    return {
        "schema_version": harness.SCHEMA_VERSION,
        "candidate": {
            "id": "btqa-2026-08-15",
            "apk_path": str(apk),
            "apk_sha256": _sha256(apk),
            "gateway_url": "http://127.0.0.1:19091",
            "required_migration_version": "33",
        },
        "cases": [{"id": "guest_onboarding", "status": status}],
    }


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == "__main__":
    unittest.main()
