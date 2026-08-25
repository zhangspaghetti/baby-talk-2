import json
import unittest
from unittest.mock import call, patch

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
        local_event_id = event_key.rsplit(":", 1)[-1]
        projected_installation_id = "v1:" + "p" * 43
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
                    {
                        "installationId": projected_installation_id,
                        "eventCount": 1,
                        "events": [
                            {
                                "eventKey": f"{projected_installation_id}:{local_event_id}",
                                "localEventId": local_event_id,
                                "installationId": projected_installation_id,
                            }
                        ],
                    },
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

    def test_idempotent_sync_runner_rejects_wrong_bootstrap_local_event_id(self) -> None:
        event_key = harness._stable_event_key(_context(), _session("primary").installation_id)
        projected_installation_id = "v1:" + "p" * 43
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
                    {
                        "installationId": projected_installation_id,
                        "eventCount": 1,
                        "events": [
                            {
                                "eventKey": f"{projected_installation_id}:wrong-local-event",
                                "localEventId": "wrong-local-event",
                                "installationId": projected_installation_id,
                            }
                        ],
                    },
                ),
            )
        )
        session = _session("primary")
        with patch.object(harness, "_authenticate_fixed_identity", return_value=session), patch.object(
            harness, "_scenario_json_request", side_effect=lambda **_: next(responses)
        ), patch.object(harness, "_launch_app") as launch, patch.object(
            harness, "_logout_fixed_identity"
        ):
            result = harness.run_case_command(
                "idempotent_account_sync", context=_context()
            )

        self.assertEqual(result.exit_code, 77)
        launch.assert_not_called()

    def test_idempotent_projection_accepts_protected_reference_without_raw_key_match(self) -> None:
        attempted_event_key = harness._stable_event_key(
            _context(), _session("primary").installation_id
        )
        local_event_id = attempted_event_key.rsplit(":", 1)[-1]
        projected_installation_id = "v1:" + "p" * 43

        event = harness._require_idempotent_bootstrap_event(
            {
                "installationId": projected_installation_id,
                "eventCount": 1,
                "events": [
                    {
                        "eventKey": f"{projected_installation_id}:{local_event_id}",
                        "localEventId": local_event_id,
                        "installationId": projected_installation_id,
                    }
                ],
            },
            local_event_id,
        )

        self.assertEqual(event["installationId"], projected_installation_id)
        self.assertNotEqual(attempted_event_key, event["eventKey"])

    def test_idempotent_receipt_accepts_existing_frozen_event_replay(self) -> None:
        self.assertTrue(
            harness._valid_observations(
                "idempotent_account_sync",
                {
                    "external_user_behavior_observed": True,
                    "server_observable_observed": True,
                    "first_write_status": "already_persisted",
                    "retry_status": "duplicate",
                    "server_event_count": 1,
                },
            )
        )

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
        with patch.object(harness, "_navigate_to_reminder_controls"), patch.object(
            harness, "_schedule_near_term_daily_reminder"
        ), patch.object(
            harness, "_allow_notification_permission_if_prompted"
        ), patch.object(
            harness, "_wait_for_notification_delivery"
        ), patch.object(harness, "_tap_ui_class"), patch.object(
            harness,
            "_dumpsys",
            return_value="no scheduled DailyReminderReceiver",
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

    def test_notification_wait_requires_due_alarm_and_new_exact_record(self) -> None:
        scheduled = (
            "RTC_WAKEUP #2: Alarm{abc com.babytalk.mobile}\n"
            "tag=*walarm*:com.babytalk.mobile/.DailyReminderReceiver\n"
            "type=RTC_WAKEUP whenElapsed=+2s repeatInterval=86400000\n"
            "operation=PendingIntentRecord{abc com.babytalk.mobile broadcastIntent}"
        )
        delivered = scheduled.replace("whenElapsed=+2s", "whenElapsed=-2s")
        notification = (
            "NotificationRecord(pkg=com.babytalk.mobile id=7020 "
            "channel=daily_reminder postTime=9999999999999)"
        )
        with patch.object(
            harness,
            "_dumpsys",
            side_effect=(scheduled, "", delivered, notification),
        ):
            harness._wait_for_notification_delivery(
                _context(),
                not_before_epoch_ms=0,
            )

    def test_flutter_card_sized_switch_taps_trailing_thumb(self) -> None:
        with patch.object(harness, "_run_device_step") as step:
            harness._tap_ui_node(
                _context(),
                {
                    "class": "android.widget.Switch",
                    "bounds": "[48,372][1232,615]",
                    "center_x": "640",
                    "center_y": "493",
                },
            )

        self.assertEqual(
            step.call_args.args[1],
            ["shell", "input", "tap", "1114", "493"],
        )

    def test_view_intent_quotes_query_delimiters_for_android_shell(self) -> None:
        uri = (
            "babytalk://invite/open?token=abcdefghijkl1234"
            "&source=invite_link&role=caregiver"
        )
        with patch.object(harness, "_run_device_step", return_value="ok") as step:
            harness._run_view_intent(_context(), uri)

        self.assertEqual(
            step.call_args.args[1],
            [
                "shell",
                "am start -W -a android.intent.action.VIEW -d "
                "'babytalk://invite/open?token=abcdefghijkl1234&source=invite_link&role=caregiver'",
            ],
        )

    def test_audio_runner_requires_output_speed_and_controls(self) -> None:
        with patch.object(harness, "_configure_audio_playback") as configure, patch.object(
            harness, "_navigate_to_care_controls"
        ), patch.object(
            harness,
            "_tap_ui_label",
            side_effect=(
                "暂停",
                "继续",
                "重播",
            ),
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
            harness,
            "_dump_ui",
            return_value='<hierarchy><node content-desc="暂停"/></hierarchy>',
        ), patch.object(harness, "_runner_case_evidence", return_value=_evidence()):
            result = harness.run_case_command("android_audio", context=_context())

        self.assertEqual(result.exit_code, 0)
        self.assertEqual(
            [call.kwargs["speed"] for call in configure.call_args_list],
            [1.0, 2.0],
        )
        observations = json.loads(result.stdout)["observations"]
        self.assertTrue(observations["audio_output_observed"])
        self.assertTrue(observations["speed_effect_observed"])
        self.assertTrue(observations["controls_observed"])

    def test_audio_setup_opens_settings_before_playback_preferences(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label", return_value="设置"
        ) as tap, patch.object(
            harness,
            "_dump_ui",
            return_value=(
                '<hierarchy><node class="android.widget.Switch" '
                'checked="false" bounds="[10,20][110,60]" '
                'center_x="60" center_y="40"/>'
                '<node class="android.widget.SeekBar" bounds="[10,80][110,120]"/>'
                '</hierarchy>'
            ),
        ), patch.object(harness, "_run_device_step"), patch.object(
            harness, "_find_ui_label", return_value="1.0x"
        ):
            harness._configure_audio_playback(_context(), speed=1.0)

        self.assertEqual(
            [call.args[1] for call in tap.call_args_list],
            [
                ("我", "我的", "Me"),
                ("设置", "Settings"),
                ("播放偏好", "Playback preferences"),
            ],
        )

    def test_audio_runner_reports_safe_failed_stage(self) -> None:
        with patch.object(
            harness,
            "_configure_audio_playback",
            side_effect=harness._ScenarioBlocked("fixed scenario user control is unavailable"),
        ):
            result = harness.run_case_command("android_audio", context=_context())

        self.assertEqual(result.exit_code, 77)
        self.assertEqual(
            result.stderr,
            "android audio configure_1x: fixed scenario user control is unavailable",
        )

    def test_audio_measurement_can_start_from_visible_replay_control(self) -> None:
        with patch.object(harness, "_tap_ui_label") as tap, patch.object(
            harness,
            "_dumpsys",
            side_effect=(
                "state=3 package:com.babytalk.mobile",
                "state=2 package:com.babytalk.mobile",
            ),
        ), patch.object(harness.time, "monotonic", side_effect=(100.0, 100.5)):
            duration = harness._measure_audio_duration(_context())

        self.assertEqual(duration, 0.5)
        self.assertEqual(
            tap.call_args.args[1],
            ("播放音频", "播放", "听一遍", "Play audio", "重播", "Replay"),
        )

    def test_deep_link_runner_requires_cold_foreground_and_invalid_results(self) -> None:
        primary = _session("primary")
        responses = iter(
            (
                harness._ScenarioHttpResponse(200, {"babyProfileId": "profile-qa"}),
                harness._ScenarioHttpResponse(
                    201,
                    {
                        "householdId": "household-qa",
                        "token": "qa-invite-123",
                        "inviteUrl": "https://babytalk.example.com/invite/qa-invite-123",
                    },
                ),
            )
        )
        with patch.object(harness, "_authenticate_fixed_identity", return_value=primary), patch.object(
            harness, "_scenario_json_request", side_effect=lambda **_: next(responses)
        ), patch.object(
            harness, "_sign_in_apk_identity"
        ), patch.object(harness, "_run_device_step"), patch.object(
            harness,
            "_dump_ui",
            side_effect=(
                "<hierarchy><node content-desc=\"播放音频\"/></hierarchy>",
                "<hierarchy><node content-desc=\"重播\"/></hierarchy>",
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

    def test_deep_link_runner_reports_safe_recipient_sign_in_stage(self) -> None:
        primary = _session("primary")
        with patch.object(harness, "_authenticate_fixed_identity", return_value=primary), patch.object(
            harness, "_ensure_profile_for_household"
        ), patch.object(
            harness,
            "_scenario_json_request",
            return_value=harness._ScenarioHttpResponse(
                201,
                {
                    "inviteUrl": "https://babytalk.example.com/invite/qa-invite-123",
                    "token": "qa-invite-123",
                },
            ),
        ), patch.object(
            harness,
            "_sign_in_apk_identity",
            side_effect=harness._ScenarioBlocked("fixed scenario user control is unavailable"),
        ), patch.object(harness, "_logout_fixed_identity"):
            result = harness.run_case_command("android_deep_link", context=_context())

        self.assertEqual(result.exit_code, 77)
        self.assertEqual(
            result.stderr,
            "android deep-link recipient_sign_in: fixed scenario user control is unavailable",
        )

    def test_apk_sign_in_reports_safe_me_stage(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness,
            "_tap_ui_label",
            side_effect=harness._ScenarioBlocked("fixed scenario user control is unavailable"),
        ):
            with self.assertRaisesRegex(
                harness._ScenarioBlocked,
                "deep-link sign-in me: fixed scenario user control is unavailable",
            ):
                harness._sign_in_apk_identity(_context(), "idempotent_event_id")

    def test_apk_sign_in_reaches_form_without_non_clickable_account_entry(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label", return_value="登录并同意"
        ) as tap, patch.object(harness, "_tap_ui_class_at"), patch.object(
            harness, "_replace_focused_text"
        ), patch.object(harness, "_find_ui_label"):
            harness._sign_in_apk_identity(_context(), "idempotent_event_id")

        self.assertEqual(
            [call.args[1] for call in tap.call_args_list],
            [
                ("我", "我的", "Me"),
                ("登录后同步数据", "登录", "Sign in"),
                ("登录并同意", "Sign in and agree"),
            ],
        )

    def test_apk_sign_in_closes_keyboard_before_consent(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label", return_value="登录并同意"
        ), patch.object(harness, "_tap_ui_class_at"), patch.object(
            harness, "_replace_focused_text"
        ), patch.object(harness, "_find_ui_label"), patch.object(
            harness, "_run_device_step"
        ) as step:
            harness._sign_in_apk_identity(_context(), "idempotent_event_id")

        self.assertIn(
            call(_context(), ["shell", "input", "keyevent", "4"]),
            step.call_args_list,
        )

    def test_apk_sign_in_accepts_care_turn_surface_after_login(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness, "_tap_ui_label", return_value="登录并同意"
        ), patch.object(harness, "_tap_ui_class_at"), patch.object(
            harness, "_replace_focused_text"
        ), patch.object(harness, "_run_device_step"), patch.object(
            harness,
            "_find_ui_label",
            side_effect=(
                harness._ScenarioBlocked("account confirmation label absent"),
                "播放音频",
            ),
        ) as find:
            harness._sign_in_apk_identity(_context(), "idempotent_event_id")

        self.assertEqual(
            find.call_args_list[1].args[1],
            ("播放音频", "重播", "听一下", "现在说一句"),
        )

    def test_apk_sign_in_returns_from_care_turn_before_opening_me(self) -> None:
        with patch.object(harness, "_launch_app"), patch.object(
            harness,
            "_tap_ui_label",
            side_effect=(
                harness._ScenarioBlocked("me is hidden by care turn"),
                "返回",
                "我",
                "登录后同步数据",
                "登录并同意",
            ),
        ) as tap, patch.object(harness, "_tap_ui_class_at"), patch.object(
            harness, "_replace_focused_text"
        ), patch.object(harness, "_run_device_step"), patch.object(
            harness, "_find_ui_label", return_value="已登录"
        ):
            harness._sign_in_apk_identity(_context(), "idempotent_event_id")

        self.assertEqual(tap.call_args_list[1].args[1], ("返回", "Back"))
        self.assertEqual(tap.call_args_list[2].args[1], ("我", "我的", "Me"))

    def test_deep_link_runner_blocks_generic_invite_words(self) -> None:
        primary = _session("primary")
        responses = iter(
            (
                harness._ScenarioHttpResponse(200, {"babyProfileId": "profile-qa"}),
                harness._ScenarioHttpResponse(
                    201,
                    {
                        "householdId": "household-qa",
                        "token": "qa-invite-123",
                        "inviteUrl": "https://babytalk.example.com/invite/qa-invite-123",
                    },
                ),
            )
        )
        with patch.object(harness, "_authenticate_fixed_identity", return_value=primary), patch.object(
            harness, "_scenario_json_request", side_effect=lambda **_: next(responses)
        ), patch.object(
            harness, "_sign_in_apk_identity"
        ), patch.object(harness, "_run_device_step"), patch.object(
            harness, "_dump_ui", return_value="<hierarchy>邀请 家庭 登录</hierarchy>"
        ), patch.object(harness, "_dumpsys", return_value="MainActivity invite/open"), patch.object(
            harness, "_logout_fixed_identity"
        ):
            result = harness.run_case_command("android_deep_link", context=_context())

        self.assertEqual(result.exit_code, 77)

    def test_deep_link_valid_destination_accepts_interactive_care_turn_entry(self) -> None:
        self.assertTrue(
            harness._deep_link_valid_destination_is_visible(
                '<hierarchy><node content-desc="现在说一句"/></hierarchy>'
            )
        )

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
        app_version="1.0.0",
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
