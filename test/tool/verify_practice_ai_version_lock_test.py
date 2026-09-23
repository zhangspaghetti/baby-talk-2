#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "tool/verify_practice_ai_version_lock.py"
BASE_LOCK_FIXTURE = REPO_ROOT / "test/tool/fixtures/practice_ai_version_lock_base.yml"
WORKFLOW_PATH = REPO_ROOT / ".github/workflows/practice-ai-version-lock.yml"
SPEC = importlib.util.spec_from_file_location("practice_ai_version_lock_verifier", MODULE_PATH)
assert SPEC and SPEC.loader
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class PracticeAiVersionLockVerifierTest(unittest.TestCase):

    def test_scans_health_policy_and_typed_classifier_prompt_reference(self) -> None:
        resources = {
            entry["version"]: entry
            for entry in VERIFIER.scanned_resources()
        }

        self.assertEqual(
            "config/practice-health-safety-v1.yml",
            resources["health-safety-v1"]["resource-path"],
        )
        self.assertEqual(
            "7efe85daa60cfdb29bc4400a4666519c342f585a3486e2bfd23d1cbad1fbac27",
            resources["health-safety-v1"]["content-hash"],
        )
        self.assertEqual(
            "config/practice-ai/prompts/custom-scene-safety-classifier-v1.txt",
            resources["custom-scene-safety-classifier-v1"]["resource-path"],
        )

    def test_write_then_verify_accepts_fixed_base_lock_and_additive_versions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            generated_lock = Path(directory) / "version-lock.yml"
            base_lock = Path(directory) / "base-version-lock.yml"
            base_lock.write_bytes(BASE_LOCK_FIXTURE.read_bytes())

            with patch.object(VERIFIER, "LOCK_PATH", generated_lock):
                with patch.object(sys, "argv", [str(MODULE_PATH), "--write"]):
                    self.assertEqual(0, VERIFIER.main())
                with patch.object(
                    sys,
                    "argv",
                    [str(MODULE_PATH), "--verify", "--base-lock", str(base_lock)],
                ):
                    self.assertEqual(0, VERIFIER.main())

            base_entries = VERIFIER.load_lock(base_lock)
            generated_entries = VERIFIER.load_lock(generated_lock)
            generated_by_version = {
                entry["version"]: entry for entry in generated_entries
            }
            base_versions = {entry["version"] for entry in base_entries}
            added_versions = set(generated_by_version) - base_versions
            self.assertTrue(added_versions)
            generated_lock_keys = [
                (entry["version"], entry["resource-path"])
                for entry in generated_entries
            ]
            self.assertEqual(sorted(generated_lock_keys), generated_lock_keys)
            for entry in base_entries:
                self.assertEqual(
                    entry["content-hash"],
                    generated_by_version[entry["version"]]["content-hash"],
                )

    def test_base_lock_rejects_existing_resource_path_change(self) -> None:
        base_entry = VERIFIER.load_lock(BASE_LOCK_FIXTURE)[0].copy()
        base_entry["resource-path"] = base_entry["resource-path"].replace(
            ".yml", "-renamed.yml"
        )

        with tempfile.TemporaryDirectory() as directory:
            base_lock = Path(directory) / "base-version-lock.yml"
            base_lock.write_text(
                yaml.safe_dump(
                    {
                        "schema-version": "practice-ai-version-lock-schema-v1",
                        "resources": [base_entry],
                    },
                    sort_keys=False,
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "existing version path changed"):
                VERIFIER.compare_base_lock(base_lock, VERIFIER.scanned_resources())

    def test_base_lock_rejects_existing_hash_change(self) -> None:
        base_entry = VERIFIER.scanned_resources()[0].copy()
        base_entry["content-hash"] = "0" * 64

        with tempfile.TemporaryDirectory() as directory:
            base_lock = Path(directory) / "base-version-lock.yml"
            base_lock.write_text(
                yaml.safe_dump(
                    {
                        "schema-version": "practice-ai-version-lock-schema-v1",
                        "resources": [base_entry],
                    },
                    sort_keys=False,
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "existing version hash changed"):
                VERIFIER.compare_base_lock(base_lock, VERIFIER.scanned_resources())

    def test_health_policy_version_mismatch_fails(self) -> None:
        policy_path = REPO_ROOT / "backend/app-api/src/main/resources/config/practice-health-safety-v1.yml"
        policy = yaml.safe_load(policy_path.read_text(encoding="utf-8"))
        policy["babytalk"]["practice"]["health-safety"]["policy-version"] = "health-safety-v2"

        with tempfile.TemporaryDirectory() as directory:
            modified_policy = Path(directory) / "practice-health-safety-v1.yml"
            modified_policy.write_text(
                yaml.safe_dump(policy, allow_unicode=True, sort_keys=False),
                encoding="utf-8",
            )
            with patch.object(VERIFIER, "HEALTH_SAFETY_POLICY_FILE", modified_policy):
                with self.assertRaisesRegex(ValueError, "health safety policy version mismatch"):
                    VERIFIER.scanned_resources()

    def test_health_policy_classifier_path_mismatch_fails(self) -> None:
        policy_path = REPO_ROOT / "backend/app-api/src/main/resources/config/practice-health-safety-v1.yml"
        policy = yaml.safe_load(policy_path.read_text(encoding="utf-8"))
        policy["babytalk"]["practice"]["health-safety"]["classifier-prompt"] = {
            "version": "custom-scene-generator-v1",
            "resource-path": "config/practice-ai/prompts/custom-scene-generator-v1.txt",
        }

        with tempfile.TemporaryDirectory() as directory:
            modified_policy = Path(directory) / "practice-health-safety-v1.yml"
            modified_policy.write_text(
                yaml.safe_dump(policy, allow_unicode=True, sort_keys=False),
                encoding="utf-8",
            )
            with patch.object(VERIFIER, "HEALTH_SAFETY_POLICY_FILE", modified_policy):
                with self.assertRaisesRegex(ValueError, "version mismatch for classifier-prompt"):
                    VERIFIER.scanned_resources()

    def test_version_lock_workflow_triggers_on_health_policy_changes(self) -> None:
        workflow = WORKFLOW_PATH.read_text(encoding="utf-8")
        health_policy_path = "backend/app-api/src/main/resources/config/practice-health-safety-v1.yml"

        self.assertEqual(2, workflow.count(f"      - {health_policy_path}"))


if __name__ == "__main__":
    unittest.main()
