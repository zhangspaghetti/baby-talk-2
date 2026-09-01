import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
VALUES = REPO_ROOT / "deploy" / "helm" / "babytalk-app" / "values.yaml"
QA_VALUES = REPO_ROOT / "deploy" / "helm" / "babytalk-app" / "values-kind-qa.yaml"
PRODUCTION_VALUES = REPO_ROOT / "deploy" / "helm" / "babytalk-app" / "values-production.yaml"
CONFIG_MAP = REPO_ROOT / "deploy" / "helm" / "babytalk-app" / "templates" / "configmap.yaml"
DEPLOYMENT = REPO_ROOT / "deploy" / "helm" / "babytalk-app" / "templates" / "deployment.yaml"
QA_BOOTSTRAP = REPO_ROOT / "scripts" / "qa-up-helm.sh"


class CandidateIdentityContractTest(unittest.TestCase):
    def test_chart_requires_one_candidate_id_for_all_images(self) -> None:
        template = DEPLOYMENT.read_text(encoding="utf-8")
        values = VALUES.read_text(encoding="utf-8")

        self.assertIn('include "babytalk-app.validateCandidateIdentity" .', template)
        self.assertIn("candidate:", values)
        self.assertIn("requiredMigrationVersion:", values)

    def test_chart_exports_candidate_to_every_backend_workload(self) -> None:
        config_map = CONFIG_MAP.read_text(encoding="utf-8")
        deployment = DEPLOYMENT.read_text(encoding="utf-8")

        self.assertIn("BABYTALK_CANDIDATE_ID:", config_map)
        self.assertIn("BABYTALK_CANDIDATE_REQUIRED_MIGRATION_VERSION:", config_map)
        self.assertNotIn("BABY_TALK_CANDIDATE_ID:", config_map)
        self.assertNotIn("BABY_TALK_CANDIDATE_REQUIRED_MIGRATION_VERSION:", config_map)
        gateway = deployment[deployment.index("- name: gateway") :]
        self.assertIn("configMapRef:", gateway)
        db_migration = deployment[deployment.index("- name: db-migration") :]
        self.assertIn("configMapRef:", db_migration)

    def test_qa_bootstrap_fails_closed_without_candidate_id(self) -> None:
        script = QA_BOOTSTRAP.read_text(encoding="utf-8")
        qa_values = QA_VALUES.read_text(encoding="utf-8")

        self.assertIn('QA_CANDIDATE_ID="${QA_CANDIDATE_ID:-}"', script)
        self.assertIn('candidate.id=$QA_CANDIDATE_ID', script)
        self.assertIn('--dart-define=BABY_TALK_CANDIDATE_ID="$QA_CANDIDATE_ID"', script)
        self.assertNotIn('QA_IMAGE_TAG="${QA_IMAGE_TAG:-$QA_CANDIDATE_ID}"', script)
        self.assertIn("candidate:", qa_values)

    def test_candidate_migration_contract_tracks_current_v38(self) -> None:
        values = VALUES.read_text(encoding="utf-8")
        qa_values = QA_VALUES.read_text(encoding="utf-8")
        production_values = PRODUCTION_VALUES.read_text(encoding="utf-8")
        script = QA_BOOTSTRAP.read_text(encoding="utf-8")

        self.assertIn('requiredMigrationVersion: "38"', values)
        self.assertIn('requiredMigrationVersion: "38"', qa_values)
        self.assertIn('requiredMigrationVersion: "38"', production_values)
        self.assertIn('QA_REQUIRED_MIGRATION_VERSION="${QA_REQUIRED_MIGRATION_VERSION:-38}"', script)


if __name__ == "__main__":
    unittest.main()
