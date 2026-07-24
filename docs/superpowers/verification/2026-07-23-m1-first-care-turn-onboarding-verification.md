# M1 First Care-turn Onboarding Verification

- Baseline: `c40c446d0e0bf2b4071233d314c863f0e9c12856` (`origin/Develop` merge base).
- Implementation commits: `9e205f34`, `da366368`, `deddafe9`, `a91c92dd`, and `b08b6210`.
- Flutter version: Flutter 3.44.0 / Dart 3.12.0.
- Android build: not produced; no Android device or emulator was available.

References: [approved roadmap spec](../specs/2026-07-23-duolingo-like-care-path-three-milestone-roadmap-design.md), [M1 implementation plan](../plans/2026-07-23-m1-first-care-turn-onboarding.md), and [first-care-turn integration test](../../../mobile/test/integration/onboarding_first_care_turn_integration_test.dart).

## Automated gates

| Gate | Command | Result | Evidence |
| --- | --- | --- | --- |
| Task 7 full UI behavior | `flutter test` onboarding screen and Care Path widget suites | Pass | Screen behavior, semantic action order, audio fallback, 390×844 at 1.3×, and reduced motion are covered in [screen test](../../../mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart) and [Care Path surface test](../../../mobile/test/features/care_path/presentation/care_turn_surface_test.dart). |
| Real persistence integration | `flutter test test/integration/onboarding_first_care_turn_integration_test.dart` | Pass (2) | Uses real local Isar repositories; proves one bedtime event, exact starter IDs, continuity, and same-ID retry. |
| Focused M1 suite | focused onboarding/Care Path/account/route/boot/integration/firewall command from the plan | Pass (99) | Includes [copy firewall](../../../mobile/test/tool/verify_care_path_copy_firewall_test.dart), app boot, route contracts, and account continuation. |
| R4 release policy plus changed M1 tests | `flutter test test/tool/r4_release_gate_policy_test.dart ...` | Pass (38) | Restored feature-boundary budget and rechecked notifier, UI, boot, and integration paths. |
| Code generation | `dart run build_runner build --delete-conflicting-outputs` | Pass | Completed with no generated output changes. |
| Task-file format | `dart format --output=none --set-exit-if-changed` on eight Task 10 files | Pass | 0 files changed. |
| Whole mobile format | `dart format --output=none --set-exit-if-changed lib test integration_test` | Blocked | Reports 81 pre-existing, unrelated files needing formatting; Task 10 files were clean and were not mechanically reformatted. |
| Static analysis | `flutter analyze` | Pass | No issues found. |
| Whole mobile suite | `flutter test --reporter compact` | Pass (664) | Fresh post-fix run completed with `All tests passed!`. |
| Local repository CI, raw noninteractive shell | `bash ci/full-ci.sh` | Blocked | `pnpm install --frozen-lockfile` stopped at `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`; the first run also refreshed root test lock transitive dependencies. |
| Local repository CI, CI environment | `CI=true bash ci/full-ci.sh` | Pass | `full local CI passed` at `b08b62109cc2e7db78c682c1d59be72a75c228a0`; final-cleanliness and diff-check passed. |

## Contract proof

| Requirement | Test or code proof | Result |
| --- | --- | --- |
| Canonical onboarding route and legacy redirects | [route contract](../../../mobile/test/app/app_route_contract_test.dart) | Pass |
| Real selected moment starts formal Care Path | [integration test](../../../mobile/test/integration/onboarding_first_care_turn_integration_test.dart) | Pass |
| One stable local event before reaction I/O; retry stays idempotent | [notifier test](../../../mobile/test/features/onboarding/presentation/onboarding_flow_notifier_test.dart) and integration retry case | Pass |
| Next-support language is visible before trace | [flow screen test](../../../mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart) | Pass |
| Restart after confirmed next support enters trace without duplicate event | [boot test](../../../mobile/test/smoke/app_boot_test.dart) | Pass |
| Exact starter IDs flow into completion and continuity | [integration test](../../../mobile/test/integration/onboarding_first_care_turn_integration_test.dart) | Pass |
| Semantic labels, reaction order, scale, and reduced motion | [flow screen test](../../../mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart) | Pass in widget environment |
| No legacy phrase-loop copy returns | [semantic copy firewall](../../../mobile/test/tool/verify_care_path_copy_firewall_test.dart) | Pass |

## Device UAT

| Device/state | Result | Evidence |
| --- | --- | --- |
| Pixel 9 Pro, 427×952 | Not run | `flutter devices` reported Windows, Chrome, and Edge only. |
| Narrow 390×844, 1.3× text | Not run on device | Widget evidence passed; no Android target was connected. |
| TalkBack order | Not run | No Android target was connected. |
| Reduced motion | Not run on device | Widget reduced-motion check passed; no Android target was connected. |
| Offline seed flow | Not run on device | No Android target was connected. |
| Audio asset failure and retry | Not run on device | Widget fallback/retry check passed; no Android target was connected. |
| Reaction write failure and same-ID retry | Not run on device | Notifier and real-Isar integration checks passed; no Android target was connected. |
| Restart at care turn, trace, and account invitation | Not run on device | Boot tests passed; no Android target was connected. |

## Known limitations

- Real Android UAT, generated TTS audio, Bluetooth/audio-focus behavior, and actual TalkBack observation remain outstanding because no Android device or emulator was available.
- The whole-repository Dart formatter reports 81 unrelated pre-existing files. This task's files are format-clean; the debt was intentionally not mixed into the M1 change.
- Automated M1 behavior and full local CI are green. Release approval still requires the outstanding real-device UAT and resolution of the repository-wide formatting gate.
