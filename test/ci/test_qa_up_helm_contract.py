import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
QA_UP_HELM = REPO_ROOT / "scripts" / "qa-up-helm.sh"


class QaUpHelmContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.script = QA_UP_HELM.read_text(encoding="utf-8")

    def test_candidate_mapping_covers_every_application_image(self) -> None:
        for mapping in (
            "app-api=appApi",
            "admin-api=adminApi",
            "admin-web=adminWeb",
            "gateway=gateway",
            "db-migration=dbMigration",
        ):
            with self.subTest(mapping=mapping):
                self.assertIn(f'"{mapping}"', self.script)
        self.assertIn(
            'APP_IMAGE_TAG_ARGS+=(--set-string "${value_key}.image.tag=$QA_IMAGE_TAG")',
            self.script,
        )

    def test_candidate_images_are_preseeded_into_kind(self) -> None:
        self.assertIn('helm template "$APP_RELEASE"', self.script)
        self.assertIn('CANDIDATE_IMAGE_REFS+=("$component_image_ref")', self.script)
        self.assertIn('for image_ref in "${CANDIDATE_IMAGE_REFS[@]}"', self.script)
        self.assertIn('docker image inspect "$image_ref"', self.script)
        self.assertIn('docker save "$image_ref"', self.script)
        self.assertIn("ctr -n k8s.io images import", self.script)

    def test_old_kind_images_are_cleaned_only_after_successful_rollout(self) -> None:
        rollout_marker = 'echo "    rollout: ok"'
        cleanup_marker = 'echo "==> [images] removing superseded candidate images from kind..."'

        self.assertIn(cleanup_marker, self.script)
        self.assertLess(self.script.index(rollout_marker), self.script.index(cleanup_marker))
        self.assertIn('[[ "$image_ref" == "$current_image_ref" ]]', self.script)
        self.assertIn('if ! kind_image_refs="$(', self.script)
        self.assertIn(
            'ctr -n k8s.io images rm "$image_ref"',
            self.script,
        )


if __name__ == "__main__":
    unittest.main()
