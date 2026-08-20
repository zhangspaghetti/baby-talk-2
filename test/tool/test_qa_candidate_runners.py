import json
import unittest
from unittest.mock import patch

from tool import qa_candidate_acceptance as harness


class QaCandidateRunnerTest(unittest.TestCase):
    def test_all_required_cases_have_distinct_fixed_runners(self) -> None:
        self.assertEqual(set(harness._CASE_RUNNERS), set(harness.REQUIRED_CASE_IDS))
        self.assertEqual(
            len({id(runner) for runner in harness._CASE_RUNNERS.values()}),
            len(harness.REQUIRED_CASE_IDS),
        )
        for runner in harness._CASE_RUNNERS.values():
            self.assertNotIn("unavailable", repr(runner).lower())

    def test_idempotent_sync_runner_emits_bound_receipt(self) -> None:
        event_key = harness._stable_event_key(_context(), _session("primary").installation_id)
        responses = iter(
            (
                harness._ScenarioHttpResponse(
                    200,
                    {
                        "acceptedCount": 1,
                        "duplicateCount": 0,
                        "acceptedEventKeys": [event_key],
                        "duplicateEventKeys": [],
                    },
                ),
                harness._ScenarioHttpResponse(
                    200,
                    {
                        "acceptedCount": 0,
                        "duplicateCount": 1,
                        "acceptedEventKeys": [],
                        "duplicateEventKeys": [event_key],
                    },
                ),
                harness._ScenarioHttpResponse(
                    200,
                    {"eventCount": 1, "events": [{"eventKey": event_key}]},
                ),
            )
        )
        session = _session("primary")
        with patch.object(harness, "_authenticate_fixed_identity", return_value=session), patch.object(
            harness, "_scenario_json_request", side_effect=lambda **_: next(responses)
        ) as request, patch.object(harness, "_launch_app"), patch.object(
            harness, "_dump_ui", return_value="<hierarchy/>"
        ), patch.object(harness, "_logout_fixed_identity"), patch.object(
            harness, "_runner_case_evidence", return_value=_evidence()
        ):
            result = harness.run_case_command(
                "idempotent_account_sync", context=_context()
            )

        self.assertEqual(result.exit_code, 0)
        receipt = json.loads(result.stdout)
        self.assertEqual(receipt["schema_version"], harness.CASE_RECEIPT_SCHEMA_VERSION)
        self.assertEqual(receipt["candidate_id"], "btqa-runner")
        self.assertEqual(receipt["apk_sha256"], "a" * 64)
        self.assertEqual(receipt["case_id"], "idempotent_account_sync")
        self.assertEqual(receipt["android_device_identity_sha256"], "b" * 64)
        self.assertEqual(receipt["synthetic_identity_fingerprints"], _context().identity_fingerprints)
        self.assertEqual(receipt["evidence"], _evidence().to_receipt())
        self.assertEqual(receipt["observations"]["retry_status"], "duplicate")
        self.assertEqual(request.call_count, 3)

    def test_household_runner_proves_accept_revoke_and_context_boundary(self) -> None:
        primary = _session("primary")
        caregiver = _session("caregiver")
        responses = iter(
            (
                harness._ScenarioHttpResponse(404, {"code": "onboarding_profile_not_found"}),
                harness._ScenarioHttpResponse(200, {"babyProfileId": "profile-qa"}),
                harness._ScenarioHttpResponse(
                    201, {"householdId": "household-qa", "token": "invite-accept"}
                ),
                harness._ScenarioHttpResponse(
                    200,
                    {
                        "householdId": "household-qa",
                        "role": "caregiver",
                        "sharedContext": {"householdId": "household-qa"},
                    },
                ),
                harness._ScenarioHttpResponse(
                    201, {"householdId": "household-qa", "token": "invite-revoke"}
                ),
                harness._ScenarioHttpResponse(200, {"applied": True, "result": "revoked"}),
                harness._ScenarioHttpResponse(409, {"code": "invite_revoked"}),
                harness._ScenarioHttpResponse(200, {"householdId": "household-qa"}),
            )
        )
        with patch.object(
            harness,
            "_authenticate_fixed_identity",
            side_effect=(primary, caregiver),
        ), patch.object(
            harness, "_scenario_json_request", side_effect=lambda **_: next(responses)
        ), patch.object(harness, "_launch_app"), patch.object(
            harness, "_dump_ui", return_value="<hierarchy/>"
        ), patch.object(harness, "_logout_fixed_identity"), patch.object(
            harness, "_runner_case_evidence", return_value=_evidence()
        ):
            result = harness.run_case_command(
                "two_account_household", context=_context()
            )

        self.assertEqual(result.exit_code, 0)
        observations = json.loads(result.stdout)["observations"]
        self.assertTrue(observations["invite_accepted"])
        self.assertTrue(observations["invite_revoked"])
        self.assertTrue(observations["shared_context_isolated"])

    def test_notification_runner_requires_scheduler_and_delivery_evidence(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label"
        ), patch.object(harness, "_tap_ui_class"), patch.object(
            harness,
            "_dumpsys",
            side_effect=(
                "RTC_WAKEUP com.babytalk.mobile/.DailyReminderReceiver\n"
                "PendingIntentRecord{abc com.babytalk.mobile broadcastIntent}",
                "Recent wakeup history: com.babytalk.mobile/.DailyReminderReceiver\n"
                "deliveryCount=1",
                "NotificationRecord(pkg=com.babytalk.mobile id=7020 "
                "channel=daily_reminder postTime=9999999999999)",
                "no scheduled DailyReminderReceiver",
            ),
        ), patch.object(harness, "_run_device_step") as device_step, patch.object(
            harness, "_dump_ui", return_value="<hierarchy>每日提醒</hierarchy>"
        ), patch.object(harness, "_runner_case_evidence", return_value=_evidence()):
            result = harness.run_case_command(
                "android_notification", context=_context()
            )

        self.assertEqual(result.exit_code, 0)
        self.assertTrue(json.loads(result.stdout)["observations"]["notification_delivered"])
        self.assertFalse(
            any("broadcast" in call.args[1] for call in device_step.call_args_list)
        )

    def test_notification_runner_blocks_generic_receiver_and_channel_text(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label"
        ), patch.object(harness, "_tap_ui_class"), patch.object(
            harness,
            "_dumpsys",
            side_effect=(
                "package:com.babytalk.mobile DailyReminderReceiver",
                "package:com.babytalk.mobile daily_reminder",
            ),
        ):
            result = harness.run_case_command("android_notification", context=_context())

        self.assertEqual(result.exit_code, 77)

    def test_audio_runner_requires_output_speed_and_controls(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label", side_effect=("场景", "暂停", "继续", "重播")
        ), patch.object(
            harness,
            "_measure_audio_duration",
            side_effect=(2.0, 1.0),
        ), patch.object(
            harness,
            "_dumpsys",
            side_effect=(
                "state=2 package:com.babytalk.mobile",
                "state=3 package:com.babytalk.mobile",
                "state=3 package:com.babytalk.mobile",
            ),
        ), patch.object(
            harness, "_dump_ui", return_value="<hierarchy>重播</hierarchy>"
        ), patch.object(harness, "_runner_case_evidence", return_value=_evidence()):
            result = harness.run_case_command("android_audio", context=_context())

        self.assertEqual(result.exit_code, 0)
        observations = json.loads(result.stdout)["observations"]
        self.assertTrue(observations["audio_output_observed"])
        self.assertTrue(observations["speed_effect_observed"])
        self.assertTrue(observations["controls_observed"])

    def test_deep_link_runner_requires_cold_foreground_and_invalid_results(self) -> None:
        primary = _session("primary")
        responses = iter(
            (
                harness._ScenarioHttpResponse(200, {"babyProfileId": "profile-qa"}),
                harness._ScenarioHttpResponse(
                    201,
                    {
                        "householdId": "household-qa",
                        "token": "invite-qa",
                        "inviteUrl": "https://babytalk.example.com/invite/qa",
                    },
                ),
            )
        )
        with patch.object(harness, "_authenticate_fixed_identity", return_value=primary), patch.object(
            harness, "_scenario_json_request", side_effect=lambda **_: next(responses)
        ), patch.object(harness, "_run_device_step"), patch.object(
            harness, "_launch_app"
        ), patch.object(
            harness,
            "_dump_ui",
            side_effect=(
                "<hierarchy><node text=\"邀请已接受，正在进入共享练习。\"/></hierarchy>",
                "<hierarchy><node text=\"重复照护邀请链接已忽略。\"/></hierarchy>",
                "<hierarchy><node text=\"邀请链接缺少有效 token，已停留在首页安全入口。\"/></hierarchy>",
            ),
        ), patch.object(
            harness,
            "_dumpsys",
            side_effect=(
                "mIntent=Intent { act=android.intent.action.VIEW dat=babytalk://invite/open cmp=com.babytalk.mobile/.MainActivity }",
                "mIntent=Intent { act=android.intent.action.VIEW dat=babytalk://invite/open cmp=com.babytalk.mobile/.MainActivity }",
                "mIntent=Intent { act=android.intent.action.VIEW dat=babytalk://invite/open cmp=com.babytalk.mobile/.MainActivity }",
            ),
        ), patch.object(harness, "_logout_fixed_identity"), patch.object(
            harness, "_runner_case_evidence", return_value=_evidence()
        ):
            result = harness.run_case_command("android_deep_link", context=_context())

        self.assertEqual(result.exit_code, 0)
        self.assertTrue(json.loads(result.stdout)["observations"]["cold_start_destination_observed"])
        self.assertTrue(json.loads(result.stdout)["observations"]["invalid_link_message_observed"])

    def test_deep_link_runner_blocks_generic_invite_words(self) -> None:
        primary = _session("primary")
        responses = iter(
            (
                harness._ScenarioHttpResponse(200, {"babyProfileId": "profile-qa"}),
                harness._ScenarioHttpResponse(
                    201,
                    {
                        "householdId": "household-qa",
                        "token": "invite-qa",
                        "inviteUrl": "https://babytalk.example.com/invite/qa",
                    },
                ),
            )
        )
        with patch.object(harness, "_authenticate_fixed_identity", return_value=primary), patch.object(
            harness, "_scenario_json_request", side_effect=lambda **_: next(responses)
        ), patch.object(harness, "_run_device_step"), patch.object(
            harness, "_launch_app"
        ), patch.object(
            harness, "_dump_ui", return_value="<hierarchy>邀请 家庭 登录</hierarchy>"
        ), patch.object(harness, "_dumpsys", return_value="MainActivity invite/open"), patch.object(
            harness, "_logout_fixed_identity"
        ):
            result = harness.run_case_command("android_deep_link", context=_context())

        self.assertEqual(result.exit_code, 77)

    def test_environment_or_public_api_block_is_77_for_every_runner(self) -> None:
        context = _context(device_serial="")
        with patch.object(
            harness,
            "_scenario_json_request",
            side_effect=harness._ScenarioBlocked("gateway unavailable"),
        ), patch.object(
            harness, "_launch_app", side_effect=harness._ScenarioBlocked("device unavailable")
        ):
            results = [
                harness.run_case_command(case_id, context=context)
                for case_id in harness.REQUIRED_CASE_IDS
            ]
        self.assertEqual([result.exit_code for result in results], [77] * 5)

    def test_unknown_case_stays_blocked(self) -> None:
        result = harness.run_case_command("manifest-injected", context=_context())
        self.assertEqual(result.exit_code, 77)
        self.assertIn("not allow-listed", result.stderr)


def _context(*, device_serial: str = "emulator-5554") -> harness.CaseExecutionContext:
    return harness.CaseExecutionContext(
        candidate_id="btqa-runner",
        apk_sha256="a" * 64,
        gateway_url="http://127.0.0.1:19091",
        package_id="com.babytalk.mobile",
        device_identity_sha256="b" * 64,
        android_version="14",
        identity_fingerprints={
            "primary_account_ref": "c" * 64,
            "caregiver_account_ref": "d" * 64,
            "idempotent_event_id": "e" * 64,
        },
        device_serial=device_serial,
    )


def _session(label: str) -> harness._QaSession:
    return harness._QaSession(
        account_id=f"account-{label}",
        session_id=f"session-{label}",
        access_token=f"access-{label}",
        refresh_token=f"refresh-{label}",
        installation_id=f"qa-install-{label}",
    )


def _evidence() -> harness.CaseEvidence:
    return harness.CaseEvidence("a" * 64, "b" * 64, "c" * 64)


if __name__ == "__main__":
    unittest.main()
