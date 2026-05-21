# Phase 2 Plan - Core Architecture Safety

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 Planning  
Created: 2026-05-18  
Status: draft

## Goal

Establish the target architecture one seam at a time: Riverpod + GoRouter composition, one authenticated client, fail-closed consent gates, repository/usecase abstractions, feature boundary contracts, local sensitive data lifecycle, and an AsyncValue pilot.

## Duration

Estimated 2-3 weeks.

## Workstreams

| Workstream | Output | Exit Signal |
|---|---|---|
| App composition | Provider compatibility matrix and Riverpod migration map | App boot tests pass before and after each change |
| Router | Route contract inventory and GoRouter canonical plan | Route paths, extras, redirects, onboarding, reentry are tested |
| Auth | Single Bearer JWT authenticated client/interceptor | Protected API tests prove `Authorization: Bearer` injection |
| Consent | Mentor/AI fail-closed gate | Tests prove no network call before login + consent |
| Sensitive local data | Classification and lifecycle plan | Delete/encrypt/backup rules documented before storage changes |
| Repository/usecase | Interface map and adapter seams | UI no longer depends on concrete data repositories in migrated seams |
| Feature boundaries | Matrix and report-only scan | Old violations tracked; no new cross-feature internals |
| Async state | Low-risk AsyncValue pilot | One small state surface migrates without behavior change |

## Entry Criteria

- Phase 1 baselines and characterization tests exist.
- Generated-code canary result is known.
- First task allowed files are approved.

## Exit Criteria

- Core architecture decisions are represented as artifacts and tests.
- Account, practice, mentor, household, and share have repository/usecase target contracts.
- Auth and consent paths have fail-closed tests.
- High-risk files are not split until their characterization tests pass.

## Blocked Until Tests Exist

- Deleting old Provider or old router surfaces.
- Splitting `practice_repository.dart`.
- Changing mentor network behavior.
- Migrating local sensitive data persistence.
- Enforcing all legacy import violations as hard CI failures.