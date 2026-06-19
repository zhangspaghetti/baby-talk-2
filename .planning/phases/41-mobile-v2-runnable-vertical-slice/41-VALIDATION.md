---
phase: 41
slug: mobile-v2-runnable-vertical-slice
status: draft
nyquist_compliant: true
wave_0_plan_ready: true
updated: 2026-06-19
---

# Phase 41 - Validation Strategy

Validation follows `41-INTERACTION-ENGINE-CONTRACT.md` and the two locked implementation authorities:

- `docs/superpowers/plans/2026-06-19-interaction-engine-v1.md`
- `docs/superpowers/plans/2026-06-19-interaction-engine-flutter-riverpod.md`

Historical four-screen, flattened snapshot, stateless reaction lookup, plain-controller, and no-Riverpod guidance is superseded. D.4.5 geometry and both approved static-asset gates remain mandatory.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | `flutter_test`, pure-Dart domain tests through Flutter runner, `ProviderContainer.test`, repo verifier CLIs |
| Package order | Plan 41-01 installs only `crypto:^3.0.7`; Plan 41-08 later installs `flutter_riverpod:^3.3.0`, updates its lockfile state, records Riverpod-specific coding standards, and proves the smoke test |
| Focused command form | Direct current-PowerShell script: `Push-Location mobile_v2; try { flutter test <paths>; if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE } } finally { Pop-Location }` |
| RED evidence form | `Start-Process flutter ... -RedirectStandardOutput/-RedirectStandardError`; require non-zero test exit, require named missing production symbol, then return exit 0 |
| Negative source gate form | PowerShell `Select-String`; if matches exist, print them and `throw`; absence returns exit 0 |
| Final command | format, analyze, full test, semantic firewall, Activation Governor verifier in one fail-fast PowerShell block |
| Fallback | Direct Flutter/Dart SDK commands recorded by Plan 41-01 in `41-COMMAND-HEALTH.md` |

## Plan and Wave Map

| Wave | Plans | Dependency reason |
|---|---|---|
| 0 | 41-01 | Approved assets, crypto-only core dependency, command health, models |
| 1 | 41-02, 41-03, 41-05, 41-06 | Independent pure modules, runtime primitives, content adapter, wire mapper after models |
| 2 | 41-04 | Requires modules and runtime primitives |
| 3 | 41-07 | Requires authority port and wire mapper |
| 4 | 41-08 | Requires authority, content, and interaction adapters; first installs/smoke-tests Riverpod |
| 5 | 41-09 | Requires read-only provider graph |
| 6 | 41-10 | Requires whole-snapshot state and capability mask |
| 7 | 41-11 | Requires authority, adapters, session, and widgets |

Same-wave plans have no `files_modified` overlap. Plans 41-01 and 41-08 intentionally modify `pubspec.yaml`/`pubspec.lock` in serial order; Riverpod-specific `CODING_STANDARDS.md` decisions belong to 41-08.

## Required Test Layers

1. Immutable models: five InputEvent variants, ProductSnapshot, schemaVersion/revision, AdvanceResult.
2. Four pure modules: NormalizeEngine, StateAccumulator, StrategyEngine, UtteranceEngine.
3. Runtime substrate: fingerprint, ConsistencyState, ReplayJournal evidence, direct replay, serialized store.
4. Authority: initialize/advance, conflict order, atomicity, one clock read, concurrency, raw non-retention.
5. Content adapter: fixture/DTO/mapper/API/repository ownership and R058-R065 evidence.
6. Interaction wire: five DTO variants, schema compatibility, ProductSnapshot-only responses.
7. Interaction adapter: thin port delegation, repository conversion, direct-engine parity.
8. Provider graph: identity, overrides, app/providers-only Riverpod, input factory, mask isolation.
9. Session: sole Notifier, whole-snapshot state, lifecycle/conflict/stale-operation behavior.
10. Widgets/app: D.4.5 projection, submitting preservation, payload substitution, retry, accessibility, full engine contract.

## Per-Task Verification Map

| Task ID | Plan/Wave | Requirements | RED evidence / automated gate | Required proof |
|---|---|---|---|---|
| 41-01-01 | 01 / W0 | R058,R059,R060,R067 | `Test-Path` both approved artifacts; crypto-only pubspec assertion; `flutter pub get`; command-health content assertions | D.4.5/static gates, audited crypto only, both asset directories, no Riverpod expectation |
| 41-01-02 | 01 / W0 | R058,R059,R060,R067 | captured focused model test must fail and name `InputEvent|ProductSnapshot|AdvanceResult` | five variants, schema/revision split, immutable truth shape |
| 41-01-03 | 01 / W0 | R058,R059,R060,R067 | focused model test + domain-model analyze + negative framework/raw scan | ProductSnapshot product truth only |
| 41-02-01 | 02 / W1 | R058,R059,R060,R067 | captured four-module tests must fail and name a module symbol | cross-modal equivalence, decay reversal, strategy/utterance separation |
| 41-02-02 | 02 / W1 | R058,R059,R060,R067 | four focused module tests + analyze + negative responsibility/vocabulary scan | four pure stateless modules |
| 41-03-01 | 03 / W1 | R060,R067 | captured runtime tests must fail and name fingerprint/consistency/journal/store symbol | receipt fields, evidence-only journal, direct replay, serialization |
| 41-03-02 | 03 / W1 | R060,R067 | focused runtime tests + analyze + negative raw/framework/module scan | ProductSnapshot+Consistency truth; ReplayJournal evidence only |
| 41-04-01 | 04 / W2 | R060,R067 | captured authority tests must fail and name `InteractionEngine|InteractionEnginePort` | conflict order, concurrency, atomicity, one clock read, replay integration |
| 41-04-02 | 04 / W2 | R060,R067 | complete engine/runtime tests + domain analyze + public-port/framework scans | sole authority and no partial mutation |
| 41-05-01 | 05 / W1 | all | captured content tests must fail and name content API/model/repository symbol | D.4.5 content ownership; explicit R058-R067 trace |
| 41-05-02 | 05 / W1 | all | content tests + both verifiers + negative content-authority scan | separate stable content bootstrap; no Garden/activation authority |
| 41-06-01 | 06 / W1 | R060,R067 | captured mapper test must fail and name DTO/mapper symbol | five wire variants, schema/privacy contract |
| 41-06-02 | 06 / W1 | R060,R067 | mapper test + DTO/mapper analyze + internal-field scan | strict ProductSnapshot-only transport |
| 41-07-01 | 07 / W3 | R060,R067 | captured adapter tests must fail and name API/repository symbol | one delegation, no initialize, all result codes, parity |
| 41-07-02 | 07 / W3 | R060,R067 | full data tests + both verifiers + negative policy/authority scan | thin API/repository over InteractionEnginePort |
| 41-08-01 | 08 / W4 | R060,R067 | install exact Riverpod dependency; update lock/standards; `flutter pub get`; Riverpod smoke passes; captured provider tests fail and name provider/input/mask symbol | dependency order, smoke, provider identity/overrides, five-channel factory, mask isolation |
| 41-08-02 | 08 / W4 | R060,R067 | provider suites + Riverpod/import/mask dependency scans | app/providers-only read-only graph |
| 41-09-01 | 09 / W5 | R060,R067 | captured session tests fail and name state/Notifier symbol | whole-snapshot state, all result transitions, stale/disposal safety |
| 41-09-02 | 09 / W5 | R060,R067 | session/state tests + exact one-Notifier count + forbidden-field scan | sole mutable Notifier; raw input not stored |
| 41-10-01 | 10 / W6 | all | repeat both `Test-Path` assertions; captured widget test fails on named widget symbol | approved D.4.5/static gate; payload/layout/accessibility contract |
| 41-10-02 | 10 / W6 | all | widget suite + both verifiers + negative import/semantic scan | reaction-only projection; no hidden controls or pressure semantics |
| 41-11-01 | 11 / W7 | all | captured engine/screen/accessibility command fails specifically on `BabyTalkApp|RitualRoomScreen` | full engine + UI integration contract |
| 41-11-02 | 11 / W7 | all | focused engine/screen/accessibility tests + one-ProviderScope/feature-import scans | runnable direct Ritual Room Support |
| 41-11-03 | 11 / W7 | all | fail-fast format/analyze/full-test/verifier block + `Test-Path` for `41-RIVERPOD-MAPPING.md` + exact ENGINE/RIVERPOD/RUNNABLE proof-content assertions | ENGINE/RIVERPOD/RUNNABLE proofs; complete read-only graph marker; exact `RitualRoomSession NotifierProvider` mutable-node marker; exact only-mutable-node marker; explicit seven-requirement trace |

`all` means R058, R059, R060, R063, R064, R065, and R067. This manual map is the authoritative trace; planning must not rely on built-in gap-analysis parsing of the `R058` requirement format.

## Canonical Focused Commands

```powershell
function Invoke-MobileV2FlutterTest {
  param([Parameter(Mandatory)][string[]]$Paths)
  Push-Location mobile_v2
  try {
    flutter test @Paths
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  } finally {
    Pop-Location
  }
}

Invoke-MobileV2FlutterTest @('test/features/ritual_room/domain/models/interaction_contract_test.dart')
Invoke-MobileV2FlutterTest @('test/features/ritual_room/domain/engine/normalize_engine_test.dart','test/features/ritual_room/domain/engine/state_accumulator_test.dart','test/features/ritual_room/domain/engine/strategy_engine_test.dart','test/features/ritual_room/domain/engine/utterance_engine_test.dart')
Invoke-MobileV2FlutterTest @('test/features/ritual_room/domain/runtime/input_fingerprint_test.dart','test/features/ritual_room/domain/runtime/interaction_runtime_test.dart')
Invoke-MobileV2FlutterTest @('test/features/ritual_room/domain/engine/interaction_engine_test.dart','test/features/ritual_room/domain/engine/interaction_engine_atomicity_test.dart','test/features/ritual_room/domain/engine/interaction_engine_replay_test.dart')
Invoke-MobileV2FlutterTest @('test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart','test/features/ritual_room/data/datasources/mock_ritual_content_api_test.dart','test/features/ritual_room/data/repositories/ritual_room_repository_test.dart')
Invoke-MobileV2FlutterTest @('test/features/ritual_room/data/mappers/interaction_mapper_test.dart')
Invoke-MobileV2FlutterTest @('test/features/ritual_room/data/datasources/mock_interaction_api_test.dart','test/features/ritual_room/data/repositories/interaction_repository_test.dart')
Invoke-MobileV2FlutterTest @('test/app/providers/riverpod_smoke_test.dart','test/app/providers/interaction_engine_providers_test.dart','test/app/providers/ritual_room_data_providers_test.dart','test/app/providers/ritual_room_capability_provider_test.dart','test/app/providers/interaction_provider_contract_test.dart')
Invoke-MobileV2FlutterTest @('test/app/providers/ritual_room_session_provider_test.dart','test/features/ritual_room/presentation/state/ritual_room_ui_state_test.dart')
Invoke-MobileV2FlutterTest @('test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart')
Invoke-MobileV2FlutterTest @('test/features/ritual_room/interaction_engine_contract_test.dart','test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart','test/features/ritual_room/presentation/ritual_room_accessibility_test.dart')
```

Each PLAN wraps these commands with `$LASTEXITCODE` handling. RED tasks use the captured-output `Start-Process` form specified in the table, not these normal GREEN commands.

## Critical Assertions

### Authority and runtime

- `InteractionEngine` alone implements initialize/advance authority.
- `InteractionEnginePort` exposes getSnapshot/advance but not initialize.
- ProductSnapshot + ConsistencyState is current runtime truth.
- ReplayJournal is evidence only and never read by current strategy/state decisions.
- duplicate_ignored precedes expectedRevision and returns the latest snapshot.
- event_id_conflict, revision_conflict, interaction_not_found, and pipeline_failed do not mutate state.
- accepted events increment revision once and commit snapshot/receipt/record together.
- one injected-clock value supplies ProductSnapshot.updatedAt and TransitionRecord.occurredAt.
- replay applies TransitionRecord values directly and leaves module/clock/ID call counts unchanged.

### Privacy

The full runtime dump after voice/free-text events must not contain raw transcript, raw free text, raw payload, or audio. Receipts contain only eventId, canonical fingerprint, and appliedRevision. TransitionRecord contains only normalized/derived outputs.

### Flutter/Riverpod

- Riverpod production imports are limited to `app/providers/` and app bootstrap.
- Exactly one Ritual Room `NotifierProvider` exists.
- UI state stores whole room/snapshot plus transient state, with no duplicate product fields or InputEvent.
- CapabilityMask is reaction-only and absent from engine/API/repository dependency graphs.
- Feature widgets/screens import no DTO, mapper, mock source, concrete repository, or provider.

### D.4.5 UI and scope

- Both approved artifact paths are hard-asserted in 41-01 and again in 41-10.
- Direct Ritual Room Support only; stable identity, one utterance, one action cue, one listen affordance, reaction tray/sheet, preserved submitting state, in-place revision, reassurance, and quiet exit.
- No microphone, visible free text, future-signal control, strategy tray, progress, score, task, child-performance, Garden-growth, Spring backend, real LLM, persistence, or production Garden transition.

## Requirement Trace

| Requirement | Mechanical evidence |
|---|---|
| R058 | Content/widget forbidden-semantics tests, semantic firewall, runnable proof row |
| R059 | Stable ritual content/model and no progression/phrase-list UI tests |
| R060 | Normalize/state tests, non-diagnostic scans, whole-snapshot/provider boundaries |
| R063 | Fake allow_activation content evidence plus Phase 40 verifier |
| R064 | No production Garden/scoring state plus Phase 40 verifier |
| R065 | No Explore-to-Activate/action-now expansion plus Phase 40 verifier |
| R067 | Five model/DTO/factory/repository channels, mixed revision 0-to-5 engine test, reaction-only mask isolation |

## Final Gate

```powershell
Push-Location mobile_v2
try {
  dart format --output=none --set-exit-if-changed .
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  flutter analyze
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  flutter test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  dart run ../tool/verify_mobile_v2_semantic_firewall.dart
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  dart run ../tool/verify_activation_governor_contract.dart
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}
```

## Manual Verification

Compare the 390x844 runtime screen to `.planning/phases/41-mobile-v2-runnable-vertical-slice/assets/prototypes/phase41-d4-5-interaction-engine.png`; confirm approved illustration, stable hierarchy, warm low-pressure parent tone, and absence of hidden-channel controls. Automated checks remain required and cannot be replaced by this visual review.

## Sign-Off

- [x] Every task has `<read_first>`, `<acceptance_criteria>`, `<verify><automated>`, and `<done>`.
- [x] Every RED gate captures output, asserts a named missing production symbol, and returns success only when expected RED is proven.
- [x] Every negative source gate throws on forbidden matches.
- [x] Every requirement has explicit manual trace independent of gap-analysis parsing.
- [x] Plan IDs, waves, focused commands, and final commands match the 11 PLAN files.
- [ ] Execution results recorded.

**Approval:** planning revision complete; execution pending.
