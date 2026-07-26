# M1 First Care-turn Onboarding Verification

- Baseline: `c40c446d0e0bf2b4071233d314c863f0e9c12856` (`origin/Develop` merge base).
- Verified code SHA: `eb7aa6d8c517ab9085b32a5f5972f0a2331a8b78`.
- Implementation commits include route-contract remediation `a92d32f5`, starter-persistence remediation `88600e7`, deterministic unknown-outcome UAT `48c43dc5`, and Care Turn accessibility remediations through `eb7aa6d8`.
- Review remediation: `88600e7` replaces the derived starter-persistence flag with explicit `idle` / `saving` / `failed` / `saved` state, adds delayed-success and true-failure regressions, and emits debug-only, redacted persistence diagnostics, 2026-07-26.
- Flutter version: Flutter 3.44.0 / Dart 3.12.0.
- Android UAT device: `emulator-5554`, Android 15, system image model `sdk_gphone64_x86_64`; TalkBack `15.0.0.639625893`, 2026-07-26. The original AVD is named Pixel 9 Pro.

References: [approved roadmap spec](../specs/2026-07-23-duolingo-like-care-path-three-milestone-roadmap-design.md), [M1 implementation plan](../plans/2026-07-23-m1-first-care-turn-onboarding.md), and [first-care-turn integration test](../../../mobile/test/integration/onboarding_first_care_turn_integration_test.dart).

## Automated gates

| Gate | Command | Result | Evidence |
| --- | --- | --- | --- |
| Task 7 full UI behavior | `flutter test` onboarding screen and Care Path widget suites | Pass | Screen behavior, semantic action order, audio fallback, 390×844 at 1.3×, and reduced motion are covered in [screen test](../../../mobile/test/features/onboarding/presentation/screens/onboarding_flow_screen_test.dart) and [Care Path surface test](../../../mobile/test/features/care_path/presentation/care_turn_surface_test.dart). |
| Real persistence integration | `flutter test test/integration/onboarding_first_care_turn_integration_test.dart` | Pass (2) | Uses real local Isar repositories; proves one bedtime event, exact starter IDs, continuity, and same-ID retry. |
| Focused M1 suite | focused onboarding/Care Path/account/route/boot/integration/firewall command from the plan | Pass (99) | Includes [copy firewall](../../../mobile/test/tool/verify_care_path_copy_firewall_test.dart), app boot, route contracts, and account continuation. |
| R4 release policy | `flutter test test/tool/r4_release_gate_policy_test.dart` | Pass (4) | `AccountEntryOrigin` and `AccountEntryResult` now live in the app router contract; forbidden candidates return to the hard budget of 30. |
| Code generation | `dart run build_runner build --delete-conflicting-outputs` | Pass | Historical run completed with no generated output changes. Fresh 2026-07-24 rerun also completed with 0 outputs. |
| Task-file format | `dart format --output=none --set-exit-if-changed` on eight Task 10 files | Pass | 0 files changed. |
| M1 cumulative Dart format | `dart format --output=none --set-exit-if-changed` on every Dart file in `f8fa0ec...HEAD` | Pass (62) | Fresh 2026-07-25 run reports 0 changed files. Ten M1-touched historical files were formatted as part of this remediation. |
| Baseline-aware mobile format | `bash test/tool/mobile_format_changed_test.sh` and `bash ci/mobile-format-changed.sh` | Pass | The synthetic Git fixtures prove that the checked-in baseline must exactly equal actual formatter debt and cannot grow after its base. Clean code SHA `88600e7` full CI passed this stage with its calculated merge base. |
| Whole mobile format | `dart format --output=none --set-exit-if-changed lib test integration_test` | Fail — 69-file historical debt | The baseline fell from 79 after formatting every historical Dart file touched by M1. The remaining debt is explicitly tracked in `ci/mobile-format-baseline.txt`. |
| Static analysis | `flutter analyze` | Pass | Fresh 2026-07-26 run on clean code SHA `88600e7`: `No issues found!`. |
| Whole mobile suite | `flutter test --concurrency=1 --reporter compact` | Pass (695) | Clean code SHA `88600e7` completed all 695 tests with zero failures. |
| Local repository CI | `bash ci/full-ci.sh` | Pass | Clean code SHA `88600e7` completed backend, admin, mobile, formatter, R4, diff-check, and final-cleanliness gates. The first run exposed an unrelated flaky admin overview-client test; its isolated retry passed, and the clean full rerun passed. |
| Review remediation regressions | account entry, notifier, continuation store, and onboarding screen suites | Pass (56) | Fresh 2026-07-25 run covers real Account router return after a continuation I/O failure, expired-return completion, origin forwarding, account-exit exclusivity, write/delete serialization, typed read recovery, disabled invitation actions, and prior recovery regressions. |

## Final clean-SHA automated evidence

| Gate | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | Pass: clean code SHA `eb7aa6d8`, 0 issues. |
| Whole mobile suite | `flutter test --concurrency=1 --reporter compact` | Pass: 701 tests, 0 failures. |
| Repository CI | `bash ci/full-ci.sh` | Pass: exit 0; R4 forbidden candidates `30`; changed Dart files format-clean; historical baseline `69`; final-cleanliness passed. |
| Diff / tree | `git diff --check`; `git status --short` | Pass before this evidence-document update: both commands had no output. |

## Starter-persistence diagnosis

The Android happy-path panel was not a filesystem failure. The old derived condition treated the normal interval between the first `careTurn` snapshot write and the second `starterPhraseId` write as a failure. On the affected run, the final durable snapshot contained the expected starter phrase ID and there was no `.tmp` file.

`88600e7` models that interval explicitly: `idle → saving → saved`, with `failed` entered only when the second write throws. During the delayed-success regression and fresh Android run, the UI presents the neutral `正在保存这句话…` state and disables `我说了`; it automatically enables the control after `saved`. A genuine write failure alone exposes `重新保存并继续`.

Debug builds emit redacted stages only: `transition_saved`, `care_turn_started`, `starter_save_started`, `starter_save_succeeded`, or `starter_save_failed` with the exception runtime type. The store failure diagnostic records only flow/tmp existence and whether the persisted/requested starter is present; it does not log phrase IDs, paths, payloads, or raw exception text.

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
| Starter phrase persistence distinguishes saving from failure | `StarterPhrasePersistenceState` is explicit (`idle` / `saving` / `failed` / `saved`); delayed-success notifier/widget regressions show a neutral saving panel and automatic enablement of `我说了`, while real write failure alone exposes `重新保存并继续` | Pass in automated regression and fresh Android happy path |
| Regular flow mutations cannot race | notifier-wide transition queue, disabled ordinary selections/CTA, and `OnboardingFlowStore` write/delete mutex | Pass |
| Completion persistence maps to safe recovery | continuation and completed-snapshot writes return safe retry messages; cleanup is best-effort only after the completed snapshot exists | Pass |
| Account invitation exits are single-flight | `OnboardingFlowNotifier._runExclusiveExitAction`; notifier and screen regressions prove duplicate save reuses one write/navigation, account-save wins over a concurrent local exit, and both controls disable while persistence is pending | Pass |
| Account login return is independent of continuation-file I/O | `AccountEntryOrigin.onboardingContinuation` makes the real Account router pop `AccountEntryResult.signedIn` exactly once after successful sign-in; the parent notifier then maps typed continuation outcomes | Pass |
| Continuation read errors are distinguishable and retryable | `AuthContinuationReadResult` reports `notFound` / `expired` / `available` / `corrupt` / `ioFailure`; I/O does not delete the file, the real Account router returns to onboarding, and notifier regressions show safe retry copy | Pass |
| Expired onboarding continuation does not strand a signed-in user | `handleAccountReturn` completes a flow with a confirmed trace for `expired` or `notFound`; cold-start recovery still requires an available save intent | Pass |
| Continuation file mutations are serialized | `AuthContinuationStore._enqueueMutation`; concurrent write/delete regression leaves no shared temporary file | Pass |
| Formatter baseline only shrinks | `mobile-format-changed.sh` requires `actual debt == current baseline` and `current baseline ⊆ merge-base baseline`; `full-ci.sh` injects `MERGE_BASE_SHA` | Pass in script regression |
| TalkBack traversal structure | `care_turn_surface_test.dart` asserts separate English and Chinese focus nodes, semantic sort keys, and no duplicate Care Turn title focus | Pass in widget and Android hierarchy; actual spoken traversal remains incomplete |

## Device UAT

| Device/state | Result | Evidence |
| --- | --- | --- |
| Pixel 9 Pro emulator | Pass — starter happy path | After clearing app data and installing `88600e7`, fresh onboarding reached the starter phrase with no recovery panel; the durable flow snapshot contained `starterPhraseId`, no starter `.tmp` file remained, and debug logs recorded `transition_saved → care_turn_started → starter_save_started → starter_save_succeeded`. |
| Fresh Case A: save account → sign in → Today | Pass | A new user completed Care Turn, saved to account, signed in with the local UAT account, popped once back through onboarding, and reached Today. No stuck Account page or white screen occurred. |
| Fresh Case B: local-only → Today | Pass | `暂时不用` reached Today with the flow and continuation files absent and the completed onboarding snapshot present. |
| Fresh Case C: double-tap account save | Pass — device smoke | Rapid double tap opened one Account page and produced one continuation file; notifier/screen regressions separately prove the single write/navigation invariant. |
| Fresh Case D: corrupt continuation | Pass | After Account opened, the device continuation file was replaced with invalid JSON. Successful sign-in popped to onboarding, removed the corrupt continuation, and displayed `暂时无法读取账号继续状态，请再试一次。`; it did not silently enter Today. |
| Signed-in continuation | Pass | With the same UAT account signed in and the onboarding invitation visible, `保存并继续` completed directly to Today without opening Account Entry. |
| Fresh Case E: TalkBack focus and return focus | Partial | TalkBack was enabled on the emulator and touch exploration was active. The Android hierarchy exposes the intended Care Turn sequence, but UIAutomator cannot observe TalkBack's spoken accessibility-focus order or post-return focus; this is not marked passed. |
| Post-fix Android runtime relaunch | Pass — retained-state smoke | `flutter run -d emulator-5554` launched the current source. The Android accessibility dump shows Today with the persisted bedtime continuity phrase and the four-tab shell. |
| Seed audio | Pass | `听一下` acquired Android audio focus, completed, restored its enabled state, and exposed `已听过一次`. |
| Care Turn accessibility hierarchy | Pass — hierarchy evidence | Android accessibility tree exposes ordered phrase+Chinese, timing, `听一下`, `我说了`, then reaction entry. Actual TalkBack speech navigation remains pending. |
| Reaction and Garden trace | Pass | A canonical reaction produced next support and a real Garden trace before entering trace and Today. |
| Deterministic unknown-outcome / same-ID retry | Pass — Android debug UAT | Fresh local onboarding used `BABY_TALK_UAT=true` and `M1_UAT_REACTION_RESPONSE_MODE=response_lost_once`. The formal repository chain wrote the real event before the harness discarded only the first response. The page showed safe unknown-outcome copy, preserved the selected canonical reaction, and exposed retry. Redacted diagnostics before retry: pending local event ID stable; interaction event count `1`. After retry: count `1`; resolved event ID equals pending ID `true`; immutable facts match `true`; Garden trace produced `true`; trace persisted `true`. |

## Known limitations

- The sole M1 release blocker is actual human TalkBack listening and touch-exploration evidence for Care Turn traversal, Account return focus, and unknown-outcome retry focus. It cannot be inferred from UIAutomator or widget semantics.
- Deferred to M2/M3: generated TTS; Bluetooth and complete audio-focus interruption matrix; 390×844 / 427×952 full visual matrix; 1.3× full-page matrix; reduced-motion full-page matrix; and product-wide TalkBack traversal.
- The release-verification run deliberately cleared emulator app data. UIAutomator was intermittently unable to return a root node immediately after launch, so coordinate input was used only to advance the fresh flow; semantic hierarchy and persisted-file checks were captured once the view was available. This is not a substitute for TalkBack or full end-to-end UAT.
- The whole-repository Dart formatter still reports 69 historical files. `ci/mobile-format-changed.sh` requires the baseline to exactly equal that debt and only shrink relative to the full-CI merge base; this stage passed in the clean-SHA full-CI run. R4 release policy also passed and is not a remaining blocker.
- Clean code SHA `eb7aa6d8` full CI is green. R4 is passing at the hard budget of 30 and is not a blocker. M1 remains **NOT RELEASE READY** until the remaining actual-TalkBack evidence is recorded by a human listener.
