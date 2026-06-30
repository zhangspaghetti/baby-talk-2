# T1 Reaction Clean Cutover Implementation Plan

Date: 2026-06-30
Status: Ready for implementation
Source ADR: `docs/adr/ADR-0001-reaction-contract-clean-cutover.md`
Scope: contract/data/backend cutover only. No new UI screens, layouts, or visual work.

## Goal

Cut the reaction contract over to the ADR-0001 five-value vocabulary everywhere that writes, parses, syncs, validates, stores, or branches on reaction wire values.

Canonical values:

```text
cooperating / hesitant / resisting / no_response / other
```

Old values to remove from the formal runtime contract:

```text
calm / engaged / imitated / needs_break
```

Allowed one-time dev/test migration:

```text
calm / engaged / imitated -> cooperating
needs_break               -> resisting
```

`other` means the user explicitly selected "其他". It is not an invalid-value fallback.

## Step 0 Scope Challenge

### What already exists

- `mobile_v2/lib/features/ritual_room/domain/models/input_event.dart` already has `ReactionSelectionPayload.selected`; reuse it instead of adding a parallel reaction event type.
- `mobile_v2/lib/app/input/interaction_input_factory.dart` is already the single event minting point for UI reactions; keep it as the admission boundary.
- `mobile_v2/lib/features/ritual_room/data/mappers/interaction_mapper.dart` and `InteractionInputDto.fromJson` already form strict transport parsing boundaries; add reaction-value validation there.
- `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json` already drives submitted choice IDs through existing widgets; change IDs and fixture tests, not widgets.
- `mobile/lib/features/practice/domain/models/interaction_event_payload.dart` still owns the local sync queue reaction enum for the legacy/mobile sync path; cut it over if that package remains in test/build gates.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java:27` already centralizes backend allowed reaction values.
- `backend/db-migration/src/main/resources/db/migration/V3__create_accounts_and_sync_tables.sql:62` created the original check constraint; add a new Flyway migration rather than editing history.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GrowthSummaryService.java:42` and `GrowthInsightsService.java:79` branch on `imitated`; they must stop treating old values as semantic truth.

### Minimum complete change

1. Add a tiny canonical reaction contract in mobile_v2 domain code and use it from event creation, DTO parsing, and tests.
2. Replace mobile_v2 fixture choice IDs with the five ADR canonical values, leaving widget structure untouched.
3. Teach `RuleBasedNormalizeEngine` the five new values and reject old values before normalization.
4. Cut over the legacy `mobile/` sync enum/parser/upload record if that tree still participates in CI or app packaging.
5. Update backend allowed values and add a V23 Flyway migration that migrates dev/test rows, drops the old check, and adds the new check.
6. Remove old-value branches from backend growth/garden/household/mentor consumers or mark old semantic metrics deprecated without mapping new values back to old meanings.
7. Add strict invalid-value tests on mobile, backend web/API, and DB migration boundaries.
8. Run focused Flutter, backend, and source-scan verification before Today/Scene/One-utterance work resumes.

### Complexity check

This exceeds 8 files if done completely. That is expected because ADR-0001 deliberately rejects dual-accept compatibility. Reducing this to only mobile_v2 would leave backend and sync queues accepting or storing old values, which violates the ADR. The right control is slicing, not scope reduction.

### Search check

No new framework, SDK, infrastructure component, or concurrency pattern is introduced. The plan uses existing Dart models/parsers, existing Riverpod submission flow, existing Spring service validation, and existing Flyway migrations. No external search is needed for a new technology choice.

### TODOS cross-reference

`TODOS.md` contains old reaction-related legacy tasks and metrics, but no item blocks this cutover. The only follow-up candidate is a separate product analytics decision for what replaces `imitationCount`; T1 should not invent that metric.

## Architecture Review

### Finding 1

`[P1] (confidence: 9/10) mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json:42 - fixture choice IDs are content-specific values like not_ready_yet/wants_independence, and RitualRoomSessionNotifier submits choice.id directly.`

Recommendation: make the stable content IDs the ADR canonical wire values. This is the smallest change that makes the existing UI submit clean values without adding a mapper layer in the widget path.

```text
RitualRoom fixture
  reaction_choices[].id = canonical wire value
        |
        v
RitualRoomScreen existing onReactionSelected(choice.id)
        |
        v
RitualRoomSessionNotifier.submitReaction(selected)
        |
        v
InteractionInputFactory.reaction(selected)
        |
        v
InputEvent.reactionSelection(selected: canonical)
```

Do not add a UI-specific translation table. It creates a second reaction contract and makes future tests ask whether `choice.id`, `selectedReaction`, or payload selected is authoritative.

### Finding 2

`[P1] (confidence: 9/10) backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncService.java:27 - backend validation still accepts only calm/engaged/imitated/needs_break.`

Recommendation: update the set in the same implementation slice as the DB migration. Backend accepting old values after the DB changes would move failures from service validation to SQL constraint exceptions and weaken error quality.

### Finding 3

`[P1] (confidence: 9/10) backend/db-migration/src/main/resources/db/migration/V3__create_accounts_and_sync_tables.sql:62 - the persisted check constraint still encodes the old four values.`

Recommendation: add `V23__reaction_contract_clean_cutover.sql`, do not edit V3. The migration should update existing dev/test rows first, then replace `chk_interaction_events_reaction_type`.

```sql
alter table interaction_events
  drop constraint if exists chk_interaction_events_reaction_type;

update interaction_events
set reaction_type = case reaction_type
  when 'calm' then 'cooperating'
  when 'engaged' then 'cooperating'
  when 'imitated' then 'cooperating'
  when 'needs_break' then 'resisting'
  else reaction_type
end
where reaction_type in ('calm', 'engaged', 'imitated', 'needs_break');

alter table interaction_events
  add constraint chk_interaction_events_reaction_type
  check (reaction_type in (
    'cooperating', 'hesitant', 'resisting', 'no_response', 'other'
  ));
```

### Finding 4

`[P2] (confidence: 8/10) GrowthSummaryService.java:42 and GrowthInsightsService.java:79 - growth endpoints count reaction_type = 'imitated'.`

Recommendation: do not map `cooperating` back into `imitationCount`. That permanently compresses new semantics into an old metric. In T1, remove old literal branches from active queries and either deprecate the old metric as zero/null in tests or rename in a backend-only follow-up if the API contract allows it.

## Code Quality Review

### Contract authority

Add one small mobile_v2 domain helper:

```dart
enum RitualReactionContract {
  cooperating('cooperating'),
  hesitant('hesitant'),
  resisting('resisting'),
  noResponse('no_response'),
  other('other');

  const RitualReactionContract(this.wireName);
  final String wireName;

  static RitualReactionContract parse(String value) => switch (value.trim()) {
    'cooperating' => cooperating,
    'hesitant' => hesitant,
    'resisting' => resisting,
    'no_response' => noResponse,
    'other' => other,
    _ => throw FormatException('unsupported reaction selection: $value'),
  };

  static String requireWireName(String value) => parse(value).wireName;
}
```

Use it without changing `ReactionSelectionPayload.selected` from `String`. That keeps the generic `InputEvent` transport shape stable while making reaction values strict.

Touch points:

- `InputEvent.reactionSelection`: validate `selected` via `RitualReactionContract.requireWireName`.
- `InteractionInputDto._validatePayload`: validate `payload.selected` when `type == reaction_selection`.
- `InteractionMapper.inputToDomain`: relies on `InputEvent.reactionSelection` to fail fast.
- `RuleBasedNormalizeEngine`: switch on `RitualReactionContract.parse(selected)` instead of loose substring matching for reaction payloads.
- `interaction_test_fixtures.dart`, mapper tests, normalize tests, provider tests: use canonical values.

### Legacy mobile sync

If `mobile/` remains in CI or packaging, update:

- `mobile/lib/features/practice/domain/models/interaction_event_payload.dart`
- generated `interaction_event_payload.freezed.dart`
- Isar entity mapping that serializes/deserializes `reactionType`
- upload request tests that call `toJsonMap()` or backend sync
- garden, mentor, household, and growth consumers that switch on `BabyReactionType`

Recommended enum:

```dart
enum BabyReactionType {
  cooperating,
  hesitant,
  resisting,
  noResponse,
  other,
}
```

Keep parser strict. Do not accept old values in normal runtime. Use a one-time dev/test migration or a local reset before enabling the parser.

### Backend contract

Keep backend validation simple and boring:

```java
private static final Set<String> ALLOWED_REACTION_TYPES = Set.of(
    "cooperating", "hesitant", "resisting", "no_response", "other"
);
```

Do not add an old-to-new runtime mapper in `AuthConsentSyncService`. The migration handles existing rows. Runtime handles only canonical new values.

### Source scan gate

After T1, these old literals should remain only in ADR/docs/migration mapping comments or tests that assert rejection:

```powershell
rg -n "calm|engaged|imitated|needs_break|not_ready_yet|wants_independence|running_away|joining_action|trying_independently" mobile_v2/lib mobile_v2/test mobile/lib mobile/test backend/app-api/src/main backend/app-api/src/test backend/db-migration/src/main/resources/db/migration
```

Expected: no active runtime use of old reaction values outside ADR-approved migration/rejection tests.

## Test Review

### Test framework detection

- mobile_v2: Flutter tests under `mobile_v2/test`, run with `flutter test --no-pub`.
- mobile legacy: Flutter tests under `mobile/test`, generated code via existing build_runner workflow if enum changes require regeneration.
- backend: Maven/Spring Boot tests under `backend/app-api/src/test` and Flyway migration tests.

### Coverage diagram

```text
CODE PATHS                                               USER/API FLOWS
[+] mobile_v2 reaction domain                            [+] Ritual Room reaction submit
  |-- [GAP] canonical five values accepted                  |-- [GAP] choosing each canonical reaction writes same wire value
  |-- [GAP] old four values rejected                        |-- [GAP] invalid fixture choice fails before submit
  |-- [GAP] invalid random value rejected                   |-- [GAP] submitting/unknown retry keeps same canonical selectedReaction
  |
[+] mobile_v2 stable content fixture                     [+] Local/dev content restore
  |-- [GAP] shoes_on reaction choices use canonical IDs      |-- [GAP] fixture parser rejects old IDs
  |-- [GAP] no duplicate canonical IDs
  |
[+] mobile_v2 normalize pipeline
  |-- [GAP] cooperating -> shared_action / continue
  |-- [GAP] hesitant -> uncertain or low_joinability
  |-- [GAP] resisting -> avoidance / low_joinability
  |-- [GAP] no_response -> no visible response / observe
  |-- [GAP] other -> explicit other / needs context
  |-- [GAP] old values fail fast, not other
  |
[+] legacy mobile sync queue                            [+] Sync upload/bootstrap
  |-- [GAP] enum writes five canonical values               |-- [GAP] upload sends canonical reactionType
  |-- [GAP] parser rejects old values after reset/migration  |-- [GAP] bootstrap/import rejects old values after reset/migration
  |-- [GAP] local migration/reset path documented
  |
[+] backend sync validation                              [+] API /api/v1/sync/events
  |-- [GAP] accepts five canonical values                    |-- [GAP] batch with all five values returns 200
  |-- [GAP] rejects old four values                          |-- [GAP] old value returns 400 invalid_reaction_type
  |-- [GAP] rejects unknown value                            |-- [GAP] invalid value does not persist partial batch
  |
[+] DB migration
  |-- [GAP] old dev rows migrated once
  |-- [GAP] new check allows only five values
  |-- [GAP] old inserts fail at DB
  |
[+] backend consumers
  |-- [GAP] growth/garden/household/mentor contain no old-value branches
  |-- [GAP] old imitation metric is not silently mapped to cooperating

COVERAGE TARGET: 0 currently proven for ADR-0001 cutover-specific paths.
QUALITY TARGET: every listed GAP needs a focused test; backend old-value rejection is P1.
```

### Required tests

mobile_v2:

- `mobile_v2/test/features/ritual_room/domain/models/interaction_contract_test.dart`
  - accepts exactly the five canonical reaction selections.
  - rejects `calm`, `engaged`, `imitated`, `needs_break`, `not_ready_yet`, and arbitrary unknown values.
- `mobile_v2/test/features/ritual_room/data/mappers/interaction_mapper_test.dart`
  - DTO `reaction_selection` round-trips all five values.
  - JSON parsing rejects old and unknown `payload.selected`.
- `mobile_v2/test/features/ritual_room/domain/engine/normalize_engine_test.dart`
  - one case per canonical reaction.
  - `other` only works when explicitly selected.
- `mobile_v2/test/features/ritual_room/data/datasources/mock_ritual_content_api_test.dart`
  - fixture has exactly the five canonical IDs.
  - no fixture reaction choice uses old/content-specific IDs.
- `mobile_v2/test/app/providers/ritual_room_session_provider_test.dart`
  - `submitReaction('hesitant')` stores `selectedReaction == 'hesitant'`.
  - unknown outcome retry replays the same canonical selected value.

mobile legacy, if retained:

- `mobile/test/features/practice/interaction_event_payload_test.dart`
  - enum wire values are the ADR five.
  - parser rejects old values.
  - upload record serializes canonical values.
- repository/local store tests covering import and pending upload records.
- generated code check after build_runner regeneration.

backend:

- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncWebTest.java`
  - batch with five canonical values succeeds.
  - each old value returns `400 invalid_reaction_type`.
  - arbitrary unknown returns `400 invalid_reaction_type`.
  - partial batch with an invalid value inserts zero events.
- migration test or Flyway integration:
  - old rows migrate to allowed new rows.
  - check constraint rejects old rows after migration.
- growth/garden/household/mentor tests:
  - source contains no branch on old values.
  - no metric maps `cooperating` to old `imitated` semantics unless a separate product decision approves it.

### Verification commands

```powershell
$env:CI='true'; $env:DART_SUPPRESS_ANALYTICS='true'; Push-Location mobile_v2; try {
  & 'C:\software\flutter\bin\flutter.bat' test --no-pub `
    test/features/ritual_room/domain/models/interaction_contract_test.dart `
    test/features/ritual_room/data/mappers/interaction_mapper_test.dart `
    test/features/ritual_room/domain/engine/normalize_engine_test.dart `
    test/features/ritual_room/data/datasources/mock_ritual_content_api_test.dart `
    test/app/providers/ritual_room_session_provider_test.dart
} finally { Pop-Location }
```

```powershell
Push-Location backend; try {
  .\mvnw.cmd -pl app-api -Dtest=AuthConsentSyncWebTest,GrowthSummaryControllerTest test
} finally { Pop-Location }
```

```powershell
rg -n "calm|engaged|imitated|needs_break|not_ready_yet|wants_independence|running_away|joining_action|trying_independently" `
  mobile_v2/lib mobile_v2/test mobile/lib mobile/test backend/app-api/src/main backend/app-api/src/test backend/db-migration/src/main/resources/db/migration
```

## Performance Review

No meaningful runtime performance risk. The new validation is set membership or enum parsing. The migration is a one-time update over `interaction_events.reaction_type`, which is small in current dev/test data. If a shared dev DB has many rows, run the update inside the migration as written; it touches only four old values and then reinstalls a check constraint.

## Implementation Tasks

- [ ] **T1.1 (P1, human: ~1h / CC: ~15min)** - mobile_v2 domain - Add strict canonical reaction contract.
  - Surfaced by: Architecture Finding 1.
  - Files: `mobile_v2/lib/features/ritual_room/domain/models/input_event.dart`, optional new `reaction_contract.dart`, `mobile_v2/test/features/ritual_room/domain/models/interaction_contract_test.dart`.
  - Verify: focused domain model test.
- [ ] **T1.2 (P1, human: ~1h / CC: ~20min)** - mobile_v2 data/content - Cut fixture IDs and transport mapper to canonical values.
  - Surfaced by: Architecture Finding 1.
  - Files: `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json`, `interaction_input_dto.dart`, `interaction_mapper_test.dart`, `mock_ritual_content_api_test.dart`, fixture helpers.
  - Verify: mapper and mock content API tests.
- [ ] **T1.3 (P1, human: ~1h / CC: ~20min)** - mobile_v2 engine/provider - Normalize canonical reactions and preserve same-event retry semantics.
  - Surfaced by: Test review.
  - Files: `normalize_engine.dart`, `normalize_engine_test.dart`, `ritual_room_session_provider_test.dart`.
  - Verify: normalize and provider tests.
- [ ] **T1.4 (P1, human: ~2h / CC: ~40min)** - legacy mobile sync - Cut local sync enum/parser/upload records if `mobile/` remains active.
  - Surfaced by: Code Quality Review.
  - Files: `mobile/lib/features/practice/domain/models/interaction_event_payload.dart`, generated Freezed file, local store/repository tests and any compile-required switch cases.
  - Verify: targeted `mobile/test/features/practice` tests plus generation check.
- [ ] **T1.5 (P1, human: ~2h / CC: ~35min)** - backend sync/DB - Update validation and add V23 clean-cutover migration.
  - Surfaced by: Architecture Findings 2 and 3.
  - Files: `AuthConsentSyncService.java`, `V23__reaction_contract_clean_cutover.sql`, `AuthConsentSyncWebTest.java`, migration test.
  - Verify: Maven focused web/migration tests.
- [ ] **T1.6 (P2, human: ~1h / CC: ~25min)** - backend consumers - Remove old-value branches from growth/garden/household/mentor logic without inventing replacement analytics.
  - Surfaced by: Architecture Finding 4.
  - Files: `GrowthSummaryService.java`, `GrowthInsightsService.java`, related tests, any other old-value branch surfaced by source scan.
  - Verify: source scan plus focused controller/service tests.
- [ ] **T1.7 (P1, human: ~30min / CC: ~10min)** - verification - Run the full cutover gate and record outputs.
  - Surfaced by: Test Review.
  - Files: no product files unless verification reveals gaps.
  - Verify: all focused commands and source scan pass.

## NOT In Scope

- Today path current-node UI.
- Scene browse UI.
- One-utterance turn-loop UI.
- Visual copy polish, layout changes, golden baseline updates unrelated to changed data IDs.
- Dual-accept compatibility for released clients.
- Permanent old-to-new runtime mapper.
- Mapping new values back to old analytics semantics such as `imitated`.
- Backend-wide event-sourcing rewrite.
- Product decision for future reaction analytics beyond raw five-value preservation.

## Failure Modes

| Codepath | Failure | Test required | User/API behavior |
|---|---|---|---|
| mobile_v2 event creation | Old value reaches `InputEvent.reactionSelection` | domain model rejection test | fail fast in test/dev, no silent `other` |
| mobile_v2 fixture | `reaction_choices[].id` stays `not_ready_yet` | mock content fixture test | app cannot submit noncanonical IDs |
| mobile_v2 mapper | JSON DTO accepts unknown selected | mapper parse test | throws `FormatException` |
| mobile_v2 normalize | `other` used as fallback | normalize invalid/other tests | invalid fails; explicit other normalizes |
| provider retry | unknown outcome replays different selected value | provider retry test | retry keeps same canonical event |
| legacy mobile sync | local queue imports old values | parser/import tests | dev reset or migration required before strict parser |
| backend service | old value accepted at API | `AuthConsentSyncWebTest` old-value cases | `400 invalid_reaction_type` |
| DB migration | old rows violate new check | migration test | rows converted before constraint install |
| backend analytics | `cooperating` counted as `imitated` | service/source scan test | no silent semantic compression |

Critical silent gap to avoid: backend accepting an invalid value while mobile maps it to `other`. ADR-0001 forbids this. Invalid values must reject.

## Worktree Parallelization Strategy

| Step | Modules touched | Depends on |
|---|---|---|
| T1.1 mobile_v2 contract | `mobile_v2/lib/features/ritual_room/domain`, `mobile_v2/test/features/ritual_room/domain` | - |
| T1.2 mobile_v2 data/content | `mobile_v2/lib/features/ritual_room/data`, `mobile_v2/assets`, `mobile_v2/test/features/ritual_room/data` | T1.1 |
| T1.3 mobile_v2 engine/provider | `mobile_v2/lib/features/ritual_room/domain/engine`, `mobile_v2/lib/app/providers`, tests | T1.1 |
| T1.4 legacy mobile sync | `mobile/lib/features/practice`, `mobile/test` | - |
| T1.5 backend sync/DB | `backend/app-api`, `backend/db-migration` | - |
| T1.6 backend consumers | `backend/app-api/src/main/java/.../service`, tests | T1.5 preferred |
| T1.7 verification | all touched modules | T1.1-T1.6 |

Parallel lanes:

- Lane A: T1.1 -> T1.2 -> T1.3. Sequential because mobile_v2 data/provider tests depend on the same canonical parser.
- Lane B: T1.4. Independent if legacy mobile is still active.
- Lane C: T1.5 -> T1.6. Sequential because consumer tests should run against the new backend constraint.
- Final lane: T1.7 after A/B/C merge.

Conflict flags:

- T1.2 and T1.3 both touch mobile_v2 test fixtures; keep them in one worktree if possible.
- T1.5 and T1.6 both touch backend tests and may share data setup; keep them in one backend worktree.

## Completion Summary

- Step 0 Scope Challenge: scope accepted as complete because ADR-0001 requires mobile, backend, DB, and test/dev data to cut together.
- Architecture Review: 4 issues found.
- Code Quality Review: 3 concrete recommendations.
- Test Review: diagram produced, 23 gaps identified.
- Performance Review: 0 issues found.
- NOT in scope: written.
- What already exists: written.
- TODOS.md updates: 0 applied; reaction analytics replacement remains a future product decision, not a T1 TODO.
- Failure modes: 1 critical silent-fallback gap flagged.
- Outside voice: skipped; this is ADR-execution planning against local source, not a cross-model product decision.
- Parallelization: 3 lanes, 3 parallel after contract boundaries are clear, 1 final sequential verification lane.
- Lake Score: 4/4 recommendations choose the complete cutover option over compatibility shortcuts.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | not run | Not needed for backend/data contract cutover |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run | Skipped for plan draft |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | clear | 4 architecture findings, 23 test gaps converted into tasks, 1 critical silent-fallback gap |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | Not applicable because no UI scope |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | Not applicable |

**UNRESOLVED:** 0

**VERDICT:** ENG CLEARED - ready to implement T1 Reaction clean cutover, with no UI implementation.
