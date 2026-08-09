#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "tool/verify_complete_generated_bundle_contract.py"
SPEC = importlib.util.spec_from_file_location("complete_bundle_verifier", MODULE_PATH)
assert SPEC and SPEC.loader
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class CompleteGeneratedBundleVerifierTest(unittest.TestCase):

    def test_application_profile_default_comes_from_nested_yaml_value(self) -> None:
        application = """
# profile: ${BABY_TALK_PRACTICE_AI_PROFILE:classpath:config/practice-ai/profiles/custom-scene-generation-v7.yml}
babytalk:
  practice:
    agentic:
      versioned-resources:
        profile: ${BABY_TALK_PRACTICE_AI_PROFILE:classpath:config/practice-ai/profiles/custom-scene-generation-v6.yml}
"""

        self.assertEqual(
            "${BABY_TALK_PRACTICE_AI_PROFILE:classpath:config/practice-ai/profiles/custom-scene-generation-v6.yml}",
            VERIFIER.application_profile_default(application),
        )


if __name__ == "__main__":
    unittest.main()
