# AsyncValue Pilot

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Task: REFACTOR-012  
Created: 2026-05-18  
Status: completed

## Target Rule

Migrated asynchronous presentation surfaces should expose their in-flight, data, and error state through `AsyncValue<T>` while preserving existing user-visible behavior during the legacy compatibility period.

## Pilot Surface

| Surface | Why This Is Low Risk |
|---|---|
| `ShareNotifier.shareCurrent()` | Small async UI command, no route changes, no auth changes, no persistence changes, focused unit coverage already exists for sharing, cancellation, and API failure |

## Pilot Shape

- Add a read-only `AsyncValue<ShareExecutionResult?>` request surface to `ShareNotifier`.
- Keep existing `isSharing`, `canShare`, `lastShareStatus`, `message`, and `lastSharePhase` getters available for current widgets and tests.
- Derive `isSharing` from the `AsyncValue` loading state.
- Preserve repository result mapping for success, cancellation, and handled API failures.
- Do not migrate app-wide ChangeNotifier providers in this task.

## Forbidden Changes

- Do not change share link payloads, share sheet launching, or API behavior.
- Do not modify routing, account, mentor, household, onboarding, or practice flows.
- Do not replace the existing `shareNotifierProvider` with `AsyncNotifier` yet.
- Do not convert other notifiers until this pilot is validated.

## Exit Signal

- Focused share notifier tests prove both legacy getters and `AsyncValue` loading/data states.
- Full mobile analyze, test, and coverage gates remain green.