# M1 First Care-turn Onboarding Verification

- Baseline: `c40c446d0e0bf2b4071233d314c863f0e9c12856` (`origin/Develop` merge base).
- Implementation commits: `9e205f34`, `da366368`, `deddafe9`, `a91c92dd`, `b08b6210`, and release-verification candidate `a05db2fa`.
- Review remediation: committed on `codex/m1-first-care-turn-onboarding`, including starter persistence, serialized transitions, completion recovery, account-exit single-flight, origin-driven account return, typed continuation recovery, and monotonic formatter-baseline fixes, 2026-07-25.
- Flutter version: Flutter 3.44.0 / Dart 3.12.0.
- Android build: debug APK installed on the `Pixel_9_Pro` Android emulator (API device `emulator-5554`), 2026-07-25.

References: [approved roadmap spec](../specs/2026-07-23-duolingo-like-care-path-three-milestone-roadmap-design.md), [M1 implementation plan](../plans/2026-07-23-m1-first-care-turn-onboarding.md), and [first-care-turn integration test](../../../mobile/test/integration/onboarding_first_care_turn_integration_test.dart).

## Automated gates

| Gate | Command | Result | Evidence |
| --- | --- | --- | --- |
| Task 7 full UI behavior | `flutter test` onboarding screen and Care Path widget suites | Pass | Screen behavior, semantic action order, audio fallback, 390×844 at 1.3×, and reduced motion are covered in [screen test](../../../mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart) and [Care Path surface test](../../../mobile/test/features/care_path/presentation/care_turn_surface_test.dart). |
| Real persistence integration | `flutter test test/integration/onboarding_first_care_turn_integration_test.dart` | Pass (2) | Uses real local Isar repositories; proves one bedtime event, exact starter IDs, continuity, and same-ID retry. |
| Focused M1 suite | focused onboarding/Care Path/account/route/boot/integration/firewall command from the plan | Pass (99) | Includes [copy firewall](../../../mobile/test/tool/verify_care_path_copy_firewall_test.dart), app boot, route contracts, and account continuation. |
| R4 release policy | `flutter test test/tool/r4_release_gate_policy_test.dart` | Fail | Feature-boundary debt is 32, exceeding the hard budget of 30. This is the only failing test in the current full suite. |
| Code generation | `dart run build_runner build --delete-conflicting-outputs` | Pass | Historical run completed with no generated output changes. Fresh 2026-07-24 rerun also completed with 0 outputs. |
| Task-file format | `dart format --output=none --set-exit-if-changed` on eight Task 10 files | Pass | 0 files changed. |
| M1 cumulative Dart format | `dart format --output=none --set-exit-if-changed` on every Dart file in `f8fa0ec...HEAD` | Pass (62) | Fresh 2026-07-25 run reports 0 changed files. Ten M1-touched historical files were formatted as part of this remediation. |
| Baseline-aware mobile format | `bash test/tool/mobile_format_changed_test.sh` and `bash ci/mobile-format-changed.sh` | Pass | The synthetic Git fixtures prove that the checked-in baseline must exactly equal actual formatter debt and cannot grow after its base. Clean-SHA `a05db2fa` full CI passed this stage with its calculated merge base before reaching the separate R4 policy failure. |
| Whole mobile format | `dart format --output=none --set-exit-if-changed lib test integration_test` | Fail — 69-file historical debt | The baseline fell from 79 after formatting every historical Dart file touched by M1. The remaining debt is explicitly tracked in `ci/mobile-format-baseline.txt`. |
| Static analysis | `flutter analyze` | Pass | Fresh 2026-07-25 run: `No issues found!` (9.9s). |
| Whole mobile suite | `flutter test --concurrency=1 --reporter compact` | Fail (690; 1 failure) | Clean-SHA `a05db2fa` run completed 690 tests. Its sole failure is the R4 feature-boundary debt budget: actual 32, maximum 30. |
| Local repository CI | `bash ci/full-ci.sh` | Fail at `mobile-r4` | Clean-SHA `a05db2fa` CI ran backend, admin, mobile analyze, formatter-baseline regression, and formatter-baseline stages, then reproduced the same R4 policy failure. |
| Review remediation regressions | account entry, notifier, continuation store, and onboarding screen suites | Pass (56) | Fresh 2026-07-25 run covers real Account router return after a continuation I/O failure, expired-return completion, origin forwarding, account-exit exclusivity, write/delete serialization, typed read recovery, disabled invitation actions, and prior recovery regressions. |

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
| Unknown outcome preserves one immutable local event | `OnboardingFlowNotifier._restorePendingCareTurn`, `CarePathRepository.restoreConfirmedReaction`, and real-Isar notifier regression | Pass |
| Event absent restores the original starter phrase for same-ID retry | `CarePathRepository.restorePendingReaction` and retry-ID screen regression | Pass |
| Reaction failure has recovery affordance | `CareTurnSurface` retry contract and widget regression | Pass |
| Confirmed trace can continue without next support | `CareTurnSurface` accepts confirmed `heldWithFallback` state; widget regression | Pass |
| Moment-start failure can return to selection | `OnboardingFlowNotifier.chooseAnotherMoment` and screen regression | Pass |
| Account continuation has one completing consumer | Provider listener removed; `handleAccountReturn` and cold-start recovery tests | Pass |
| Signed-in account save does not open account entry | `beginAccountSave` direct completion and screen regression | Pass |
| User-facing care-turn failures are safe | `CareTurnFailureKind`, repository/notifier mapping, safe-copy regressions | Pass |
| Flow-store writes do not create unhandled UI errors | `_saveTransition` recovery regression | Pass |
| Failed persistence prevents later side effects | `_saveTransition` returns `bool`; notifier regressions prove failed moment save does not start Care Path and failed pending-ID save does not record a reaction | Pass |
| Failed trace persistence is recoverable | `hasPendingTracePersistence`, `retryPersistConfirmedCareTurn`, and screen regression replace a dead continue CTA with `重新保存记录` | Pass |
| Starter phrase persistence can recover in place | `hasPendingStarterPhrasePersistence`, `retryPersistStarterPhrase`, and the Care Turn recovery panel keep the original turn and block reaction writing until its phrase ID is saved | Pass |
| Regular flow mutations cannot race | notifier-wide transition queue, disabled ordinary selections/CTA, and `OnboardingFlowStore` write/delete mutex | Pass |
| Completion persistence maps to safe recovery | continuation and completed-snapshot writes return safe retry messages; cleanup is best-effort only after the completed snapshot exists | Pass |
| Account invitation exits are single-flight | `OnboardingFlowNotifier._runExclusiveExitAction`; notifier and screen regressions prove duplicate save reuses one write/navigation, account-save wins over a concurrent local exit, and both controls disable while persistence is pending | Pass |
| Account login return is independent of continuation-file I/O | `AccountEntryOrigin.onboardingContinuation` makes the real Account router pop `AccountEntryResult.signedIn` exactly once after successful sign-in; the parent notifier then maps typed continuation outcomes | Pass |
| Continuation read errors are distinguishable and retryable | `AuthContinuationReadResult` reports `notFound` / `expired` / `available` / `corrupt` / `ioFailure`; I/O does not delete the file, the real Account router returns to onboarding, and notifier regressions show safe retry copy | Pass |
| Expired onboarding continuation does not strand a signed-in user | `handleAccountReturn` completes a flow with a confirmed trace for `expired` or `notFound`; cold-start recovery still requires an available save intent | Pass |
| Continuation file mutations are serialized | `AuthContinuationStore._enqueueMutation`; concurrent write/delete regression leaves no shared temporary file | Pass |
| Formatter baseline only shrinks | `mobile-format-changed.sh` requires `actual debt == current baseline` and `current baseline ⊆ merge-base baseline`; `full-ci.sh` injects `MERGE_BASE_SHA` | Pass in script regression |
| TalkBack traversal contract | `care_turn_surface_test.dart` asserts `CareTurnSurface` semantic sort keys for main phrase → Chinese → timing → listen → reaction → quiet exit | Pass in widget and Android hierarchy; actual TalkBack speech navigation pending |

## Device UAT

| Device/state | Result | Evidence |
| --- | --- | --- |
| Pixel 9 Pro emulator | Partial — fresh-launch smoke | Clean-SHA `a05db2fa` debug APK installed; `adb shell pm clear com.babytalk.mobile` then cold launch showed onboarding welcome, and tapping `开始` reached age selection. No crash or white screen observed. |
| Fresh Case A: save account → sign in → Today | Not run | The release verification run did not use a test account or complete login-return continuation. |
| Fresh Case B: local-only → Today | Not run | The release verification run stopped after validating the fresh welcome-to-age transition. |
| Fresh Case C: double-tap account save | Not run | Covered by widget/notifier regression; fresh-device confirmation remains required. |
| Fresh Case D: corrupt continuation | Not run | Covered by typed-store/notifier regression; fresh-device fault injection remains required. |
| Fresh Case E: TalkBack focus and return focus | Not run | Accessibility hierarchy exists, but actual TalkBack navigation was not run. |
| Post-fix Android runtime relaunch | Pass — retained-state smoke | Fresh 2026-07-25 `flutter run -d emulator-5554` launched the current source. The Android accessibility dump shows Today with the persisted bedtime continuity phrase and the four-tab shell. Existing emulator data was intentionally retained, so this does not replace a clean onboarding run. |
| Seed audio | Pass | `听一下` acquired Android audio focus, completed, restored its enabled state, and exposed `已听过一次`. |
| Care Turn accessibility hierarchy | Pass — hierarchy evidence | Android accessibility tree exposes ordered phrase+Chinese, timing, `听一下`, `我说了`, then reaction entry. Actual TalkBack speech navigation remains pending. |
| Reaction and Garden trace | Pass | A canonical reaction produced next support and a real Garden trace before entering trace and Today. |
| Pending unknown-outcome kill/recovery | Not run on device | Process-kill timing could not deterministically leave a pending local ID; real-Isar notifier regression covers this state. |
| Reaction write failure and same-ID retry | Not run on device | Deterministic repository/notifier/widget tests cover it; no device fault injection was introduced. |
| Signed-in account continuation | Not run on device | Account continuation regressions cover it; no test account was used in UAT. |

## Known limitations

- Full release UAT remains outstanding: narrow/large viewport matrix, 1.3× device text, reduced motion, actual TalkBack speech navigation, Bluetooth/audio-focus interruptions, generated TTS, and account/pending-write fault injection.
- The release-verification run deliberately cleared emulator app data. UIAutomator returned an empty root node, so the fresh onboarding smoke used ADB screenshots and coordinate input; this is not a substitute for TalkBack or full end-to-end UAT.
- The whole-repository Dart formatter still reports 69 historical files. `ci/mobile-format-changed.sh` requires the baseline to exactly equal that debt and only shrink relative to the full-CI merge base; this stage passed in the clean-SHA full-CI run, while the separate R4 policy remains blocking.
- Clean-SHA `a05db2fa` full CI is not green: it reproducibly stops at the R4 feature-boundary policy (32 candidates versus the budget of 30). M1 remains not release-ready until this gate and the listed fresh-device cases pass.
