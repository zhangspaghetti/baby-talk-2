import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import call, patch
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
                    "requiredMigrationVersion": "36",
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

    def test_manifest_rejects_untrusted_gateway_hosts_and_plaintext_remote(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            apk = Path(temporary) / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            for gateway_url in (
                "http://attacker.invalid:19091",
                "https://attacker.invalid",
                "http://api.babytalk.example.com",
            ):
                candidate = _manifest(apk)
                candidate["candidate"]["gateway_url"] = gateway_url
                self.assertIsNone(harness._validate_candidate(candidate))
            self.assertIsNotNone(harness._validate_candidate(_manifest(apk)))

    def test_installed_candidate_identity_requires_exact_about_row(self) -> None:
        context = harness.CaseExecutionContext(
            candidate_id="btqa-2026-08-15",
            apk_sha256="a" * 64,
            gateway_url="http://127.0.0.1:19091",
            package_id="com.zhangspaghetti.babytalk",
            device_identity_sha256="b" * 64,
            android_version="14",
            app_version="1.0.0",
            identity_fingerprints={},
            device_serial="emulator-5554",
        )
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label", return_value="关于 BabyTalk"
        ) as tap, patch.object(
            harness,
            "_dump_ui",
            return_value=(
                '<hierarchy><node content-desc="关于 BabyTalk"/><node '
                'content-desc="版本&#10;1.0.0+1&#10;候选 ID&#10;btqa-2026-08-15&#10;开发者&#10;BabyTalk Studio"/>'
                '</hierarchy>'
            ),
        ):
            self.assertTrue(harness._verify_installed_candidate_identity(context))
        self.assertEqual(
            tap.call_args_list,
            [
                call(
                    context,
                    ("我的", "我", "Me"),
                    wait_seconds=harness._UI_READY_TIMEOUT_SECONDS,
                ),
                call(
                    context,
                    ("设置", "Settings"),
                    wait_seconds=harness._UI_READY_TIMEOUT_SECONDS,
                ),
                call(
                    context,
                    ("关于 BabyTalk",),
                    wait_seconds=harness._UI_READY_TIMEOUT_SECONDS,
                ),
            ],
        )

        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label"
        ), patch.object(
            harness,
            "_dump_ui",
            return_value=(
                '<hierarchy><node content-desc="关于 BabyTalk"/><node '
                'content-desc="版本&#10;1.0.0+1&#10;候选 ID&#10;other-candidate&#10;开发者&#10;BabyTalk Studio"/>'
                '</hierarchy>'
            ),
        ):
            self.assertFalse(harness._verify_installed_candidate_identity(context))

    def test_installed_candidate_identity_scrolls_to_about_after_initial_miss(self) -> None:
        context = harness.CaseExecutionContext(
            candidate_id="btqa-2026-08-15",
            apk_sha256="a" * 64,
            gateway_url="http://127.0.0.1:19091",
            package_id="com.zhangspaghetti.babytalk",
            device_identity_sha256="b" * 64,
            android_version="14",
            app_version="1.0.0",
            identity_fingerprints={},
            device_serial="emulator-5554",
        )
        with patch.object(harness, "_launch_app"), patch.object(
            harness,
            "_tap_ui_label",
            side_effect=["我", "设置", harness._ScenarioBlocked("about below viewport")],
        ), patch.object(
            harness, "_tap_ui_label_after_scroll", return_value="关于 BabyTalk"
        ) as tap_after_scroll, patch.object(
            harness,
            "_dump_ui",
            return_value=(
                '<hierarchy><node content-desc="关于 BabyTalk"/><node '
                'content-desc="版本&#10;1.0.0&#10;候选 ID&#10;btqa-2026-08-15&#10;开发者&#10;BabyTalk Studio"/>'
                "</hierarchy>"
            ),
        ):
            self.assertTrue(harness._verify_installed_candidate_identity(context))
        tap_after_scroll.assert_called_once_with(
            context,
            ("关于 BabyTalk",),
            scroll_attempts=5,
        )

    def test_care_navigation_waits_for_cold_start_scene_tab(self) -> None:
        context = _ui_context()
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label", return_value="场景"
        ) as tap_label, patch.object(
            harness, "_find_ui_label", return_value="现在说一句"
        ):
            harness._navigate_to_care_controls(context)

        self.assertEqual(
            tap_label.call_args_list,
            [
                call(
                    context,
                    ("场景", "Scenes", "练习", "Practice"),
                    wait_seconds=harness._UI_READY_TIMEOUT_SECONDS,
                ),
                call(
                    context,
                    (
                        "现在说一句",
                        "Say one sentence",
                        "Speak now",
                        "Continue this activity",
                    ),
                    wait_seconds=harness._UI_READY_TIMEOUT_SECONDS,
                ),
            ],
        )

    def test_parse_ui_nodes_preserves_hyphenated_android_attributes(self) -> None:
        nodes = harness._parse_ui_nodes(
            '<hierarchy><node content-desc="设置" resource-id="android:id/content" '
            'long-clickable="false" bounds="[10,20][110,120]"/></hierarchy>'
        )

        self.assertEqual(nodes[0]["content-desc"], "设置")
        self.assertEqual(nodes[0]["resource-id"], "android:id/content")
        self.assertEqual(nodes[0]["long-clickable"], "false")
        self.assertEqual(nodes[0]["center_x"], "60")
        self.assertEqual(nodes[0]["center_y"], "70")

    def test_installed_app_version_is_read_from_package_and_bound_to_context(self) -> None:
        device = {"serial": "emulator-5554", "package_id": "com.babytalk.mobile"}
        commands = [
            harness.CaseCommandResult(0, "device\n", ""),
            harness.CaseCommandResult(0, "Success\n", ""),
            harness.CaseCommandResult(0, "15\n", ""),
            harness.CaseCommandResult(0, "package:/data/app/base.apk\n", ""),
            harness.CaseCommandResult(0, "Package [com.babytalk.mobile]\n  versionName=1.0.0\n", ""),
        ]
        with patch.object(harness, "run_device_command", side_effect=commands) as run_command:
            evidence = harness.collect_android_device_evidence(apk=Path("candidate.apk"), device=device)

        self.assertEqual(evidence.status, "PASS")
        self.assertEqual(evidence.app_version, "1.0.0")
        self.assertEqual(
            run_command.call_args_list[-1].args[0],
            ["adb", "-s", "emulator-5554", "shell", "dumpsys", "package", "com.babytalk.mobile"],
        )
        context = harness._case_execution_context(
            candidate={
                "id": "btqa-2026-08-15",
                "apk_sha256": "a" * 64,
                "gateway_url": "http://127.0.0.1:19091",
            },
            device=device,
            device_evidence=evidence,
            identity_fingerprints={},
        )
        self.assertEqual(context.app_version, "1.0.0")

    def test_installed_app_version_missing_or_invalid_blocks_before_scenarios(self) -> None:
        device = {"serial": "emulator-5554", "package_id": "com.babytalk.mobile"}
        for dumpsys_output in ("Package [com.babytalk.mobile]\n", "versionName=1.0.0+1\n"):
            with self.subTest(dumpsys_output=dumpsys_output):
                commands = [
                    harness.CaseCommandResult(0, "device\n", ""),
                    harness.CaseCommandResult(0, "Success\n", ""),
                    harness.CaseCommandResult(0, "15\n", ""),
                    harness.CaseCommandResult(0, "package:/data/app/base.apk\n", ""),
                    harness.CaseCommandResult(0, dumpsys_output, ""),
                ]
                with patch.object(harness, "run_device_command", side_effect=commands):
                    evidence = harness.collect_android_device_evidence(
                        apk=Path("candidate.apk"), device=device
                    )

                self.assertEqual(evidence.status, "BLOCKED")
                self.assertIsNone(evidence.app_version)

    def test_scenario_request_sends_installed_app_version_header(self) -> None:
        context = _ui_context()
        opener_response = patch.object(harness._NO_REDIRECT_OPENER, "open")
        with opener_response as open_request:
            open_request.return_value.__enter__.return_value.status = 200
            open_request.return_value.__enter__.return_value.read.return_value = b"{}"
            harness._scenario_json_request(context=context, method="GET", path="/qa/ping")

        request = open_request.call_args.args[0]
        self.assertEqual(request.headers.get("X-app-version"), "1.0.0")

    def test_scenario_request_blocks_context_without_installed_app_version(self) -> None:
        context = harness.CaseExecutionContext(
            candidate_id="btqa-2026-08-15",
            apk_sha256="a" * 64,
            gateway_url="http://127.0.0.1:19091",
            package_id="com.babytalk.mobile",
            device_identity_sha256="b" * 64,
            android_version="15",
            identity_fingerprints={},
            device_serial="emulator-5554",
        )
        with patch.object(harness._NO_REDIRECT_OPENER, "open") as open_request:
            with self.assertRaisesRegex(harness._ScenarioBlocked, "app version"):
                harness._scenario_json_request(context=context, method="GET", path="/qa/ping")
        open_request.assert_not_called()

    def test_acceptance_rejects_installed_apk_candidate_id_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apk = root / "candidate.apk"
            apk.write_bytes(b"frozen-apk")
            candidate = _manifest(apk)
            manifest = root / "candidate.json"
            manifest.write_text(json.dumps(candidate), encoding="utf-8")

            with _passing_harness(candidate), patch.object(
                harness, "_verify_installed_candidate_identity", return_value=False
            ), patch.object(harness, "run_case_command") as runner:
                report = harness.run_acceptance(manifest)

        self.assertEqual(report.violations, ["apk_candidate_identity_mismatch"])
        runner.assert_not_called()

    def test_dump_ui_reads_fixed_remote_xml_and_cleans_up(self) -> None:
        context = _ui_context()
        xml = '<hierarchy rotation="0"><node text="Today"/></hierarchy>'
        with patch.object(harness, "_run_device_step", return_value="dumped") as dump, patch.object(
            harness,
            "_run_binary_command",
            return_value=harness._BinaryCommandResult(0, xml.encode(), b""),
        ) as cat, patch.object(
            harness,
            "run_device_command",
            return_value=harness.CaseCommandResult(0, "", ""),
        ) as cleanup:
            self.assertEqual(harness._dump_ui(context), xml)

        remote_path = harness._UI_DUMP_REMOTE_PATH
        dump.assert_called_once_with(context, ["shell", "uiautomator", "dump", remote_path])
        cat.assert_called_once_with(["adb", "-s", context.device_serial, "exec-out", "cat", remote_path])
        cleanup.assert_called_once_with(
            ["adb", "-s", context.device_serial, "shell", "rm", "-f", remote_path]
        )

    def test_dump_ui_rejects_missing_malformed_or_non_hierarchy_xml(self) -> None:
        context = _ui_context()
        for payload in (b"", b"<hierarchy>", b"<root/>"):
            with self.subTest(payload=payload), patch.object(
                harness, "_run_device_step", return_value="dumped"
            ), patch.object(
                harness,
                "_run_binary_command",
                return_value=harness._BinaryCommandResult(0, payload, b""),
            ), patch.object(
                harness,
                "run_device_command",
                return_value=harness.CaseCommandResult(0, "", ""),
            ) as cleanup:
                with self.assertRaisesRegex(
                    harness._ScenarioBlocked, "fixed scenario did not expose user-visible UI"
                ):
                    harness._dump_ui(context)
                cleanup.assert_called_once()

    def test_dump_ui_rejects_dump_or_cat_failure_and_still_cleans_up(self) -> None:
        context = _ui_context()
        with patch.object(
            harness,
            "_run_device_step",
            side_effect=harness._ScenarioBlocked("fixed scenario device command failed"),
        ), patch.object(
            harness,
            "run_device_command",
            return_value=harness.CaseCommandResult(0, "", ""),
        ) as cleanup:
            with self.assertRaises(harness._ScenarioBlocked):
                harness._dump_ui(context)
        cleanup.assert_called_once()

        with patch.object(harness, "_run_device_step", return_value="dumped"), patch.object(
            harness,
            "_run_binary_command",
            return_value=harness._BinaryCommandResult(1, b"", b"cat failed"),
        ), patch.object(
            harness,
            "run_device_command",
            return_value=harness.CaseCommandResult(0, "", ""),
        ) as cleanup:
            with self.assertRaises(harness._ScenarioBlocked):
                harness._dump_ui(context)
        cleanup.assert_called_once()

    def test_dump_ui_cleanup_failure_does_not_hide_valid_xml(self) -> None:
        context = _ui_context()
        xml = "<hierarchy><node text=\"Today\"/></hierarchy>"
        with patch.object(harness, "_run_device_step", return_value="dumped"), patch.object(
            harness,
            "_run_binary_command",
            return_value=harness._BinaryCommandResult(0, xml.encode(), b""),
        ), patch.object(
            harness,
            "run_device_command",
            return_value=harness.CaseCommandResult(1, "", "rm failed"),
        ) as cleanup:
            self.assertEqual(harness._dump_ui(context), xml)
        cleanup.assert_called_once()

    def test_case_server_hash_binds_redacted_business_result(self) -> None:
        candidate = {
            "id": "btqa-2026-08-15",
            "apk_sha256": "a" * 64,
            "gateway_url": "http://127.0.0.1:19091",
        }
        device = {"serial": "emulator-5554", "package_id": "com.zhangspaghetti.babytalk"}
        device_evidence = harness.AndroidDeviceEvidence.passing(
            serial="emulator-5554",
            android_version="14",
            package_id=device["package_id"],
            app_version="1.0.0",
        )
        compatibility = {
            "candidateId": candidate["id"],
            "requiredMigrationVersion": "36",
            "status": "compatible",
        }
        commands = (
            harness.CaseCommandResult(0, "device", ""),
            harness.CaseCommandResult(0, "14", ""),
            harness.CaseCommandResult(0, "package:/data/app/base.apk", ""),
            harness.CaseCommandResult(
                0,
                '<hierarchy><node text="重播" class="android.widget.TextView"/></hierarchy>',
                "",
            ),
        )
        screenshot = harness._BinaryCommandResult(0, b"png", b"")
        with patch.object(harness, "read_gateway_compatibility", return_value=compatibility), patch.object(
            harness, "run_device_command", side_effect=commands
        ), patch.object(harness, "_run_binary_command", return_value=screenshot), patch.object(
            harness,
            "_collect_case_business_result",
            return_value={"eventCount": 1, "accessToken": "must-not-hash"},
        ), patch.object(
            harness,
            "_dump_ui",
            return_value='<hierarchy><node text="重播" class="android.widget.TextView"/></hierarchy>',
        ) as dump_ui:
            first = harness.collect_case_evidence(
                candidate=candidate,
                device=device,
                device_evidence=device_evidence,
                case_id="idempotent_account_sync",
                compatibility=compatibility,
                context=context_for(candidate, device, device_evidence),
            )
        self.assertIsNotNone(first)
        expected = harness._canonical_json_sha256(
            {
                "case_id": "idempotent_account_sync",
                "compatibility": compatibility,
                "business_result": {"eventCount": 1, "accessToken": "[REDACTED]"},
            }
        )
        self.assertEqual(first.server_response_sha256, expected)
        dump_ui.assert_called_once()

    def test_user_visible_receipt_hash_ignores_unstable_screenshot_pixels(self) -> None:
        candidate = {
            "id": "btqa-2026-08-15",
            "apk_sha256": "a" * 64,
            "gateway_url": "http://127.0.0.1:19091",
        }
        device = {"serial": "emulator-5554", "package_id": "com.zhangspaghetti.babytalk"}
        evidence = harness.AndroidDeviceEvidence.passing(
            serial=device["serial"],
            android_version="14",
            package_id=device["package_id"],
            app_version="1.0.0",
        )
        compatibility = {
            "candidateId": candidate["id"],
            "requiredMigrationVersion": "36",
            "status": "compatible",
        }
        one_read = (
            harness.CaseCommandResult(0, "device", ""),
            harness.CaseCommandResult(0, "14", ""),
            harness.CaseCommandResult(0, "package:/data/app/base.apk", ""),
        )
        with patch.object(harness, "read_gateway_compatibility", return_value=compatibility), patch.object(
            harness, "run_device_command", side_effect=one_read + one_read
        ), patch.object(
            harness,
            "_run_binary_command",
            side_effect=(
                harness._BinaryCommandResult(0, b"png-frame-1", b""),
                harness._BinaryCommandResult(0, b"png-frame-2", b""),
            ),
        ), patch.object(harness, "_collect_case_business_result", return_value={"state": "same"}), patch.object(
            harness,
            "_dump_ui",
            return_value='<hierarchy><node text="重播" class="android.widget.TextView"/></hierarchy>',
        ):
            reads = [
                harness.collect_case_evidence(
                    candidate=candidate,
                    device=device,
                    device_evidence=evidence,
                    case_id="android_audio",
                    compatibility=compatibility,
                    context=context_for(candidate, device, evidence),
                )
                for _ in range(2)
            ]

        self.assertIsNotNone(reads[0])
        self.assertIsNotNone(reads[1])
        self.assertEqual(reads[0].user_visible_sha256, reads[1].user_visible_sha256)


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
                app_version="1.0.0",
            ),
        ),
        patch.object(harness, "run_case_command", side_effect=run_case),
        patch.object(harness, "collect_case_evidence", side_effect=collect_case_evidence),
        patch.object(harness, "_verify_installed_candidate_identity", return_value=True),
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


def context_for(
    candidate: dict[str, str],
    device: dict[str, str],
    device_evidence: harness.AndroidDeviceEvidence,
) -> harness.CaseExecutionContext:
    assert device_evidence.device_identity_sha256 is not None
    assert device_evidence.android_version is not None
    assert device_evidence.app_version is not None
    return harness.CaseExecutionContext(
        candidate_id=candidate["id"],
        apk_sha256=candidate["apk_sha256"],
        gateway_url=candidate["gateway_url"],
        package_id=device["package_id"],
        device_identity_sha256=device_evidence.device_identity_sha256,
        android_version=device_evidence.android_version,
        app_version=device_evidence.app_version,
        identity_fingerprints={
            "primary_account_ref": "c" * 64,
            "caregiver_account_ref": "d" * 64,
            "idempotent_event_id": "e" * 64,
        },
        device_serial=device["serial"],
    )


def _ui_context() -> harness.CaseExecutionContext:
    return harness.CaseExecutionContext(
        candidate_id="btqa-2026-08-15",
        apk_sha256="a" * 64,
        gateway_url="http://127.0.0.1:19091",
        package_id="com.babytalk.mobile",
        device_identity_sha256="b" * 64,
        android_version="15",
        app_version="1.0.0",
        identity_fingerprints={},
        device_serial="emulator-5554",
    )


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
            "required_migration_version": "36",
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
                "recipient_pre_acceptance_non_member_observed": True,
                "recipient_household_join_observed": True,
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
