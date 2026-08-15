# Onboarding V4 Continuous Loop Release Verification

- Date: 2026-08-15
- Scope: #76 release proof for #67-#75.
- Verified code SHA: `146f2d1ac5ec9ed30fbc63b315323d4b52d67568`.
- Status: **NOT RELEASE READY**. Repository gates pass; required device E2E branches, human Android visual review, and actual TalkBack evidence are absent.

## Historical audit

Git history and current code show #67-#74 were already implemented before this release pass. #75 was incomplete and is now implemented by `05a3bac1` (`feat(onboarding): remove legacy M1 funnel`). The release pass did not reimplement #67-#74.

## Reconciled A1-A18 acceptance matrix

| Criterion | Evidence | Result |
| --- | --- | --- |
| A1 Care Entries; no English phrase list | [surface widget/goldens](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated |
| A2 `onboarding.primary` has exactly four safe entries | [registry contract](../../../mobile/test/features/care_entry/care_entry_registry_test.dart) | Pass automated |
| A3 Tile selection and one start CTA | [surface widget](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart), [controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated |
| A4 Reviewed pronunciation; no microphone | [audio API/output](../../../mobile/test/features/care_entry/guest_onboarding_audio_api_test.dart), [surface semantics](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated; device audio pending |
| A5 `我说了` precedes Baby Reaction | [surface widget](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart), [controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated |
| A6 Reaction only after durable PhraseSaid | [controller durable-order regression](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated |
| A7 No reaction continues after four seconds | [fake-time controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [wire contract](../../../mobile/test/features/care_entry/guest_onboarding_conversation_api_test.dart) | Pass automated; E2E pending |
| A8 Next request contains prior utterance/action/reaction/version semantics | [mobile wire contract](../../../mobile/test/features/care_entry/guest_onboarding_conversation_api_test.dart), [backend turn service](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/onboarding/conversation/OnboardingConversationTurnServiceTest.java) | Pass automated |
| A9 One durable spoken phrase enables explicit completion | [repository integration](../../../mobile/test/features/care_entry/onboarding_conversation_repository_test.dart), [controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated |
| A10 Empty nickname displays `宝宝` | [surface widget/goldens](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated |
| A11 Nickname and age are not gates/inputs | [controller state](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [surface widget](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated |
| A12 `稍后再来` enters Today after durable checkpoint | [surface routing seam](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart), [repository restore](../../../mobile/test/features/care_entry/onboarding_conversation_repository_test.dart) | Pass automated; device defer/resume pending |
| A13 Banned learning/scoring/AI copy absent | [semantic copy firewall](../../../mobile/test/tool/verify_care_path_copy_firewall_test.dart) | Pass automated |
| A14 Missing mentor/sprout assets use text/initials, never PNG crops | [surface widget and six goldens](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart) | Pass automated; human visual review pending |
| A15 Guest identity/text/audio privacy and TTL | [backend conversation service](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/onboarding/conversation/OnboardingConversationServiceTest.java), [audio capability](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/onboarding/conversation/OnboardingAudioCapabilityServiceTest.java), final CI privacy gates | Pass automated |
| A16 Timeout is stable local content; late remote cannot replace it | [fake-time controller](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [registry fallback](../../../mobile/test/features/care_entry/care_entry_registry_test.dart) | Pass automated; E2E pending |
| A17 PhraseSaid creates at most one Garden Trace across retry/resume | [real file repository integration](../../../mobile/test/features/care_entry/onboarding_conversation_repository_test.dart), [controller retry/resume](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart) | Pass automated; device Garden pending |
| A18 Continue/Today/Garden preserve exact state without account | [controller handoffs](../../../mobile/test/features/care_entry/onboarding_conversation_controller_test.dart), [surface handoffs](../../../mobile/test/features/care_entry/care_entry_entry_surface_test.dart), [Android Today case](../../../mobile/integration_test/s06_full_chain_release_flow_test.dart) | Partial: Today passes device; Continue/Garden device E2E pending |

## End-to-end closure matrix

| Required scenario | Current highest evidence | Result |
| --- | --- | --- |
| Online generation | Controller + HTTP contract | **Pending device E2E** |
| Offline sticky fallback | Deterministic fake-time controller | **Pending device E2E** |
| Audio success and failure | API/output + widget cancellation tests | **Pending device E2E and human audibility** |
| No-reaction timeout | Fake-time controller + HTTP contract | **Pending device E2E** |
| Defer/resume | Durable repository/controller/widget seams | **Pending device E2E** |
| Continue | Controller/widget handoff | **Pending device E2E** |
| Today finish | Android fresh-install S06 | Pass device automation |
| Garden handoff | Repository/controller/widget seams | **Pending device E2E** |
| Human visuals and actual TalkBack | No human listener record | **Pending P1** |

## Exact automated gates

| Gate | Command | Result |
| --- | --- | --- |
| Spring AI 2 platform | `python3 tool/verify_spring_ai_2_backend_platform.py` | Pass in final full CI |
| Backend clean suite | `cd backend && bash mvnw clean test` | Pass: six reactor modules `SUCCESS`; app-api 1002 tests; `BUILD SUCCESS`; 04:27 |
| Mobile analysis | `cd mobile && flutter analyze` | Pass: `No issues found!` |
| Mobile full suite | `cd mobile && flutter test --concurrency=1` | Pass: 837 tests |
| Repository CI | `bash ci/full-ci.sh` | Pass on verified code SHA: backend, admin, mobile, format, R4, semantic/privacy, generated metadata, diff, and cleanliness gates |
| Android release/boot flow | `cd mobile && flutter test integration_test/s06_full_chain_release_flow_test.dart` | Pass: 2 tests on Android device/emulator |

## Android automated artifact evidence

- Source SHA: `146f2d1ac5ec9ed30fbc63b315323d4b52d67568`.
- Archived tested artifact: `artifacts/onboarding-v4/146f2d1ac5ec9ed30fbc63b315323d4b52d67568/app-debug.apk` (Git-ignored local release artifact; read-only).
- Size: `102291548` bytes.
- Build timestamp: `2026-08-15T00:27:35.2955837Z`.
- SHA-256: `D9A3295A5B5FBB17C3E7DE12E94C3E4E4390336F6042C4C4C43CC53B420A78B8`.
- Device run proved fresh V4 onboarding through one durable Today Care Turn and the malformed-snapshot boot failure surface.

This is automated device evidence. It does not prove visual quality, human audibility, TalkBack spoken order, touch exploration, or return focus.

## Release-pass remediations

- `116690d6`: inject Care Path dependencies into the Mentor widget harness.
- `594b31a0`: satisfy backend Checkstyle without behavior changes.
- `57f0d2f6`: format Care Entry provider wiring.
- `e6c87891`: remove font-license trailing whitespace caught by CI.
- `146f2d1a`: wait for Care Path's shared-Isar consumer before app-boot test teardown, removing repository-close races.

## Release decision

**NOT RELEASE READY.** #76 remains unresolved because required device E2E branches, manual Android visual review, and actual TalkBack spoken-order, touch-exploration, and return-focus evidence have not been performed. Widget semantics, Android hierarchy, and component/integration tests cannot substitute for those sessions. Do not close #76 or the parent rollout until every pending P1 row is recorded and reviewed.
