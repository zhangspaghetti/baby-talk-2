# M2 Custom Scene Release Verification

Date: 2026-07-28
Scope: #28 / M2-12 only. Evidence below is from current workspace after #27 (`9a298682`).

## Automatable release matrix

`dart tool/verify_m2_12_release_matrix.dart` makes required M2 evidence targets explicit. `scripts/verify-m2-12-release.ps1` is repeatable runner for platform, privacy, backend, and mobile gates. Android mode only checks that an ADB device is available; it never treats device presence as human accessibility evidence.

| Gate | Evidence command | Status |
| --- | --- | --- |
| Spring AI 2 backend platform | `python tool/verify_spring_ai_2_backend_platform.py` | PASS — `Spring AI 2 backend platform contract verified` |
| Production-default custom-scene release wiring | `dart tool/verify_custom_scene_production_release.dart` | PASS — mobile default, production Helm routing/Secret, runtime enable mapping, and release APK/AAB workflow are fail-closed |
| Privacy / lifecycle / architecture | `dart tool/verify_m2_11_custom_scene_gates.dart` | PASS — 0 violations |
| M2-12 evidence manifest | `dart tool/verify_m2_12_release_matrix.dart` | PASS — 18 required targets present |
| M2-12 verifier tests + M2-11 negative fixtures | `flutter test test/tool/verify_m2_12_release_matrix_test.dart test/tool/verify_m2_11_custom_scene_gates_test.dart` | PASS — 8 tests |
| Backend full Maven test | `cd backend && bash mvnw clean test` | PASS — six reactor modules `SUCCESS`, `BUILD SUCCESS`, 06:02 |
| Backend generated-audio HTTP E2E | `cd backend && bash mvnw -pl app-api -am '-Dtest=GeneratedUtteranceAudioHttpIntegrationTest' '-Dsurefire.failIfNoSpecifiedTests=false' test` | PASS — 1 test; real random-port HTTP/JWT/consent/owner/ACTIVE bundle path with dev-only fake speech bytes |
| Mobile analyze | `cd mobile && flutter analyze` | PASS — no issues |
| Mobile format check | `cd mobile && dart format --output=none --set-exit-if-changed lib test integration_test` | BLOCKED — current baseline needs formatting; do not apply formatter in shared release worktree without owner approval |
| Mobile R4 policy | `cd mobile && flutter test test/tool/r4_release_gate_policy_test.dart` | PASS — 5 tests |
| Mobile full Flutter test | `cd mobile && flutter test` | PASS — 739 tests, 03:02 |
| Android UAT | `adb devices -l` | PARTIAL — recreated API35 emulator accepts current APK; automated evidence exists, but required generated endpoint and human UAT remain open |

## Coverage mapping

Backend target tests cover discovery contract; six-utterance bundle/state constraints; clientRequestId exact reuse and owner isolation; Testcontainers concurrency; generated TTS owner/content/utterance checks; and generated-audio privacy verification.

Mobile target tests cover DTO/mapper/repository; draft and auth continuation; submission reconciliation; Today/Scene widgets; generated formal Care Turn with canonical reaction/Garden/Today; audio cache/late playback; lifecycle clearing; and R4 policy. Full Maven and Flutter commands remain required execution gates, not substitutes for device UAT.

The first full Flutter run found one stale lifecycle expectation: logout now clears `generatedAudioMemory` under #27, while `local_sensitive_data_clearance_orchestrator_test.dart` still expected it skipped. The M2-12 test update asserts the required clearing behavior. Focused lifecycle/R4 tests then passed (8 tests); final full run passed 739 tests.

## Android risk evidence — 2026-07-28

Device: `emulator-5554`, `sdk_gphone64_x86_64`, Android 15 / API 35.

`cd mobile && flutter build apk --debug` produced `build/app/outputs/flutter-apk/app-debug.apk` (221,868,078 bytes). Initial install failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE` at 583 MB free. After explicit user authorization, `Pixel_9_Pro` was stopped and recreated with `-wipe-data -no-snapshot`; `/data/user/0` then had 5.0 GB free. `adb install -r build/app/outputs/flutter-apk/app-debug.apk` succeeded.

The installed `com.babytalk.mobile` version `1.0.0` has `lastUpdateTime=2026-07-28 10:47:00`. Cold start reached fully drawn `MainActivity` in 6.694s without a captured fatal exception. Automated fresh onboarding reached current-build preset Care Turn `Warm water.`. Pressing `听一下` disabled that control; on completion, Android hierarchy exposed `已听过一次`. Logcat recorded the app requesting/abandoning media audio focus and `AudioTrack` stopping after 220,500 delivered frames. This proves current-build packaged-asset playback pipeline execution, not human audibility.

Generated-audio contract and failure tests remain local supplements. `GeneratedUtteranceAudioServiceTest` covers accepted-session owner/ACTIVE/approved-utterance enforcement, empty/oversize/wrong-MIME provider output rejection, and retryable provider timeout. `flutter test test/features/care_path/presentation/care_turn_surface_test.dart test/app/local_sensitive_data_clearance_registry_test.dart test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart test/features/practice/generated/generated_audio_api_test.dart test/features/care_path/presentation/care_audio_playback_controller_test.dart` passed 21 tests. They cover authenticated route validation, empty/wrong-MIME/oversize client rejection, UI error fallback restoring `听一下`, late-playback cancellation, logout policy clearing `generatedAudioMemory`, real registry clearance removing an occupied generated-audio cache, and mobile controlled HTTP bytes wire format. Fakes/mocks remain explicitly bounded.

Endpoint E2E now exists: `GeneratedUtteranceAudioHttpIntegrationTest` starts current application on a random local port with Testcontainers PostgreSQL. It creates a real JWT through `/api/v1/auth/challenges` and `/api/v1/auth/verify`, creates consent through `/api/v1/consent/accept`, and commits a six-utterance `care_path` bundle before marking it ACTIVE. Before consent, audio returns `409 consent_required`; accepted owner receives `200 audio/mpeg`, no-store/private and authorization Vary headers, expected voice-version header, and bytes from existing dev-only `FakeGeneratedSpeechSynthesisProvider`; an accepted different owner receives `404 generated_audio_not_found`. This is real auth/consent/owner/ACTIVE HTTP endpoint evidence, but fake speech is not an external real-TTS claim. Mobile now sends `Accept: audio/mpeg, application/json` so contract errors negotiate correctly instead of returning an incidental 500; its controlled loopback HTTP test verifies real `GeneratedAudioApi` request/bytes parsing. No current emulator app session can be safely provisioned with this ephemeral server's JWT and DB fixture, so mobile-to-this-backend endpoint playback remains separate from this evidence.

Android output-layer evidence: `flutter test integration_test/m2_generated_audio_bytes_playback_test.dart -d emulator-5554 --reporter expanded` rebuilt, installed, and passed on recreated API35 emulator (`00:47 +2: All tests passed!`). Test loads six independent known MP3 assets into memory and invokes production `AudioplayersCareAudioOutput.playBytes`, which uses `BytesSource`; each completion is awaited. It also starts a controlled loopback HTTP endpoint inside emulator: production `GeneratedAudioApi` sends expected GET, Authorization, Accept, and app-version headers; accepted test session and `GeneratedAudioRepository` return controlled MP3 bytes through `SourceNeutralCareAudioPlaybackController` to `AudioplayersCareAudioOutput`, then `BytesSource` completes. This proves controlled on-device network byte parsing and output, without temporary files. Loopback endpoint is not Spring backend: it does not prove backend authentication, consent, owner/ACTIVE lookup, or cloud TTS.

## Release decision

**NOT RELEASE READY.** No release-ready statement is permitted while Android risk UAT and actual TalkBack evidence are absent.

Explicit M3 deferred evidence: human listener must perform actual TalkBack spoken-order, touch-exploration, and return-focus checks. UI/widget semantics and hierarchy cannot replace that evidence.

Android risk UAT still requires installation of current source on a visible device/emulator and execution of: Today signed-in generated Care Turn; Scene draft/login exactly-once resume; response-loss reconciliation; force-stop during login/submission; reaction response-loss exactly-one event; starter/five-support playback; TTS failure fallback; page-leave cancellation; logout/account-switch clearing; and AI/TTS-disabled preset regression. #26 Android bytes-playback UAT is therefore still unverified.
