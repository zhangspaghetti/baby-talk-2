#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "tool/verify_practice_generation_privacy.py"
SPEC = importlib.util.spec_from_file_location("practice_privacy_verifier", MODULE_PATH)
assert SPEC and SPEC.loader
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class PracticeGenerationPrivacyVerifierTest(unittest.TestCase):

    def test_current_repository_passes_privacy_contract(self) -> None:
        self.assertEqual([], VERIFIER.collect_violations(REPO_ROOT))

    def test_forbidden_persisted_field_is_reported_from_custom_scene_production_tree(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "backend/app-api/src/main/java/com/example/practice/generated/PracticeAuditEntity.java"
            source.parent.mkdir(parents=True)
            source.write_text("String raw_prompt;\n", encoding="utf-8")
            failures = VERIFIER.collect_violations(root)

        self.assertTrue(any("raw_prompt" in failure for failure in failures))

    def test_forbidden_camel_case_persistence_fields_are_reported(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "backend/app-api/src/main/java/com/example/practice/generated/PracticeAuditEntity.java"
            source.parent.mkdir(parents=True)
            source.write_text("String rawPrompt;\nString rawResponse;\n", encoding="utf-8")
            failures = VERIFIER.collect_violations(root)

        self.assertTrue(any("rawPrompt" in failure for failure in failures))
        self.assertTrue(any("rawResponse" in failure for failure in failures))

    def test_security_and_risk_camel_case_are_limited_to_approved_boundary_classes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "backend/app-api/src/main/java/com/example/practice/generated/PracticeAuditEntity.java"
            source.parent.mkdir(parents=True)
            source.write_text("String securityText;\nString riskSignals;\n", encoding="utf-8")
            failures = VERIFIER.collect_violations(root)

        self.assertTrue(any("securityText use outside approved" in failure for failure in failures))
        self.assertTrue(any("riskSignals use outside approved" in failure for failure in failures))

    def test_security_and_risk_snake_case_are_rejected_in_current_migration_and_mapper_xml(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            migration = root / "backend/db-migration/src/main/resources/db/migration" / VERIFIER.CURRENT_GENERATED_CONTENT_MIGRATION
            mapper = root / "backend/app-api/src/main/resources/mapper/practice/generated/PracticeAuditMapper.xml"
            migration.parent.mkdir(parents=True)
            mapper.parent.mkdir(parents=True)
            migration.write_text("create table audit (security_text text);\n", encoding="utf-8")
            mapper.write_text("<result column=\"risk_signals\"/>\n", encoding="utf-8")
            failures = VERIFIER.collect_violations(root)

        self.assertTrue(any(VERIFIER.CURRENT_GENERATED_CONTENT_MIGRATION in failure and "security_text" in failure
                            for failure in failures))
        self.assertTrue(any("PracticeAuditMapper.xml" in failure and "risk_signals" in failure
                            for failure in failures))

    def test_only_zero_retry_is_accepted(self) -> None:
        self.assertIsNone(VERIFIER.re.search(r"\.maxRetries\((?!0\))", ".maxRetries(0)"))
        self.assertIsNotNone(VERIFIER.re.search(r"\.maxRetries\((?!0\))", ".maxRetries(1)"))

    def test_generated_audio_persistence_marker_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / (VERIFIER.GENERATED_AUDIO_JAVA_ROOT + "/UnsafeAudioStore.java")
            source.parent.mkdir(parents=True)
            source.write_text("import java.nio.file.Files;\n", encoding="utf-8")
            failures = VERIFIER.collect_violations(root)

        self.assertTrue(any("generated audio must not persist" in failure for failure in failures))


if __name__ == "__main__":
    unittest.main()
