# REFACTOR-039 Local Sensitive Data Backup Posture

---
id: REFACTOR-039
title: Local sensitive data backup posture
status: done
priority: high
phase: 4
assignee: AI
created: 2026-05-20
estimated: 0.5 day
---

## Goal

Reduce the R4 backup/encryption blocker by implementing an explicit backup-exclusion posture for local sensitive data directories and adding focused verification for the Android and iOS posture surfaces.

## Target Locations

- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/android/app/src/main/res/xml/data_extraction_rules.xml`
- `mobile/ios/Runner/AppDelegate.swift`
- `mobile/lib/core/local_data_lifecycle/local_sensitive_data_backup_protection.dart`
- `mobile/lib/app/providers/repository_providers.dart`
- `mobile/lib/app/session_bootstrap.dart`
- `mobile/test/core/local_data_lifecycle/local_sensitive_data_backup_protection_test.dart`
- `mobile/test/core/local_data_lifecycle/local_sensitive_data_backup_posture_test.dart`
- R4 task index, timeline, and readiness reports

## Approach

1. Treat backup exclusion as the approved current posture for local sensitive JSON, installation ID, and Isar stores; no encryption migration is introduced in this task.
2. Disable Android backup and data extraction for the app with manifest attributes plus a root-level extraction exclusion resource.
3. Add an iOS native method channel that sets `isExcludedFromBackup` on the application support directory.
4. Wire app directory resolution through a fail-closed Dart helper on platforms that require native backup exclusion.
5. Add focused tests for Dart fail-closed behavior and static platform posture evidence.

## Allowed Changes

- Add platform backup exclusion configuration.
- Add a small Dart helper for backup protection wiring.
- Add a narrow iOS method channel for backup exclusion.
- Add focused tests and update R4 reports.

## Forbidden Changes

- Do not migrate storage format or persisted schema.
- Do not add encryption without a separate migration and key-management decision.
- Do not weaken lifecycle deletion or Staff+ governance requirements.
- Do not claim iOS target readiness without a target build/replay artifact.

## Acceptance Criteria

- [x] Android app backup and Android 12 data extraction are explicitly disabled/excluded.
- [x] iOS app support directory backup exclusion path exists through a native method channel.
- [x] Dart startup wiring fails closed when a platform requires native exclusion and the native call is not confirmed.
- [x] Focused tests cover backup-protection behavior and platform posture files.
- [x] Android debug build validates manifest/resource integration.
- [x] Reports distinguish local code/config evidence from iOS target build/replay evidence.

## Verification Evidence

| Command | Exit | Result |
|---|---:|---|
| `flutter test test/core/local_data_lifecycle/local_sensitive_data_backup_protection_test.dart test/core/local_data_lifecycle/local_sensitive_data_backup_posture_test.dart` from `mobile/` | 0 | Pass; 5 tests |
| `flutter analyze` from `mobile/` | 0 | Pass; no issues found |
| `flutter test test/smoke/app_boot_test.dart` from `mobile/` | 0 | Pass; 7 tests |
| `flutter build apk --debug` from `mobile/` | 0 | Pass; built `build/app/outputs/flutter-apk/app-debug.apk` |

## Backup Posture Decision

The current R4 posture is backup exclusion, not at-rest encryption. Android backup and device-transfer extraction are disabled for the app. iOS now has runtime exclusion wiring for the application support directory used by sensitive local stores. Production readiness still needs iOS target build/replay and the broader R4 target-platform replay/final approval gates.