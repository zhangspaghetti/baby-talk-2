# Local Sensitive Data Lifecycle

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Task: REFACTOR-013  
Created: 2026-05-18  
Status: approved

## Decision

Child profile data, household context, practice events, mentor facts, account session material, and installation identifiers are sensitive local data. They must have explicit storage, backup, deletion, and consent lifecycle rules before storage migration work begins.

This document is a planning baseline. It does not approve a storage migration, destructive local data deletion, or hard CI enforcement in REFACTOR-013.

## Lifecycle Rules

| Trigger | Required Behavior |
|---|---|
| Logout / clear session | Delete account session and challenge material, reset downstream in-memory view models, and keep any retained child/practice data local-only with network calls blocked until accepted consent exists again. |
| Consent withdrawal | Stop protected network calls, clear or invalidate account session material, clear shared household/network continuity context, and keep any retained child/practice data local-only until a separately confirmed erase-device-data flow exists. |
| Account deletion | Delete or make inaccessible all account session material and schedule all child, household, practice, mentor, and installation-id local stores for device erasure. |
| Fresh install / local-only | Do not send installation ID, child profile, practice events, mentor facts, or household context over the network before accepted consent. |
| Backup / restore | File and Isar stores must be excluded from platform backup where possible or migrated to encrypted storage before backup is allowed. |

## Surface Matrix

| Surface ID | Data | Classification | Current Storage | Current Delete Primitive | Target Protection | REFACTOR-013 Status |
|---|---|---|---|---|---|---|
| account_local_snapshot | Consent state, session tokens, masked phone, challenge metadata, sync counters | sensitive_account_auth | `FlutterSecureStorage` key `account_state` | `AccountLocalStore.deleteIfExists()` | Keep in secure storage; clear session/challenge on logout, revoke, and account delete | covered_delete_primitive |
| onboarding_snapshot | Child display name, approximate age/month bucket, birth date, starter stage/activity/phrase | sensitive_child_profile | App support JSON file `onboarding_snapshot.json` | `OnboardingSnapshotStore.deleteIfExists()` | Migrate to encrypted local storage or protect with platform backup exclusion before enforcement | covered_delete_primitive |
| household_snapshot | Household ID, caregiver role, shared baby/practice/garden context | sensitive_household_context | App support JSON file `household_state.json` | `HouseholdLocalStore.deleteIfExists()` | Delete on consent withdrawal/account delete; migrate to encrypted storage or backup exclusion | covered_delete_primitive |
| practice_interaction_events | Installation-bound practice reactions, phrase/activity IDs, sync state/errors | sensitive_child_behavior_history | Isar database `practice_local` | `PracticeLocalDataSource.close(deleteFromDisk: true)` / `PracticeRepository.close(deleteFromDisk: true)` | Add lifecycle contract before account feature coordinates deletion; exclude from backup or encrypt | covered_delete_primitive |
| mentor_fact_events | Redacted mentor facts, visible statuses, fallback diagnostics, installation ID | sensitive_mentor_context | Isar database `mentor_local` | `MentorLocalDataSource.close(deleteFromDisk: true)` | Delete on consent withdrawal/account delete; exclude from backup or encrypt | covered_delete_primitive |
| installation_id | Stable installation identifier | sensitive_persistent_identifier | App support text file `installation_id.txt` | missing | Add reset/delete primitive before hard lifecycle enforcement; never send before accepted consent | missing_delete_primitive |

## Enforcement Plan

1. Keep REFACTOR-013 report-only until all storage surfaces have an explicit delete primitive and tests.
2. Add a lifecycle service/usecase before wiring account deletion to destructive child/practice/mentor deletion.
3. Add platform backup exclusion or encrypted storage migration for JSON/Isar stores before hard enforcement.
4. Add UX confirmation before destructive device erasure of local child/practice history.
5. Convert the report-only scan into a hard gate only after migration tests prove account delete and consent withdrawal clear every target store.

## Current Known Gaps

- `InstallationIdService` can create and read the stable identifier, but it has no delete/reset primitive yet.
- Account revoke and delete paths update account state, but there is not yet a single lifecycle service that clears onboarding, household, practice, mentor, and installation-id stores together.
- File and Isar stores do not yet prove platform backup exclusion or encryption.