# Phase 41 Interaction Engine Proof

## Verified command evidence

Executed from `C:\code\AI\baby-talk-2` on 2026-06-21:

```powershell
Push-Location mobile_v2
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub
Pop-Location
dart run tool/verify_mobile_v2_semantic_firewall.dart
dart run tool/verify_activation_governor_contract.dart
```

Results:

- Format: pass, 88 files checked, 0 changed.
- Analyze: pass, no issues.
- Flutter tests: pass, 113/113.
- Semantic firewall: pass, 59 runtime files, 0 violations.
- Activation Governor contract: pass, 5 cases, 0 violations.

## Authority and version proof

- `InteractionEngine` is the sole lifecycle, revision, idempotency, conflict,
  pipeline, clock, atomic-commit, and replay-evidence authority.
- Runtime truth is `ProductSnapshot + ConsistencyState`; `ReplayJournal` is
  evidence only.
- Initialization creates schema version 1 at revision 0. Five accepted typed
  channels advance one interaction monotonically through revision 5.
- The full contract executes reaction selection, voice observation, free text,
  future signal, and strategy preference as one mixed-channel evolution.
- Every accepted event commits one snapshot, one receipt, and one transition.
  The transition uses one-clock-read for snapshot and journal timestamps.

## Result and failure proof

- `duplicate_ignored`: delayed retry of event 1 returns the latest revision 5
  snapshot without pipeline or clock work.
- `event_id_conflict`: changed content under an existing event ID is rejected
  with the latest snapshot.
- `revision_conflict`: an unseen stale-revision event is rejected with the
  latest snapshot.
- `interaction_not_found`: unknown interaction IDs are rejected without
  initialization or pipeline work.
- `pipeline_failed`: pipeline failure leaves revision, receipts, journal, and
  transition clock unchanged, proving atomic failure.

## Privacy, replay, and adapter proof

- raw-input non-retention: raw voice and free-text sentinels are absent from the
  complete runtime JSON after successful execution.
- direct replay: recorded derived outputs reproduce the revision 5 snapshot
  from revision 0 without rerunning modules, clock, or ID generation.
- adapter parity: direct `InteractionEngine` and
  `MockInteractionApi -> InteractionRepositoryImpl` execution produce equal
  product semantics for all five channels.

## Replacement invariants

Phase 42 may add presentation/input adapters only. Future Spring transport or
LLM-backed module implementations remain replaceable consumers behind the same
schema, lifecycle, conflict, privacy, and snapshot contract. They may not own
revision, commit product state, bypass the engine, or introduce a second
authority. No Phase 42 controls, Spring endpoint, real LLM, persistence, or
production Garden transition was implemented in Phase 41.
