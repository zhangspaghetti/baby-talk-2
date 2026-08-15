# Onboarding V4 Continuous Loop Release Verification

- Date: 2026-08-15
- Scope: #76 release proof for #67-#75.
- Verified code SHA: `f22669a0b6bf544621a5d1d02fa107e7e5a4c801`.
- Status: **NOT RELEASE READY**. Repository and automated Android device gates pass; human Android visual review, human audibility, and actual TalkBack evidence are absent.

## Historical audit

Git history and current code show #67-#74 were already implemented before this release pass. #75 was incomplete and is now implemented by `05a3bac1` (`feat(onboarding): remove legacy M1 funnel`). The release pass did not reimplement #67-#74.

## Reconciled A1-A18 acceptance matrix

| Criterion | Evidence | Result |
| --- | --- | --- |
| A1 Care Entries; no English phrase list | [surface widget/goldens](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated |
| A2 `onboarding.primary` has exactly four safe entries | [registry contract](../../../mobile/test/features/care_entry/care_entry_registry_test.dart) | Pass automated |
| A3 Tile selection and one start CTA | [surface widget](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart), [controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated |
| A4 Reviewed pronunciation; no microphone | [audio API/output](../../../mobile/test/features/care_entry/guest_onboarding_audio_api_test.dart), [surface semantics](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart), [Android release branches](../../../mobile/integration_test/onboarding_v4_release_branches_test.dart) | Pass automated device HTTP/output control; human audibility pending |
| A5 `我说了` precedes Baby Reaction | [surface widget](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart), [controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated |
| A6 Reaction only after durable PhraseSaid | [controller durable-order regression](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated |
| A7 No reaction continues after four seconds | [fake-time controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [wire contract](../../../mobile/test/features/care_entry/guest_onboarding_conversation_api_test.dart), [Android release branches](../../../mobile/integration_test/onboarding_v4_release_branches_test.dart) | Pass device automation |
| A8 Next request contains prior utterance/action/reaction/version semantics | [mobile wire contract](../../../mobile/test/features/care_entry/guest_onboarding_conversation_api_test.dart), [backend turn service](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/onboarding/conversation/OnboardingConversationTurnServiceTest.java) | Pass automated |
| A9 One durable spoken phrase enables explicit completion | [repository integration](../../../mobile/test/features/care_entry/onboarding_conversation_repository_test.dart), [controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated |
| A10 Empty nickname displays `宝宝` | [surface widget/goldens](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated |
| A11 Nickname and age are not gates/inputs | [controller state](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [surface widget](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated |
| A12 `稍后再来` enters Today after durable checkpoint | [surface routing seam](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart), [repository restore](../../../mobile/test/features/care_entry/onboarding_conversation_repository_test.dart), [Android release branches](../../../mobile/integration_test/onboarding_v4_release_branches_test.dart) | Pass device defer/resume automation |
| A13 Banned learning/scoring/AI copy absent | [semantic copy firewall](../../../mobile/test/tool/verify_care_path_copy_firewall_test.dart) | Pass automated |
| A14 Missing mentor/sprout assets use text/initials, never PNG crops | [surface widget and six goldens](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated; human visual review pending |
| A15 Guest identity/text/audio privacy and TTL | [backend conversation service](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/onboarding/conversation/OnboardingConversationServiceTest.java), [audio capability](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/onboarding/conversation/OnboardingAudioCapabilityServiceTest.java), final CI privacy gates | Pass automated |
| A16 Timeout is stable local content; late remote cannot replace it | [fake-time controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [registry fallback](../../../mobile/test/features/care_entry/care_entry_registry_test.dart), [Android release branches](../../../mobile/integration_test/onboarding_v4_release_branches_test.dart) | Pass device automation |
| A17 PhraseSaid creates at most one Garden Trace across retry/resume | [real file repository integration](../../../mobile/test/features/care_entry/onboarding_conversation_repository_test.dart), [controller retry/resume](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [Android Garden handoff](../../../mobile/integration_test/onboarding_v4_release_branches_test.dart) | Pass integration idempotency and device Garden handoff |
| A18 Continue/Today/Garden preserve exact state without account | [controller handoffs](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [Android Continue/Garden cases](../../../mobile/integration_test/onboarding_v4_release_branches_test.dart), [Android Today case](../../../mobile/integration_test/s06_full_chain_release_flow_test.dart) | Pass device automation |

## End-to-end closure matrix

| Required scenario | Current highest evidence | Result |
| --- | --- | --- |
| Online generation | Android app through production HTTP client to controlled in-memory backend | Pass device automation |
| Offline sticky fallback | Android held HTTP request, four-second local fallback, then late success | Pass device automation |
| Audio success and failure | Android 503 safe failure followed by retry with exact controlled bytes | Pass device automation; **human audibility pending** |
| No-reaction timeout | Android four-second timeout followed by remote next turn | Pass device automation |
| Defer/resume | Android durable checkpoint, shell entry, explicit `/onboarding` re-entry | Pass device automation |
| Continue | Android exact-state handoff | Pass device automation |
| Today finish | Android fresh-install S06 | Pass device automation |
| Garden handoff | Android published trace and Garden shell destination | Pass device automation |
| Human visuals and actual TalkBack | No human listener record | **Pending P1** |

## Exact automated gates

| Gate | Command | Result |
| --- | --- | --- |
| Spring AI 2 platform | `python3 tool/verify_spring_ai_2_backend_platform.py` | Pass in final full CI |
| Backend clean suite | `cd backend && bash mvnw clean test` | Pass: six reactor modules `SUCCESS`; app-api 1002 tests; `BUILD SUCCESS`; 04:24 |
| Mobile analysis | `cd mobile && flutter analyze` | Pass: `No issues found!` |
| Mobile full suite | `cd mobile && flutter test --concurrency=1` | Pass: 837 tests |
| Repository CI | `bash ci/full-ci.sh` | Pass on verified code SHA: backend, admin, mobile, format, R4, semantic/privacy, generated metadata, diff, and cleanliness gates |
| Android V4 release branches | `cd mobile && flutter test integration_test/onboarding_v4_release_branches_test.dart --reporter expanded` | Pass: 4 tests in one Android device/emulator run |
| Android release/boot flow | `cd mobile && flutter test integration_test/s06_full_chain_release_flow_test.dart` | Pass: 2 tests on Android device/emulator |

## Android automated artifact evidence

- Source SHA: `f22669a0b6bf544621a5d1d02fa107e7e5a4c801`.
- Archived tested artifact: `artifacts/onboarding-v4/f22669a0b6bf544621a5d1d02fa107e7e5a4c801/app-debug.apk` (Git-ignored local release artifact; read-only).
- Size: `102303008` bytes.
- Build timestamp: `2026-08-15T01:24:14.0948618Z`.
- SHA-256: `ADC39B3ABE8AB8F853C00D85A047E3993045EB22802C34D015E8E984FF06A434`.
- Device runs proved controlled online HTTP generation, audio failure/retry bytes, no-reaction timeout, offline sticky fallback, defer/resume, Continue/Today/Garden handoffs, one durable Today Care Turn, and the malformed-snapshot boot failure surface.

This is automated device evidence. It does not prove visual quality, human audibility, TalkBack spoken order, touch exploration, or return focus.

## Release-pass remediations

- `116690d6`: inject Care Path dependencies into the Mentor widget harness.
- `594b31a0`: satisfy backend Checkstyle without behavior changes.
- `57f0d2f6`: format Care Entry provider wiring.
- `e6c87891`: remove font-license trailing whitespace caught by CI.
- `146f2d1a`: wait for Care Path's shared-Isar consumer before app-boot test teardown, removing repository-close races.
- `f22669a0`: add Android V4 release-branch coverage and close Mentor repository ownership with its Riverpod scope.

## Release decision

**NOT RELEASE READY.** #76 remains unresolved only because manual Android visual review, human audibility, and actual TalkBack spoken-order, touch-exploration, and return-focus evidence have not been performed. Widget semantics, controlled audio bytes, Android hierarchy, and component/integration tests cannot substitute for those human sessions. Do not close #76 or the parent rollout until every pending P1 row is recorded and reviewed.
