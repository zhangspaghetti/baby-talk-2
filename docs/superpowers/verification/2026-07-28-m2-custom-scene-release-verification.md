# M2 Custom Scene Release Verification

Date: 2026-07-28
Scope: #28 / M2-12 only. Evidence below is from current workspace after #27 (`9a298682`).

## Automatable release matrix

`dart tool/verify_m2_12_release_matrix.dart` makes required M2 evidence targets explicit. `scripts/verify-m2-12-release.ps1` is repeatable runner for platform, privacy, backend, and mobile gates. Android mode only checks that an ADB device is available; it never treats device presence as human accessibility evidence.

| Gate | Evidence command | Status |
| --- | --- | --- |
| Spring AI 2 backend platform | `python tool/verify_spring_ai_2_backend_platform.py` | PASS — `Spring AI 2 backend platform contract verified` |
| Privacy / lifecycle / architecture | `dart tool/verify_m2_11_custom_scene_gates.dart` | PASS — 0 violations |
| M2-12 evidence manifest | `dart tool/verify_m2_12_release_matrix.dart` | PASS — 16 required targets present |
| M2-12 verifier tests + M2-11 negative fixtures | `flutter test test/tool/verify_m2_12_release_matrix_test.dart test/tool/verify_m2_11_custom_scene_gates_test.dart` | PASS — 8 tests |
| Backend full Maven test | `cd backend && bash mvnw clean test` | PASS — six reactor modules `SUCCESS`, `BUILD SUCCESS`, 06:02 |
| Mobile analyze | `cd mobile && flutter analyze` | PASS — no issues |
| Mobile format check | `cd mobile && dart format --output=none --set-exit-if-changed lib test integration_test` | BLOCKED — current baseline needs formatting; do not apply formatter in shared release worktree without owner approval |
| Mobile R4 policy | `cd mobile && flutter test test/tool/r4_release_gate_policy_test.dart` | PASS — 5 tests |
| Mobile full Flutter test | `cd mobile && flutter test` | PASS — 739 tests, 03:02 |
| Android UAT | `adb devices -l` | BLOCKED — no online ADB device attached |

## Coverage mapping

Backend target tests cover discovery contract; six-utterance bundle/state constraints; clientRequestId exact reuse and owner isolation; Testcontainers concurrency; generated TTS owner/content/utterance checks; and generated-audio privacy verification.

Mobile target tests cover DTO/mapper/repository; draft and auth continuation; submission reconciliation; Today/Scene widgets; generated formal Care Turn with canonical reaction/Garden/Today; audio cache/late playback; lifecycle clearing; and R4 policy. Full Maven and Flutter commands remain required execution gates, not substitutes for device UAT.

The first full Flutter run found one stale lifecycle expectation: logout now clears `generatedAudioMemory` under #27, while `local_sensitive_data_clearance_orchestrator_test.dart` still expected it skipped. The M2-12 test update asserts the required clearing behavior. Focused lifecycle/R4 tests then passed (8 tests); final full run passed 739 tests.

## Release decision

**NOT RELEASE READY.** No release-ready statement is permitted while Android risk UAT and actual TalkBack evidence are absent.

Explicit M3 deferred evidence: human listener must perform actual TalkBack spoken-order, touch-exploration, and return-focus checks. UI/widget semantics and hierarchy cannot replace that evidence.

Android risk UAT still requires a visible device/emulator and execution of: Today signed-in generated Care Turn; Scene draft/login exactly-once resume; response-loss reconciliation; force-stop during login/submission; reaction response-loss exactly-one event; starter/five-support playback; TTS failure fallback; page-leave cancellation; logout/account-switch clearing; and AI/TTS-disabled preset regression. #26 Android bytes-playback UAT is therefore still unverified.
