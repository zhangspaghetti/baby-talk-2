# Refactor Task: REFACTOR-017A Integration Blocker Stabilization

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Created: 2026-05-19
Status: completed

## Objective

Investigate and remediate the integration blockers recorded by REFACTOR-017 without changing intended product behavior, deleting legacy code, or expanding the refactor blast radius beyond the failing mobile integration flows.

## Scope

- Restore S01 guest offline practice cold-start recovery evidence.
- Restore S02 fresh install onboarding to personalized shell and cold-start recovery evidence.
- Restore S03 offline practice, account sync, logout/login restore evidence.
- Restore S06 full-chain onboarding, malformed snapshot, Mentor blocked fallback, and Mentor timeout evidence.
- Keep app behavior aligned with current product contracts: fresh install routes to onboarding, the shell has a combined growth/garden tab, and online Mentor chat is gated by login plus accepted consent.

## Root Causes Addressed

| Area | Root Cause | Remediation |
|---|---|---|
| Session bootstrap | Integration apps did not provide the household repository now required by `SessionBootstrap` | Added shared local household repository helper and injected it in focused integration harnesses |
| Practice session | First route frame could read `AsyncLoading<PracticeRepository>()` through `requireValue` | Added loading/error handling around the Riverpod repository provider |
| Post-practice home state | Home continuity/garden projection did not synchronously refresh after practice pop | Refresh continuity and garden/growth state after practice returns |
| Celebration overlay | Confetti overlay could create unbounded paint/layout inside scrollables | Paint confetti within the child bounds using foreground `CustomPaint` |
| Account state bridge | Provider and Riverpod account paths could use different `AccountNotifier` instances | Share one `AccountNotifier` across legacy Provider and Riverpod overrides |
| Account notifier lifecycle | Shared Provider/Riverpod notifier ownership could trigger duplicate dispose during teardown | Make `AccountNotifier.dispose()` idempotent and keep one app-owned bridge instance |
| Mentor API path | Legacy Mentor notifier path could create an unauthenticated API service | Inject authenticated `MentorApiService` through Provider composition |
| S06 backend contract | Test backend rejected current `practice` Mentor surface | Allow `practice` surface and record backend diagnostics |
| Cross-test persistence | Mentor Isar default store name could collide across sequential harnesses | Added injectable Mentor store name and isolated S06 harness reads/writes |
| Harness assumptions | Tests expected stale shell tab/title/UI contracts and fragile scroll finders | Updated assertions to current UI contracts and hardened scroll helpers |

## Regression Evidence

| Command | Result |
|---|---|
| `..\flutter.cmd test integration_test/s01_guest_practice_flow_test.dart` | Passed; 1 test |
| `..\flutter.cmd test integration_test/s02_personalized_onboarding_flow_test.dart` | Passed; 1 test |
| `..\flutter.cmd test integration_test/s03_account_sync_restore_flow_test.dart` | Passed; 1 test |
| `..\flutter.cmd test integration_test/s06_full_chain_release_flow_test.dart` | Passed; 3 tests |
| `..\flutter.cmd analyze` | Passed; no issues found |

## Completion Decision

REFACTOR-017A completes the local integration blocker stabilization for the R1-documented core flows. This does not approve production readiness because coverage, critical UI coverage measurement, sensitive lifecycle completion, performance benchmarks, hard-gate escalation, and final human release approval remain open.

## Non-Goals Confirmed

- No fresh-install route behavior was changed to satisfy stale tests.
- No user-facing product copy or visual design values were intentionally changed.
- No generated output was moved or regenerated.
- No legacy file was deleted, moved, or archived.
- No production readiness or legacy deletion approval is granted by this task.

## Authorization

- Human selected investigation of the R017 integration failures after REFACTOR-018 and the REFACTOR-003 generated-code canary were complete.