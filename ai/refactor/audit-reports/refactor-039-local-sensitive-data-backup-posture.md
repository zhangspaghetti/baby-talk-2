# REFACTOR-039 Local Sensitive Data Backup Posture Report

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Task: REFACTOR-039  
Created: 2026-05-20  
Status: complete; backup-exclusion posture implemented with target replay still pending

## Summary

REFACTOR-039 implements the current backup posture for local sensitive data: exclude local sensitive app data from OS backup/transfer surfaces rather than introducing an encryption migration in this task.

Android now disables app backup and declares root-level data extraction exclusions. iOS now exposes a method channel that marks the application support directory as excluded from backup. Dart startup wiring calls the protection helper where required and fails closed if native exclusion is not confirmed.

## Changes

| Area | Change |
|---|---|
| Android manifest | Added `allowBackup="false"`, `fullBackupContent="false"`, and `dataExtractionRules` |
| Android resource | Added `data_extraction_rules.xml` excluding root data from cloud backup and device transfer |
| iOS AppDelegate | Added `baby_talk/local_sensitive_data_backup` method channel and `excludeFromBackup` handler |
| Dart core | Added `LocalSensitiveDataBackupProtection` fail-closed helper |
| App directory wiring | Wrapped repository app directory resolution and session bootstrap directory setup with backup protection |
| Tests | Added Dart helper behavior tests and platform posture file tests |

## Sensitive Store Coverage

| Store Surface | Path Source | Posture |
|---|---|---|
| Onboarding snapshot JSON | Application support directory | Covered by Android backup opt-out and iOS support-directory exclusion |
| Household snapshot JSON | Application support directory | Covered by Android backup opt-out and iOS support-directory exclusion |
| Installation ID text file | Application support directory | Covered by Android backup opt-out and iOS support-directory exclusion |
| Practice interaction Isar store | Application support directory | Covered by Android backup opt-out and iOS support-directory exclusion |
| Mentor fact Isar store | Application support directory | Covered by Android backup opt-out and iOS support-directory exclusion |
| Account secure snapshot | `flutter_secure_storage` platform backend | Remains delegated to secure storage backend; lifecycle deletion covered by REFACTOR-038 |

## Verification

| Command | Exit | Result |
|---|---:|---|
| `flutter test test/core/local_data_lifecycle/local_sensitive_data_backup_protection_test.dart test/core/local_data_lifecycle/local_sensitive_data_backup_posture_test.dart` from `mobile/` | 0 | Pass; 5 tests |
| `flutter analyze` from `mobile/` | 0 | Pass; no issues found |
| `flutter test test/smoke/app_boot_test.dart` from `mobile/` | 0 | Pass; 7 tests |
| `flutter build apk --debug` from `mobile/` | 0 | Pass; manifest/resource integration accepted by Gradle |

## Remaining Gaps

| Gap | Required Evidence |
|---|---|
| iOS target build/replay | Build and run on the approved macOS/iOS target environment to prove the native method channel is registered and applied |
| Backup exclusion runtime observation | Capture target-platform evidence that the application support directory has the expected backup exclusion attribute |
| Encryption decision | If backup exclusion is deemed insufficient, open a separate key-management and migration task before adding encryption |
| Final R4 release approval | Complete target replay, lifecycle product-flow approval, performance full profile, policy gates, and final human sign-off |

## Risk Decision

The backup/encryption posture blocker is reduced from undocumented/open to an implemented backup-exclusion posture with local tests and Android build proof. Production readiness still requires iOS target evidence and the broader R4 gates.