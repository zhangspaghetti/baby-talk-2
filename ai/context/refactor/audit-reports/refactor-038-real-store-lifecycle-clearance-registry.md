# REFACTOR-038 Real-Store Lifecycle Clearance Registry Report

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Task: REFACTOR-038  
Created: 2026-05-20  
Status: complete; real-store lifecycle registry verified but not product-flow wired

## Summary

REFACTOR-038 adds an app-layer registry that connects the existing governance orchestrator to real local deletion primitives for all six sensitive local-data targets. The registry remains intentionally unwired from destructive user flows until separate Staff+/human approval exists.

Focused tests prove registration coverage, governance rejection without Staff+ authorization, and real temp-store clearance with Staff+ authorization.

## Changes

| Area | Change |
|---|---|
| Account repository | Added `deleteLocalSnapshotForLifecycle()` wrapper around the account local store delete primitive |
| Household repository | Added `deleteLocalSnapshotForLifecycle()` wrapper around the household local store delete primitive |
| Practice repository | Added `deleteInstallationIdForLifecycle()` wrapper around `InstallationIdService.deleteIfExists()` |
| App registry | Added `createLocalSensitiveDataClearanceOrchestrator()` and `createLocalSensitiveDataClearanceSteps()` |
| Tests | Added temp-store lifecycle registry tests for target coverage, governance rejection, and Staff+ clearance |
| Test doubles | Updated repository test doubles to satisfy the new public lifecycle methods |

## Registry Coverage

| Target | Registered Primitive |
|---|---|
| `accountLocalSnapshot` | `AccountRepository.deleteLocalSnapshotForLifecycle` |
| `onboardingSnapshot` | `OnboardingRepository.clearSnapshot` |
| `householdSnapshot` | `HouseholdRepository.deleteLocalSnapshotForLifecycle` |
| `practiceInteractionEvents` | `PracticeRepository.close(deleteFromDisk: true)` |
| `mentorFactEvents` | `MentorRepository.close(deleteFromDisk: true)` |
| `installationId` | `PracticeRepository.deleteInstallationIdForLifecycle` |

## Verification

| Command | Exit | Result |
|---|---:|---|
| `flutter test test/app/local_sensitive_data_clearance_registry_test.dart` from `mobile/` | 0 | Pass; 3 tests |
| `flutter analyze` from `mobile/` | 0 | Pass; no issues found |
| `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart test/app/local_sensitive_data_clearance_registry_test.dart` from `mobile/` | 0 | Pass; 6 tests |

## Safety Boundary

This task deliberately does not wire the registry into `BabyTalkApp`, logout, account deletion, consent withdrawal, device erase, or UI triggers. The only destructive execution path exercised here runs against isolated temporary test directories and in-memory secure storage.

## Remaining Lifecycle Gaps

| Gap | Required Evidence |
|---|---|
| Product-flow wiring approval | Explicit Staff+/human approval artifact for logout/session-only, consent withdrawal, account deletion, and device erase integration |
| Real-flow end-to-end tests | Focused app/repository tests proving approved user flows call the registry and report outcomes |
| Backup/encryption posture | Evidence that JSON and Isar stores are excluded from backup or protected by the approved encryption strategy |
| Target replay | Lifecycle evidence replayed in approved CI or target-platform environment |
| Release approval | Final human sign-off before production readiness is claimed |

## Risk Decision

The R4 lifecycle gate is materially stronger because every known sensitive target now has an app-layer registered delete path and temp-store proof. Production lifecycle readiness remains open until destructive product-flow wiring and backup/encryption decisions are approved and verified.