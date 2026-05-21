---
id: REFACTOR-009
title: Repository Usecase Contract Map And Account Adapter Seam
status: done
priority: high
phase: 2
assignee: AI
created: 2026-05-18
estimated: 1d
---

## Goal

Add the first repository/usecase seam for account presentation code without changing account behavior. The migrated seam must make `AccountNotifier` depend on an account repository contract instead of the concrete data repository class.

## Legacy Code Location

`mobile/lib/features/account/presentation/account_notifier.dart` currently imports the concrete `mobile/lib/features/account/data/repositories/account_repository.dart` implementation.

## Original Functionality Description

Account UI state is driven by `AccountNotifier`, which delegates snapshot loading, sign-in, runtime refresh, session clearing, consent revocation, and account deletion to `AccountRepository`. Tests frequently fake the repository by implementing the concrete class interface.

## Refactoring Approach

1. Add an account repository contract that captures the methods used by `AccountNotifier`.
2. Move the account runtime trigger wire contract next to the repository contract.
3. Make the concrete `AccountRepository` implement the contract and re-export it for compatibility.
4. Update `AccountNotifier` to depend on the contract, preserving all public behavior and constructor call sites.
5. Add a contract-only fake test proving `AccountNotifier` no longer requires the concrete repository type.

## Target Location

`mobile/lib/features/account/data/repositories/account_repository_contract.dart`, `mobile/lib/features/account/data/repositories/account_repository.dart`, `mobile/lib/features/account/presentation/account_notifier.dart`, and account presentation tests.

## Allowed Changes

- Add the account repository contract.
- Change `AccountNotifier` constructor type from concrete repository to contract.
- Keep existing concrete repository factories and Provider wiring intact.
- Add tests for the contract-only seam.
- Documentation artifacts describing the completed behavior.

## Forbidden Changes

- Changing account snapshot semantics or persistence format.
- Changing sign-in, refresh, revoke, delete, clear-session, upgrade-link, or lifecycle behavior.
- Moving `AccountLocalSnapshot` or other local persistence models in this task.
- Changing API request payloads, auth headers, or refresh/replay behavior.
- Migrating household, practice, mentor, or share repositories in this task.

## Acceptance Criteria

- [x] `AccountNotifier` imports and depends on an account repository contract, not the concrete data repository implementation.
- [x] The concrete `AccountRepository` implements the account repository contract.
- [x] Existing account, mentor, household, app composition, and full mobile tests remain green.
- [x] A contract-only fake can drive `AccountNotifier` without extending or implementing the concrete repository class.
- [x] Existing imports of `AccountRuntimeTrigger` from `account_repository.dart` remain compatible.

## Regression Test Requirements

- [x] Unit/widget test proving `AccountNotifier` works with a contract-only fake.
- [x] Existing account entry screen tests remain green.
- [x] Existing account repository tests remain green.
- [x] Full `flutter analyze`, `flutter test`, and `flutter test --coverage` remain green.

## Completion Evidence

- Added `AccountRepositoryContract` and moved `AccountRuntimeTrigger` wire values into the contract surface.
- Made the concrete `AccountRepository` implement the contract and re-export compatibility symbols.
- Updated `AccountNotifier` to accept `AccountRepositoryContract` while leaving existing factories and call sites unchanged.
- Added `account_repository_contract_test.dart` with a contract-only fake that drives reload, sign-in, and runtime refresh.
- Focused validation: `flutter analyze` pass; account contract, account entry, and mentor notifier tests pass.
- Full `flutter analyze`: pass, no issues found.
- Full `flutter test`: pass, 210 tests passed.
- Full `flutter test --coverage`: pass, 210 tests passed.
- Line coverage after REFACTOR-009: 66.26%.

## Initial Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Contract misses a method used by notifier | Low | Medium | Add focused contract-only notifier test and run analyze |
| Existing tests importing `AccountRuntimeTrigger` break | Medium | Medium | Re-export the trigger from the concrete repository compatibility surface |
| Domain purity is overstated while `AccountLocalSnapshot` remains under data/local | Medium | Low | Record this as a residual; do not move local persistence models in this task |
| Provider graph behavior changes | Low | High | Keep provider factories returning the concrete repository and only narrow notifier dependency type |

## Known Decisions

- Riverpod + GoRouter is the canonical app composition target.
- Repository/usecase seams must be introduced incrementally.
- Behavior changes require separate approval and tests.

## Authorizations

- AR-R3-008.

## Dependencies

- REFACTOR-004.