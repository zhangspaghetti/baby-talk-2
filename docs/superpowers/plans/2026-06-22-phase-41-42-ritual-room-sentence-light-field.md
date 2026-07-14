# Phase 41/42 Ritual Room Sentence Light Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Phase 41 D.4.5 card/modal projection with the approved Flutter Android “句子光场” Ritual Room while preserving the existing Interaction Engine, one-session Notifier, immutable ProductSnapshot truth, and exact original-event reconciliation.

**Architecture:** Keep Phase 41 domain/runtime authority intact. First close the Phase 41 documentation and snapshot-contract bridge, then implement Phase 42 as a projection-only redesign: content-owned atmosphere metadata and atomic active-utterance data flow into a tokenized theme, a decorative atmosphere layer, one semantic sentence plane, and a non-modal local Dock. UI-only expansion state and audio presentation state remain local; no second product-state controller is introduced.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, Material 3 primitives, Riverpod 3.3.0 only in existing app composition/providers, Flutter gen-l10n, `flutter_test`, Android TalkBack/device UAT.

---

## 0. Scope split and implementation order

### Phase 41 — must complete before the redesign is accepted

These items are Phase 41 closure or bridge work. They protect already-verified
behavior and remove ambiguity; they do not redesign the screen.

1. Supersede the obsolete D.4.5 visual UAT and record the new no-focus-stealing
   accessibility interpretation.
2. Preserve the existing engine, one Notifier, single-flight admission, and
   original-event reconciliation with focused regression commands.
3. Make English, Chinese support, and action timing one immutable
   `ActiveUtterance` snapshot so Phase 42 cannot render mixed revisions.

Phase 41 must not be reopened for:

- engine pipeline redesign
- a second controller, Notifier, or ViewModel
- voice/STT acquisition
- free-text UI
- strategy controls
- production audio integration
- Garden state or memory UI

### Phase 42 — required sentence-light-field implementation

1. Content-owned atmosphere token and local design tokens.
2. Generated localization for generic UI chrome.
3. Edge illustration atmosphere layer and unframed sentence plane.
4. Non-modal bottom Dock with local expand/collapse state.
5. Stable local state projection for submitting, recoverable failure, and
   unknown-outcome reconciliation.
6. TalkBack order, no forced focus, text scaling, reduced motion, dual viewport
   widget/golden coverage, and Android UAT.
7. Removal of the old card/modal presentation files after replacement coverage
   passes.

### Phase 42 — explicitly deferred follow-ups

These need separate approval or assets and are not required for the first
sentence-light-field merge:

- Real audio playback. The current fixture truthfully declares
  `"available": false` and no audio asset exists. The first merge must not expose
  a functional-looking no-op control. A later audio sub-plan must approve an
  asset, player dependency, interruption behavior, disposal, and device tests.
- Visible voice, free-text, future-signal, or strategy controls. The engine
  remains capability-complete, but the approved sentence-light-field design has
  no visual contract for these controls. Do not add placeholders.
- Additional production illustrations or atmosphere variants beyond the
  `shoes_on` room. Implement the token system now; add assets only through a
  later approved content/illustration plan.
- Production Garden or Memory Lens behavior.

## 1. Locked file map

### Phase 41 closure/bridge

**Modify**

- `docs/superpowers/specs/2026-06-22-phase-41-42-ritual-room-sentence-light-field-design.md`
  — clarify that “return to the sentence” is visual/semantic priority, never an
  automatic TalkBack focus request.
- `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-UAT.md`
  — mark the D.4.5 visual comparison as superseded and retain engine/reconciliation
  evidence.
- `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-VERIFICATION.md`
  — record that the old visual human gate is replaced by Phase 42 sentence-light-field
  UAT.
- `.planning/ROADMAP.md`
  — split the approved reaction-only sentence-light-field core from future
  multi-channel affordance work.
- `.planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-CONTEXT.md`
  — make the approved sentence-light-field design the Phase 42 execution
  authority.
- `mobile_v2/lib/features/ritual_room/domain/models/active_utterance.dart`
  — add required `actionCue`.
- `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart`
  — parse `active_utterances.*.action_cue`.
- `mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart`
  — transport `actionCue` explicitly.
- `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart`
  — map content utterance timing.
- `mobile_v2/lib/features/ritual_room/data/mappers/interaction_mapper.dart`
  — round-trip timing with the snapshot.
- `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_runtime_state.dart`
  — serialize timing.
- `mobile_v2/lib/features/ritual_room/domain/runtime/replay_journal.dart`
  — serialize/replay timing as part of `ActiveUtterance`.
- `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json`
  — put an `action_cue` on each active utterance.
- Existing test builders and mapper/runtime/engine tests returned by:
  `rg -l "ActiveUtterance\\(" mobile_v2/lib mobile_v2/test`.

### Phase 42 production UI

**Create**

- `mobile_v2/lib/app/localization/l10n/app_zh.arb`
- `mobile_v2/l10n.yaml`
- `mobile_v2/lib/app/theme/ritual_room_theme.dart`
- `mobile_v2/lib/features/ritual_room/domain/models/ritual_atmosphere_tone.dart`
- `mobile_v2/lib/features/ritual_room/presentation/models/ritual_listen_state.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_atmosphere_layer.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_sentence_plane.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_dock.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_choices.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_transient_notice.dart`
- `mobile_v2/test/helpers/ritual_room_test_harness.dart`
- `mobile_v2/test/features/ritual_room/presentation/ritual_room_golden_test.dart`
- `mobile_v2/test/goldens/ritual_room/` approved PNG baselines
- `.planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-UAT.md`

**Modify**

- `mobile_v2/pubspec.yaml`
- `mobile_v2/lib/app/baby_talk_app.dart`
- `mobile_v2/lib/app/theme/baby_talk_theme.dart`
- `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart`
- `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart`
- `mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart`
- `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart`
- `mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`
- `mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart`
- `mobile_v2/test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart`
- `tool/verify_mobile_v2_semantic_firewall.dart`

**Delete only after replacement tests pass**

- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_identity_header.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_current_utterance.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_reassurance.dart`
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_submitting_indicator.dart`

Keep `ritual_action_cue.dart` and `ritual_listen_control.dart`, but refactor them
to the new unframed sentence-plane APIs.

---

## Task 1: Rebaseline Phase 41 authority and accessibility wording

**Scope:** Phase 41 required

**Files:**

- Modify: `docs/superpowers/specs/2026-06-22-phase-41-42-ritual-room-sentence-light-field-design.md`
- Modify: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-UAT.md`
- Modify: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-VERIFICATION.md`
- Modify: `.planning/ROADMAP.md`
- Create: `.planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-CONTEXT.md`

- [x] **Step 1: Replace ambiguous focus wording in the approved design**

Use this exact contract wherever the document says the reading focus returns to
the sentence:

```markdown
“回到主句”表示视觉重心与语义阅读路径重新以主句为先，不表示调用
`requestFocus`、`FocusScope` 或平台语义公告 API 强制抢占 TalkBack
当前焦点。异步更新、收起 Dock 与“先这样就好”不得自动跳转无障碍
焦点；一次性 live region 只做低打扰宣告，用户按自然阅读顺序浏览到
新主句。
```

- [x] **Step 2: Mark the old D.4.5 visual UAT as superseded**

Change Test 1 in `41-UAT.md` to:

```markdown
### 1. D.4.5 visual comparison
result: superseded
evidence: |
  Superseded on 2026-06-22 by the approved Phase 41/42 Ritual Room
  “句子光场” design contract. Do not approve or reject the current milestone
  by comparing it with the obsolete card/modal D.4.5 projection.
```

Keep the interaction/reconciliation evidence. Do not mark TalkBack device work
as passed; move its visual/focus acceptance to Phase 42 UAT.

- [x] **Step 3: Reconcile the Phase 42 roadmap scope**

In `.planning/ROADMAP.md`, keep the capability-complete engine goal but split
delivery into:

```markdown
- [ ] Implement the approved reaction-only “句子光场” core: stable sentence
  plane, non-modal context Dock, responsive layout, accessibility, and visual UAT.
- [ ] Prototype voice/free-text/strategy affordances only after a separate
  product schematic is approved; no placeholder controls belong to the core plan.
```

Create `42-CONTEXT.md`:

```markdown
# Phase 42 Context

The execution authority is:
`docs/superpowers/specs/2026-06-22-phase-41-42-ritual-room-sentence-light-field-design.md`.

Phase 42 first delivers the reaction-only sentence-light-field core. The
Interaction Engine remains capable of reaction, voice, free-text, future-signal,
and strategy inputs, but this plan does not expose unapproved controls.
```

- [x] **Step 4: Update verification status without rewriting historical evidence**

Append a dated addendum to `41-VERIFICATION.md`:

```markdown
## 2026-06-22 Design Supersession Addendum

Phase 41 engine, repository, Notifier, single-flight, and original-event
reconciliation evidence remains valid. The D.4.5 presentation fidelity gate is
superseded. Sentence-light-field layout, non-modal Dock, TalkBack focus behavior,
dual viewport screenshots, text scaling, and reduced-motion acceptance are
Phase 42 gates.
```

- [x] **Step 5: Run documentation checks**

Run:

```powershell
rg -n "requestFocus|FocusScope|强制抢占|superseded|句子光场" `
  docs/superpowers/specs/2026-06-22-phase-41-42-ritual-room-sentence-light-field-design.md `
  .planning/phases/41-mobile-v2-runnable-vertical-slice/41-UAT.md `
  .planning/phases/41-mobile-v2-runnable-vertical-slice/41-VERIFICATION.md `
  .planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-CONTEXT.md `
  .planning/ROADMAP.md
git diff --check
```

Expected: focus non-grab wording and supersession addendum are found; no
whitespace errors.

- [x] **Step 6: Commit**

```powershell
git add -- `
  docs/superpowers/specs/2026-06-22-phase-41-42-ritual-room-sentence-light-field-design.md `
  .planning/phases/41-mobile-v2-runnable-vertical-slice/41-UAT.md `
  .planning/phases/41-mobile-v2-runnable-vertical-slice/41-VERIFICATION.md `
  .planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-CONTEXT.md `
  .planning/ROADMAP.md
git commit -m "docs(41): supersede d4.5 visual uat"
```

---

## Task 2: Make action timing part of the immutable utterance snapshot

**Scope:** Phase 41/42 bridge; required before Phase 42 widgets

**Files:**

- Modify: `mobile_v2/lib/features/ritual_room/domain/models/active_utterance.dart`
- Modify: `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json`
- Modify: `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart`
- Test: `mobile_v2/test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/models/interaction_contract_test.dart`

- [x] **Step 1: Write failing mapper and contract tests**

Add assertions:

```dart
expect(ready.actionCue, '拿起鞋时');
expect(revised.actionCue, '宝宝停下来时');
expect(snapshot.activeUtterance.actionCue, isNotEmpty);
```

Update the mapper test payload so each active utterance owns its timing:

```dart
'ready': {
  'display_id': 'shoes_on_ready_v1',
  'primary': 'Let’s put your shoes on.',
  'zh_support': '我们来穿鞋吧。',
  'action_cue': '拿起鞋时',
  'audio_asset_id': 'rr_shoes_001',
},
'not_ready_yet': {
  'display_id': 'shoes_on_revised_wait_v1',
  'primary': 'You don’t want your shoes on yet.',
  'zh_support': '你现在还不想穿鞋。',
  'action_cue': '宝宝停下来时',
  'audio_asset_id': 'rr_shoes_002',
},
```

- [x] **Step 2: Run the focused tests and verify failure**

Run from `mobile_v2`:

```powershell
flutter test `
  test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart `
  test/features/ritual_room/domain/models/interaction_contract_test.dart
```

Expected: compile failure because `ActiveUtterance.actionCue` does not exist.

- [x] **Step 3: Add the required domain field**

Change the constructor and fields to:

```dart
final class ActiveUtterance {
  const ActiveUtterance({
    required this.displayId,
    required this.primary,
    required this.zhSupport,
    required this.actionCue,
    required this.audioAssetId,
    this.contextLabel,
    this.gentleSupport,
  });

  final String displayId;
  final String primary;
  final String zhSupport;
  final String actionCue;
  final String audioAssetId;
  final String? contextLabel;
  final String? gentleSupport;
}
```

- [x] **Step 4: Add `action_cue` to the stable content DTO**

In `RitualActiveUtteranceResponse`:

```dart
actionCue: _requiredString(json, 'action_cue'),
```

Add:

```dart
final String actionCue;
```

and serialize:

```dart
'action_cue': actionCue,
```

Map it in `RitualRoomMapper.toActiveUtterance`:

```dart
actionCue: value.actionCue,
```

- [x] **Step 5: Update the canonical fixture**

Add:

```json
"action_cue": "拿起鞋时"
```

to `ready`, and:

```json
"action_cue": "宝宝停下来时"
```

to `not_ready_yet`.

The top-level `action_cue` may remain for one compatibility commit, but Phase 42
presentation must stop reading it. Remove it only after all consumers use
`snapshot.activeUtterance.actionCue`.

- [x] **Step 6: Update every constructor**

Run:

```powershell
rg -l "ActiveUtterance\\(" lib test
```

For every listed constructor, add a non-empty `actionCue`. Production builders
must copy the cue owned by their fixture/source. Generic engine-only test
doubles must use:

```dart
actionCue: 'shared action moment',
```

Do not use an empty string or derive timing in a widget.

- [x] **Step 7: Re-run focused tests**

```powershell
flutter test `
  test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart `
  test/features/ritual_room/domain/models/interaction_contract_test.dart
```

Expected: PASS.

- [x] **Step 8: Commit**

```powershell
git add -- mobile_v2
git commit -m "refactor(41): bind action cue to active utterance"
```

---

## Task 3: Preserve action timing through transport, replay, and parity

**Scope:** Phase 41/42 bridge; required before Phase 42 widgets

**Files:**

- Modify: `mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/mappers/interaction_mapper.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/models/product_snapshot.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_runtime_state.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/runtime/replay_journal.dart`
- Test: `mobile_v2/test/features/ritual_room/data/mappers/interaction_mapper_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_replay_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/repositories/interaction_repository_test.dart`

- [x] **Step 1: Write failing round-trip and replay assertions**

Add:

```dart
expect(roundTripped.activeUtterance.actionCue, source.activeUtterance.actionCue);
expect(replayed.activeUtterance.actionCue, expected.activeUtterance.actionCue);
expect(repositoryResult.activeUtterance.actionCue, '宝宝停下来时');
expect(ProductSnapshot.currentSchemaVersion, 2);
```

- [x] **Step 2: Run focused tests and verify failure**

```powershell
flutter test `
  test/features/ritual_room/data/mappers/interaction_mapper_test.dart `
  test/features/ritual_room/domain/engine/interaction_engine_replay_test.dart `
  test/features/ritual_room/data/repositories/interaction_repository_test.dart
```

Expected: FAIL because transport and replay do not preserve `actionCue`.

- [x] **Step 3: Add explicit transport ownership**

Because the snapshot wire shape changes, bump:

```dart
static const int currentSchemaVersion = 2;
```

Update schema assertions and transport test payloads from `1` to `2`. Keep
unsupported-schema tests by feeding `1` and `3`; both must fail explicitly.

Change `InteractionUtteranceResponse` to include:

```dart
required this.actionCue,
```

Parse, store, and serialize:

```dart
actionCue: _requiredString(json, 'actionCue'),
final String actionCue;
'actionCue': actionCue,
```

Do not encode action timing into `alternatives`.

- [x] **Step 4: Map both directions**

In `snapshotFromDomain`:

```dart
actionCue: snapshot.activeUtterance.actionCue,
```

In `snapshotToDomain`:

```dart
actionCue: response.utterance.actionCue,
```

- [x] **Step 5: Serialize runtime and journal evidence**

Add to both `_activeUtteranceToJson` helpers:

```dart
'actionCue': value.actionCue,
```

Replay already carries the whole `ActiveUtterance`; do not create a separate
action-cue field on `ProductSnapshot`.

- [x] **Step 6: Run the focused tests**

Run the command from Step 2.

Expected: PASS with action timing preserved across DTO round-trip, repository,
runtime JSON, and replay.

- [x] **Step 7: Run the complete Phase 41 authority suite**

```powershell
flutter test test/features/ritual_room/domain
flutter test test/features/ritual_room/data
flutter test test/app/providers/ritual_room_session_provider_test.dart
```

Expected: PASS. Event identity, revision, atomicity, and original-event retry
remain unchanged.

- [x] **Step 8: Commit**

```powershell
git add -- mobile_v2
git commit -m "refactor(41): round trip utterance timing"
```

---

## Task 4: Add content-owned atmosphere metadata and local design tokens

**Scope:** Phase 42 required

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/domain/models/ritual_atmosphere_tone.dart`
- Create: `mobile_v2/lib/app/theme/ritual_room_theme.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart`
- Modify: `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json`
- Modify: `mobile_v2/lib/app/theme/baby_talk_theme.dart`
- Test: `mobile_v2/test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart`
- Create: `mobile_v2/test/app/theme/ritual_room_theme_test.dart`

- [x] **Step 1: Write failing tone parsing and token tests**

```dart
expect(content.atmosphereTone, RitualAtmosphereTone.everydayCalm);
expect(
  RitualRoomTheme.light.paletteFor(RitualAtmosphereTone.everydayCalm).canvas,
  const Color(0xFFFBF6EF),
);
expect(RitualRoomTheme.light.textMuted, const Color(0xFF756A63));
```

- [x] **Step 2: Run tests and verify failure**

```powershell
flutter test `
  test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart `
  test/app/theme/ritual_room_theme_test.dart
```

Expected: FAIL because the tone and theme extension do not exist.

- [x] **Step 3: Add the domain-safe tone**

```dart
enum RitualAtmosphereTone {
  everydayCalm('everyday_calm'),
  gentlyLively('gently_lively'),
  groundedSoothing('grounded_soothing'),
  bedtimeQuiet('bedtime_quiet');

  const RitualAtmosphereTone(this.wireName);

  final String wireName;

  static RitualAtmosphereTone fromWireName(String value) =>
      RitualAtmosphereTone.values.firstWhere(
        (tone) => tone.wireName == value,
        orElse: () => throw FormatException(
          'Unsupported ritual atmosphere tone: $value',
        ),
      );
}
```

Add `required this.atmosphereTone` to `RitualRoomContent`.

- [x] **Step 4: Add transport and fixture fields**

At the room root:

```json
"atmosphere_tone": "everyday_calm"
```

Parse it as a required non-empty string and map with
`RitualAtmosphereTone.fromWireName`.

- [x] **Step 5: Add the ThemeExtension**

Define a palette value and tokens with these exact core colors:

```dart
@immutable
final class RitualAtmospherePalette {
  const RitualAtmospherePalette({
    required this.canvas,
    required this.lightField,
  });

  final Color canvas;
  final Color lightField;
}

@immutable
final class RitualRoomTheme extends ThemeExtension<RitualRoomTheme> {
  const RitualRoomTheme({
    required this.canvas,
    required this.lightField,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.assistive,
    required this.assistiveSurface,
    required this.warmAccent,
    required this.divider,
  });

  static const light = RitualRoomTheme(
    canvas: Color(0xFFFBF6EF),
    lightField: Color(0xFFFFFDF9),
    textPrimary: Color(0xFF302A26),
    textSecondary: Color(0xFF6D625B),
    textMuted: Color(0xFF756A63),
    assistive: Color(0xFF3F746B),
    assistiveSurface: Color(0xFFE4F0EC),
    warmAccent: Color(0xFFB9653B),
    divider: Color(0xFFE2D9D1),
  );

  final Color canvas;
  final Color lightField;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color assistive;
  final Color assistiveSurface;
  final Color warmAccent;
  final Color divider;

  RitualAtmospherePalette paletteFor(RitualAtmosphereTone tone) =>
      switch (tone) {
        RitualAtmosphereTone.everydayCalm =>
          const RitualAtmospherePalette(
            canvas: Color(0xFFFBF6EF),
            lightField: Color(0xFFFFFDF9),
          ),
        RitualAtmosphereTone.gentlyLively =>
          const RitualAtmospherePalette(
            canvas: Color(0xFFFCF5E8),
            lightField: Color(0xFFFFFDF8),
          ),
        RitualAtmosphereTone.groundedSoothing =>
          const RitualAtmospherePalette(
            canvas: Color(0xFFF7F2EC),
            lightField: Color(0xFFFCFAF6),
          ),
        RitualAtmosphereTone.bedtimeQuiet =>
          const RitualAtmospherePalette(
            canvas: Color(0xFFF6EFE8),
            lightField: Color(0xFFFCF8F3),
          ),
      };
}
```

Implement `copyWith` and `lerp` for every field. Add the extension to
`BabyTalkTheme.light.extensions`.

- [x] **Step 6: Set typography without online fonts**

Use system sans-serif and these roles in `BabyTalkTheme.light`:

```dart
displaySmall: TextStyle(
  color: ritual.textPrimary,
  fontSize: 36,
  height: 1.25,
  fontWeight: FontWeight.w600,
),
bodyLarge: TextStyle(
  color: ritual.textSecondary,
  fontSize: 16,
  height: 1.55,
  fontWeight: FontWeight.w400,
),
labelLarge: TextStyle(
  color: ritual.textMuted,
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w600,
),
```

Do not add `google_fonts` or a network font.

- [x] **Step 7: Run tests**

Run the command from Step 2.

Expected: PASS.

- [x] **Step 8: Commit**

```powershell
git add -- mobile_v2
git commit -m "feat(42): add ritual atmosphere design tokens"
```

---

## Task 5: Localize generic Ritual Room chrome

**Scope:** Phase 42 required

**Files:**

- Create: `mobile_v2/l10n.yaml`
- Create: `mobile_v2/lib/app/localization/l10n/app_zh.arb`
- Modify: `mobile_v2/pubspec.yaml`
- Modify: `mobile_v2/lib/app/baby_talk_app.dart`
- Test: `mobile_v2/test/app/localization/ritual_room_localization_test.dart`

- [x] **Step 1: Add the localization test**

Assert that generated localization exposes:

```dart
expect(copy.listen, '听一下');
expect(copy.pause, '暂停');
expect(copy.collapseContext, '收起');
expect(copy.retry, '再试一次');
expect(copy.adjustingUtterance, '正在让这句话更贴近一点…');
expect(copy.unknownOutcome, '刚才的调整还没有确认。');
```

- [x] **Step 2: Configure gen-l10n**

`l10n.yaml`:

```yaml
arb-dir: lib/app/localization/l10n
template-arb-file: app_zh.arb
output-dir: lib/app/localization/generated
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
format: true
```

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter

flutter:
  generate: true
```

- [x] **Step 3: Add the Chinese ARB**

```json
{
  "@@locale": "zh",
  "listen": "听一下",
  "pause": "暂停",
  "playSentenceSemantics": "播放这句话",
  "pauseSentenceSemantics": "暂停播放",
  "loadingAudioSemantics": "正在加载语音",
  "audioUnavailable": "暂时听不了，你也可以直接照着说。",
  "contextEntry": "想让这句话更贴近一点吗？",
  "contextEntryHint": "轻触告诉我",
  "contextPrompt": "宝宝现在怎么了？",
  "contextPromptHint": "选一个最接近的就好",
  "collapseContext": "收起",
  "retry": "再试一次",
  "adjustingUtterance": "正在让这句话更贴近一点…",
  "recoverableFailure": "这次没有换好，刚才那句话还可以继续用。",
  "unknownOutcome": "刚才的调整还没有确认。",
  "loadingSentence": "正在准备这句话…",
  "loadFailure": "这个小声音暂时没准备好。稍后再打开一次。",
  "timingSemantics": "说这句话的时机：{timing}",
  "@timingSemantics": {
    "placeholders": {
      "timing": {"type": "String"}
    }
  },
  "adjustedSentenceSemantics": "说法已调整：{sentence}",
  "@adjustedSentenceSemantics": {
    "placeholders": {
      "sentence": {"type": "String"}
    }
  }
}
```

- [x] **Step 4: Generate and wire localization**

Run:

```powershell
flutter pub get
flutter gen-l10n
```

In `MaterialApp`:

```dart
localizationsDelegates: AppLocalizations.localizationsDelegates,
supportedLocales: AppLocalizations.supportedLocales,
```

- [x] **Step 5: Run tests**

```powershell
flutter test test/app/localization/ritual_room_localization_test.dart
```

Expected: PASS.

- [x] **Step 6: Commit**

```powershell
git add -- mobile_v2
git commit -m "feat(42): localize ritual room chrome"
```

---

## Task 6: Build the decorative atmosphere layer and atomic sentence plane

**Scope:** Phase 42 required

**Files:**

- Modify: `mobile_v2/lib/features/ritual_room/presentation/models/ritual_listen_state.dart`
- Create: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_atmosphere_layer.dart`
- Create: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_sentence_plane.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_action_cue.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_listen_control.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart`

- [x] **Step 1: Replace old widget expectations with failing sentence-field tests**

Assert:

```dart
expect(find.byType(RitualAtmosphereLayer), findsOneWidget);
expect(find.byType(RitualSentencePlane), findsOneWidget);
expect(find.byType(Card), findsNothing);
expect(find.byType(AppBar), findsNothing);
expect(find.byType(RitualIdentityHeader), findsNothing);
expect(find.text(snapshot.activeUtterance.primary), findsOneWidget);
expect(find.text(snapshot.activeUtterance.zhSupport), findsOneWidget);
expect(find.text(snapshot.activeUtterance.actionCue), findsOneWidget);
expect(find.text('legacy room-level cue'), findsNothing);
```

Also assert that changing one `ProductSnapshot` changes all three sentence
values in the same pump. Build the test room with
`actionCue: 'legacy room-level cue'` and the snapshot with
`actionCue: '拿起鞋时'` so the assertion proves the widget is not reading the
old room-level field.

- [x] **Step 2: Run the widget test and verify failure**

```powershell
flutter test `
  test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart
```

Expected: FAIL because the new components do not exist.

- [x] **Step 3: Define the audio presentation states used by the sentence plane**

```dart
sealed class RitualListenState {
  const RitualListenState();
}

final class RitualListenUnavailable extends RitualListenState {
  const RitualListenUnavailable();
}

final class RitualListenReady extends RitualListenState {
  const RitualListenReady();
}

final class RitualListenLoading extends RitualListenState {
  const RitualListenLoading();
}

final class RitualListenPlaying extends RitualListenState {
  const RitualListenPlaying();
}

final class RitualListenPaused extends RitualListenState {
  const RitualListenPaused();
}

final class RitualListenFailure extends RitualListenState {
  const RitualListenFailure();
}
```

- [x] **Step 4: Implement `RitualAtmosphereLayer`**

Public API:

```dart
final class RitualAtmosphereLayer extends StatelessWidget {
  const RitualAtmosphereLayer({
    super.key,
    required this.illustration,
    required this.tone,
    required this.roomName,
  });

  final RitualIllustration illustration;
  final RitualAtmosphereTone tone;
  final String roomName;
}
```

Implementation constraints:

- root is `IgnorePointer`
- the complete layer, including illustration and visible room label, is wrapped
  in `ExcludeSemantics`
- no business-state imports
- no `Card`, `Material` elevation, or shadow
- use `LayoutBuilder` to clamp illustration size between 88dp and 128dp
- place illustration at an edge and keep the center sentence bounds clear
- render `roomName` as low-emphasis visual text inside the excluded decorative
  layer
- use a radial/linear light-field gradient only when
  `MediaQuery.highContrastOf(context)` is false

- [x] **Step 5: Implement `RitualSentencePlane`**

Public API:

```dart
final class RitualSentencePlane extends StatelessWidget {
  const RitualSentencePlane({
    super.key,
    required this.utterance,
    required this.listenState,
    required this.onListen,
    required this.motionDuration,
  });

  final ActiveUtterance utterance;
  final RitualListenState listenState;
  final VoidCallback? onListen;
  final Duration motionDuration;
}
```

Give the root:

```dart
key: const Key('ritual-sentence-plane'),
```

Give the English and Chinese semantic nodes:

```dart
key: const Key('ritual-primary-sentence'),
key: const Key('ritual-zh-support'),
```

The semantic and visual order inside one `Column` is:

```dart
Semantics(
  sortKey: const OrdinalSortKey(1),
  label: utterance.primary,
  child: Text(utterance.primary),
),
Semantics(
  sortKey: const OrdinalSortKey(2),
  label: utterance.zhSupport,
  child: Text(utterance.zhSupport),
),
RitualActionCue(
  cue: utterance.actionCue,
  sortKey: const OrdinalSortKey(3),
),
RitualListenControl(
  state: listenState,
  sortKey: const OrdinalSortKey(4),
  onPressed: onListen,
),
```

Use one `AnimatedSwitcher` keyed by `utterance.displayId` around the complete
English/Chinese/timing group. Do not animate each field separately.

- [x] **Step 6: Respect reduced motion**

Calculate duration at the screen boundary:

```dart
final reduceMotion = MediaQuery.disableAnimationsOf(context);
final atmosphereMotionDuration = switch (room.atmosphereTone) {
  RitualAtmosphereTone.everydayCalm =>
    const Duration(milliseconds: 200),
  RitualAtmosphereTone.gentlyLively =>
    const Duration(milliseconds: 170),
  RitualAtmosphereTone.groundedSoothing =>
    const Duration(milliseconds: 250),
  RitualAtmosphereTone.bedtimeQuiet =>
    const Duration(milliseconds: 300),
};
final sentenceDuration = reduceMotion
    ? const Duration(milliseconds: 80)
    : atmosphereMotionDuration;
```

When reduced motion is enabled, use `FadeTransition` only; do not translate,
scale, or slide.

- [x] **Step 7: Run tests**

Run the command from Step 2.

Expected: PASS; no old identity/card component remains in the harness.

- [x] **Step 8: Commit**

```powershell
git add -- mobile_v2
git commit -m "feat(42): add sentence light field components"
```

---

## Task 7: Replace the modal reaction sheet with a local non-modal Dock

**Scope:** Phase 42 required

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_dock.dart`
- Create: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_choices.dart`
- Create: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_transient_notice.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart`

- [x] **Step 1: Write failing Dock tests**

Cover:

```dart
expect(find.byKey(const Key('ritual-context-dock-collapsed')), findsOneWidget);
expect(find.text('还不想穿'), findsNothing);
expect(find.byType(ModalBarrier), findsNothing);
expect(find.byKey(const Key('ritual-reaction-sheet')), findsNothing);
```

After tapping the entry:

```dart
expect(find.byKey(const Key('ritual-context-dock-expanded')), findsOneWidget);
expect(find.text('还不想穿'), findsOneWidget);
expect(find.text('想自己来'), findsOneWidget);
expect(find.byType(ModalBarrier), findsNothing);
```

During submitting:

```dart
expect(choice.onPressed, isNull);
expect(collapse.onPressed, isNotNull);
expect(quietExit.onPressed, isNotNull);
```

- [x] **Step 2: Run tests and verify failure**

```powershell
flutter test `
  test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart
```

Expected: FAIL because the Dock does not exist and the old widget opens a modal.

- [x] **Step 3: Implement immutable Dock inputs**

```dart
enum RitualDockRequestStatus {
  idle,
  submitting,
  recoverableFailure,
  unknownOutcome,
  reconciling,
}

final class RitualContextDock extends StatelessWidget {
  const RitualContextDock({
    super.key,
    required this.expanded,
    required this.requestStatus,
    required this.prompt,
    required this.reassurance,
    required this.quietExitLabel,
    required this.choices,
    required this.selectedReactionId,
    required this.notice,
    required this.onToggleExpanded,
    required this.onReactionSelected,
    required this.onReconcileUnknown,
    required this.onQuietExit,
  });

  final bool expanded;
  final RitualDockRequestStatus requestStatus;
  final String prompt;
  final String reassurance;
  final String quietExitLabel;
  final List<RitualReactionChoice> choices;
  final String? selectedReactionId;
  final String? notice;
  final ValueChanged<bool> onToggleExpanded;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback? onReconcileUnknown;
  final VoidCallback onQuietExit;
}
```

`RitualContextDock` owns no repository or provider. It receives values and
callbacks only. It reads generic entry/collapse/retry labels from
`AppLocalizations`; ritual prompt, reassurance, quiet-exit copy, and choices
come from `RitualRoomContent`.

`RitualContextChoices` has this focused API:

```dart
final class RitualContextChoices extends StatelessWidget {
  const RitualContextChoices({
    super.key,
    required this.choices,
    required this.enabled,
    required this.selectedReactionId,
    required this.onSelected,
  });

  final List<RitualReactionChoice> choices;
  final bool enabled;
  final String? selectedReactionId;
  final ValueChanged<String> onSelected;
}
```

Recoverable failure does not retain a private command and therefore does not
call `onReconcileUnknown`; the parent may select a context again. Only
`unknownOutcome` exposes original-event reconciliation.

- [x] **Step 4: Implement the collapsed and expanded layouts**

Collapsed:

- one 48dp entry row
- root key `Key('ritual-context-dock-collapsed')`
- entry key `Key('ritual-context-entry')`
- `OrdinalSortKey(5)`
- no visible choices
- no arrow animation

Expanded:

- root key `Key('ritual-context-dock-expanded')`
- prompt and low-pressure helper
- choices rendered by `RitualContextChoices`
- internal `SingleChildScrollView` only when constraints require it
- `收起` and `先这样就好` remain enabled
- no modal route, barrier, drag handle, or screen dimming

Quiet exit has `OrdinalSortKey(6)`.

- [x] **Step 5: Implement transient notices**

```dart
final class RitualTransientNotice extends StatelessWidget {
  const RitualTransientNotice({
    super.key,
    required this.message,
    this.liveRegion = true,
    this.onRetry,
  });
}
```

Use:

```dart
Semantics(
  liveRegion: liveRegion,
  container: true,
  child: Text(message),
)
```

Do not use `FocusNode`, `requestFocus`, `FocusScope`, or
`SemanticsService.sendAnnouncement`.

- [x] **Step 6: Run tests**

Run the command from Step 2.

Expected: PASS; modal widgets and old sheet keys are absent.

- [x] **Step 7: Commit**

```powershell
git add -- mobile_v2
git commit -m "feat(42): add non modal ritual context dock"
```

---

## Task 8: Recompose `RitualRoomScreen` as one stable Room loop

**Scope:** Phase 42 required

**Files:**

- Modify: `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart`
- Modify: `mobile_v2/lib/app/baby_talk_app.dart`
- Modify: `mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`

- [ ] **Step 1: Write failing screen-state and geometry tests**

At both viewport sizes, record the sentence-plane rectangle before and after
Dock expansion:

```dart
final before = tester.getRect(
  find.byKey(const Key('ritual-sentence-plane')),
);
await tester.tap(find.byKey(const Key('ritual-context-entry')));
await tester.pumpAndSettle();
final after = tester.getRect(
  find.byKey(const Key('ritual-sentence-plane')),
);
expect(after, before);
```

Add tests that:

- submitting preserves the old sentence
- unknown outcome preserves the old sentence and exposes reconciliation retry
- recoverable failure preserves the old sentence
- collapsing during a pending request does not cancel the eventual update
- Android back collapses the Dock first
- `先这样就好` creates no SnackBar, navigation, completion, save, or external
  callback
- source contains no `requestFocus`, `FocusScope`, or semantic announcement API

- [ ] **Step 2: Run tests and verify failure**

```powershell
flutter test `
  test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
```

Expected: FAIL because the current screen uses a scrolling list/modal sheet and
the app shows a SnackBar.

- [ ] **Step 3: Convert the screen to local ephemeral state**

Use a `StatefulWidget` only for:

```dart
bool _dockExpanded = false;
```

Do not store room, snapshot, revision, selected reaction, error, or request
status in widget state.

- [ ] **Step 4: Use `PopScope` for Android back**

```dart
PopScope(
  canPop: !_dockExpanded,
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop && _dockExpanded) {
      setState(() => _dockExpanded = false);
    }
  },
  child: room,
)
```

Do not request accessibility focus after collapse.

- [ ] **Step 5: Project request status without duplicating product truth**

Derive locally:

```dart
final requestStatus = switch (state) {
  RitualRoomSubmitting() => RitualDockRequestStatus.submitting,
  RitualRoomUnknownOutcome(:final isRetrying) =>
    isRetrying
      ? RitualDockRequestStatus.reconciling
      : RitualDockRequestStatus.unknownOutcome,
  RitualRoomRecoverableFailure() =>
    RitualDockRequestStatus.recoverableFailure,
  _ => RitualDockRequestStatus.idle,
};
```

Keep `snapshot = state.snapshot!` as the only sentence truth.

- [ ] **Step 6: Build the stable geometry**

Use:

```dart
Scaffold(
  key: const Key('ritual-room-root'),
  body: SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: RitualAtmosphereLayer(
                  illustration: room.illustration,
                  tone: room.atmosphereTone,
                  roomName: room.roomName,
                ),
              ),
              Positioned.fill(
                child: _RitualSemanticContent(
                  state: state,
                  dockExpanded: _dockExpanded,
                  onDockExpandedChanged: (expanded) {
                    setState(() => _dockExpanded = expanded);
                  },
                  onReactionSelected: onReactionSelected,
                  onRetryPendingEvent: onRetryPendingEvent,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
)
```

`_RitualSemanticContent` is one linear semantic tree: sentence plane, flexible
space, Dock. The decorative layer is excluded.

- [ ] **Step 7: Replace initial full-screen spinner**

For idle/loading, preserve the same geometry and show:

```dart
Semantics(
  liveRegion: true,
  child: Text(copy.loadingSentence),
)
```

Do not render a full-screen centered `CircularProgressIndicator` or a skeleton
sentence.

- [ ] **Step 8: Remove app-owned quiet-exit feedback**

Delete `_messengerKey`, `scaffoldMessengerKey`, the SnackBar, and the
`onQuietExit` callback from `BabyTalkApp` and `RitualRoomScreen`.

Quiet exit is now local Dock collapse/dismiss behavior only.

- [ ] **Step 9: Run tests**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 10: Commit**

```powershell
git add -- mobile_v2
git commit -m "feat(42): recompose ritual room loop"
```

---

## Task 9: Make audio presentation truthful without shipping a no-op

**Scope:** Phase 42 required presentation contract; real playback deferred

**Files:**

- Create: `mobile_v2/lib/features/ritual_room/presentation/models/ritual_listen_state.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_listen_control.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_sentence_plane.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart`

- [ ] **Step 1: Add failing state and semantics tests**

```dart
expect(
  find.bySemanticsLabel('播放这句话'),
  findsOneWidget,
);
expect(
  find.bySemanticsLabel('暂停播放'),
  findsOneWidget,
);
expect(
  find.bySemanticsLabel('正在加载语音'),
  findsOneWidget,
);
expect(find.text('暂时听不了，你也可以直接照着说。'), findsOneWidget);
```

Also assert that production fixture `available: false` does not expose an
enabled no-op callback.

- [ ] **Step 2: Verify the presentation-state contract created in Task 6**

```dart
sealed class RitualListenState {
  const RitualListenState();
}

final class RitualListenUnavailable extends RitualListenState {
  const RitualListenUnavailable();
}

final class RitualListenReady extends RitualListenState {
  const RitualListenReady();
}

final class RitualListenLoading extends RitualListenState {
  const RitualListenLoading();
}

final class RitualListenPlaying extends RitualListenState {
  const RitualListenPlaying();
}

final class RitualListenPaused extends RitualListenState {
  const RitualListenPaused();
}

final class RitualListenFailure extends RitualListenState {
  const RitualListenFailure();
}
```

Do not add playback position, duration, waveform, or platform-player state to
this presentation union.

- [ ] **Step 3: Render state truthfully**

- unavailable: visible low-pressure unavailable copy; no enabled button
- ready: play icon + `听一下`
- loading: small progress ring in icon slot; semantics says loading
- playing: pause icon + `暂停`
- paused: play icon + `听一下`
- failure: keep sentence and show the local failure copy

Do not add waveform, duration, progress bar, or player panel.

- [ ] **Step 4: Keep production unavailable until a real adapter exists**

In the first merge:

```dart
final listenState = room.audio.available
    ? const RitualListenReady()
    : const RitualListenUnavailable();
```

If `available` is true but no real callback is injected, fail closed by rendering
unavailable; do not pass `() {}`.

- [ ] **Step 5: Run tests**

```powershell
flutter test `
  test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart `
  test/features/ritual_room/presentation/ritual_room_accessibility_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add -- mobile_v2
git commit -m "feat(42): add truthful ritual audio states"
```

---

## Task 10: Lock TalkBack order, non-stealing focus, scaling, and reduced motion

**Scope:** Phase 42 required

**Files:**

- Modify: `mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart`
- Modify: `mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`

- [ ] **Step 1: Add semantic sort-order assertions**

For the six stable nodes, assert:

```dart
expect(
  tester.getSemantics(find.byKey(const Key('ritual-primary-sentence')))
      .getSemanticsData()
      .sortKey,
  const OrdinalSortKey(1),
);
expect(
  tester.getSemantics(find.byKey(const Key('ritual-zh-support')))
      .getSemanticsData()
      .sortKey,
  const OrdinalSortKey(2),
);
```

Continue through action timing `3`, listen `4`, context entry `5`, quiet exit
`6`.

- [ ] **Step 2: Add a no-forced-focus source contract**

```dart
final source = File(
  'lib/features/ritual_room/presentation/screens/ritual_room_screen.dart',
).readAsStringSync();

for (final forbidden in [
  'requestFocus(',
  'FocusScope.of(',
  'SemanticsService.',
  'sendAnnouncement',
]) {
  expect(source, isNot(contains(forbidden)));
}
```

This does not replace real TalkBack UAT; it prevents accidental default focus
stealing.

- [ ] **Step 3: Add one-shot live-region tests**

Pump submitting → ready and unknown → reconciling → ready. Verify:

- only the transient notice is a live region
- the primary sentence is not converted into a persistent live region
- notices disappear after their intended state
- widget focus is not moved programmatically

- [ ] **Step 4: Test viewport and text-scale matrix**

Use:

```dart
const viewports = [
  Size(427, 952),
  Size(390, 844),
];
const scales = [1.0, 1.3, 2.0];
```

For each pair, pump with:

```dart
tester.view.devicePixelRatio = 1;
tester.view.physicalSize = viewport;
await tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(
      size: viewport,
      textScaler: TextScaler.linear(scale),
    ),
    child: app,
  ),
);
```

At 1.0 and 1.3:

- all six primary elements render
- no overflow exception
- 48dp targets remain
- Dock does not overlap the sentence plane

At 2.0:

- vertical scrolling is allowed
- all elements remain reachable
- no horizontal overflow

- [ ] **Step 5: Test reduced motion**

Pump with:

```dart
MediaQuery(
  data: const MediaQueryData(disableAnimations: true),
  child: app,
)
```

Assert sentence replacement settles within 100ms and no slide transition is
present.

- [ ] **Step 6: Run tests**

```powershell
flutter test `
  test/features/ritual_room/presentation/ritual_room_accessibility_test.dart `
  test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add -- mobile_v2
git commit -m "test(42): lock ritual room accessibility"
```

---

## Task 11: Add dual-viewport visual regression coverage

**Scope:** Phase 42 required

**Files:**

- Create: `mobile_v2/test/helpers/ritual_room_test_harness.dart`
- Create: `mobile_v2/test/features/ritual_room/presentation/ritual_room_golden_test.dart`
- Create: `mobile_v2/test/goldens/ritual_room/*.png`

- [ ] **Step 1: Extract deterministic test builders**

The harness must provide:

```dart
Widget ritualRoomHarness({
  required Size viewport,
  required RitualRoomUiState state,
  double textScale = 1,
  bool disableAnimations = true,
});

Future<void> pumpRitualRoomGolden(
  WidgetTester tester, {
  required Size viewport,
  required RitualRoomUiState state,
  double textScale = 1,
  bool expandDock = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  await tester.pumpWidget(
    ritualRoomHarness(
      viewport: viewport,
      state: state,
      textScale: textScale,
    ),
  );
  if (expandDock) {
    await tester.tap(find.byKey(const Key('ritual-context-entry')));
    await tester.pumpAndSettle();
  }
}
```

Use only safe synthetic household data. Do not import mock APIs or DTOs into
presentation tests.

- [ ] **Step 2: Add golden cases**

For both `427×952` and `390×844`, capture:

- ready/collapsed
- Dock expanded
- submitting
- revised
- recoverable failure
- unknown outcome
- audio unavailable/failure
- 1.3 text scale
- reduced motion final frame

Test naming:

```dart
await expectLater(
  find.byKey(const Key('ritual-room-root')),
  matchesGoldenFile(
    'test/goldens/ritual_room/ready_427x952.png',
  ),
);
```

- [ ] **Step 3: Generate baselines**

```powershell
flutter test `
  test/features/ritual_room/presentation/ritual_room_golden_test.dart `
  --update-goldens
```

Expected: PNG files are generated.

- [ ] **Step 4: Perform mandatory human visual review**

Reject a baseline if any image shows:

- AppBar
- card border/shadow around the sentence
- modal barrier or bottom sheet
- illustration entering the sentence reading zone
- strong teal/orange CTA
- sentence losing first visual priority
- extra content on the taller viewport
- missing Chinese, timing, context entry, or quiet exit on compact

- [ ] **Step 5: Run goldens without update**

```powershell
flutter test `
  test/features/ritual_room/presentation/ritual_room_golden_test.dart
```

Expected: PASS with no changed pixels in the approved environment.

- [ ] **Step 6: Commit**

```powershell
git add -- mobile_v2/test
git commit -m "test(42): add ritual room visual baselines"
```

---

## Task 12: Remove obsolete D.4.5 presentation code

**Scope:** Phase 42 required, after Tasks 6–11 pass

**Files:**

- Delete: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_identity_header.dart`
- Delete: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_current_utterance.dart`
- Delete: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart`
- Delete: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_reassurance.dart`
- Delete: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_submitting_indicator.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart`
- Modify: `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json`
- Modify: imports/tests that reference them

- [ ] **Step 1: Verify replacement coverage exists**

```powershell
rg -n `
  "RitualAtmosphereLayer|RitualSentencePlane|RitualContextDock|RitualTransientNotice" `
  mobile_v2/lib mobile_v2/test
```

Expected: each new component has production and test references.

- [ ] **Step 2: Delete obsolete files**

Use `apply_patch` deletions. Do not keep wrappers or deprecated aliases; they
would preserve the old card/modal vocabulary.

- [ ] **Step 3: Remove the migrated room-level action cue**

Delete top-level `actionCue` from `RitualRoomContent`, top-level `action_cue`
from `RitualRoomResponse` and `shoes_on.json`, and the matching mapper field.
The only visible timing source must be:

```dart
snapshot.activeUtterance.actionCue
```

Update content DTO/mapper tests to prove each active utterance still owns a
non-empty timing cue.

- [ ] **Step 4: Prove the modal/card vocabulary and duplicate timing truth are gone**

```powershell
rg -n `
  "showModalBottomSheet|ritual-reaction-sheet|RitualIdentityHeader|RitualCurrentUtterance|RitualContextInputTray|RitualReassurance|RitualSubmittingIndicator|room\\.actionCue" `
  mobile_v2/lib mobile_v2/test
```

Expected: no matches.

- [ ] **Step 5: Run content and presentation tests**

```powershell
flutter test `
  test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart `
  test/features/ritual_room/presentation
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add -- mobile_v2
git commit -m "refactor(42): remove d4.5 ritual projection"
```

---

## Task 13: Extend the semantic firewall with isolated negative fixtures

**Scope:** Phase 42 required

**Files:**

- Modify: `tool/verify_mobile_v2_semantic_firewall.dart`
- Create: `test/fixtures/mobile_v2_semantic_firewall/negative/forbidden_runtime_terms.txt`
- Test: `test/tool/verify_mobile_v2_semantic_firewall_test.dart`

- [ ] **Step 1: Add failing verifier tests**

Cover:

1. a banned term in `mobile_v2/lib` blocks
2. the same term in the isolated negative fixture is allowed as test evidence
3. the negative fixture path is never treated as runtime
4. banned product semantics in normal `mobile_v2/assets/fixtures` block
5. ordinary `mobile_v2/test/fixtures` are not a blanket allowlist

- [ ] **Step 2: Expand the runtime banned vocabulary**

Add exact runtime phrases or stems covering:

```dart
const mobileV2BannedRuntimeTerms = <String>[
  'phraseId',
  'activityId',
  'completedPhrase',
  'completedPhraseCount',
  'completedPhraseIds',
  'nextPhraseId',
  'currentStreakDays',
  'streak',
  'GardenGrowth',
  'starterPhraseId',
  '下一句',
  '继续下一句',
  '完成练习',
  '今日任务',
  '打卡成功',
  '宝宝学会了吗',
  '积分',
  '连胜',
  '成长值',
];
```

Do not ban generic implementation words such as `complete` globally; that would
create false positives in tests and async APIs.

- [ ] **Step 3: Narrow fixture policy and add an explicit negative-fixture prefix**

```dart
const _negativeFixturePrefixes = <String>[
  'test/fixtures/mobile_v2_semantic_firewall/negative/',
];
```

Remove `mobile_v2/test/fixtures/` from `_allowlistedReferencePrefixes`.

Scan:

- `mobile_v2/lib/**/*.dart` as runtime code
- `mobile_v2/assets/fixtures/**/*.{json,yaml,yml}` as normal runtime content
- only `_negativeFixturePrefixes` as intentional verifier evidence

The negative fixture is never runtime or normal product content.

- [ ] **Step 4: Run verifier tests and CLI**

```powershell
dart test test/tool/verify_mobile_v2_semantic_firewall_test.dart
dart run tool/verify_mobile_v2_semantic_firewall.dart
```

Expected: tests PASS; CLI reports zero runtime violations and records isolated
negative evidence.

- [ ] **Step 5: Commit**

```powershell
git add -- tool test
git commit -m "test(42): harden ritual semantic firewall"
```

---

## Task 14: Run Phase 42 Android UAT

**Scope:** Phase 42 required human/device gate

**Files:**

- Create: `.planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-UAT.md`
- Store reviewed screenshots under:
  `artifacts/phase-42/ritual-room/`

- [ ] **Step 1: Build and launch on the Pixel 9 Pro emulator**

From `mobile_v2`:

```powershell
flutter devices
flutter run -d <pixel-9-pro-device-id>
```

Confirm Flutter reports a logical content viewport of `427×952dp` after
SafeArea/system insets are accounted for.

- [ ] **Step 2: Execute the main viewport checklist**

Record PASS/FAIL for:

1. English sentence is the first visual focus.
2. Edge illustration does not enter the sentence static zone.
3. Taller space adds breathing room only.
4. Dock expansion does not move, cover, or dim the sentence.
5. Submitting, recoverable failure, and unknown outcome preserve the sentence.
6. Unknown retry reconciles the original event ID and does not double-advance.
7. `先这样就好` only collapses/dismisses auxiliary UI.
8. No SnackBar, completion message, route change, or history appears.

- [ ] **Step 3: Execute compact viewport validation**

Use an emulator/profile with `390×844dp` logical viewport. Confirm:

- decoration contracts before content
- English, Chinese, timing, listening state, context entry, and quiet exit remain
- all touch targets remain at least 48dp
- no horizontal overflow

- [ ] **Step 4: Execute TalkBack UAT**

With TalkBack enabled:

1. Traverse in order: English → Chinese → timing → listen → context → quiet exit.
2. Expand and collapse the Dock.
3. Submit a context and let the sentence update.
4. Confirm live-region status is announced once.
5. Confirm focus does not jump automatically to the top or sentence.
6. Continue naturally to the new sentence.
7. Trigger unknown result and reconciliation.
8. Confirm retry remains reachable while collapse/back remain available.

- [ ] **Step 5: Execute text scaling and reduced motion**

Android settings:

- font scale equivalent to 1.3 and 2.0
- remove animations/reduced motion enabled

Confirm the approved contract and capture screenshots.

- [ ] **Step 6: Write UAT evidence**

`42-UAT.md` must include:

- device/emulator ID
- Android version
- Flutter build commit
- logical viewport
- text scale
- reduced-motion setting
- screenshot paths
- each result and issue link

Do not mark UAT passed from widget tests alone.

- [ ] **Step 7: Commit UAT evidence**

```powershell
git add -- `
  .planning/phases/42-mobile-v2-low-pressure-interaction-schematic/42-UAT.md `
  artifacts/phase-42/ritual-room
git commit -m "test(42): record ritual room android uat"
```

---

## Task 15: Final verification and handoff

**Scope:** Phase 41/42 required release gate

**Files:** no new production files

- [ ] **Step 1: Run formatting**

From `mobile_v2`:

```powershell
dart format --output=none --set-exit-if-changed .
```

Expected: exit 0, no changed files.

- [ ] **Step 2: Run analyze and complete tests**

```powershell
flutter analyze
flutter test
```

Expected: no analyzer issues; all tests PASS.

- [ ] **Step 3: Run semantic and governance gates from repository root**

```powershell
dart run tool/verify_mobile_v2_semantic_firewall.dart
dart run tool/verify_activation_governor_contract.dart
```

Expected: both PASS with zero violations.

- [ ] **Step 4: Run source-boundary checks**

```powershell
rg -n `
  "showModalBottomSheet|SnackBar|requestFocus\\(|FocusScope\\.of\\(|SemanticsService\\.|RitualIdentityHeader|RitualContextInputTray" `
  mobile_v2/lib
```

Expected: no matches.

```powershell
rg -n `
  "package:flutter_riverpod|dto/|mock_ritual|assets/fixtures" `
  mobile_v2/lib/features/ritual_room/presentation
```

Expected: no matches.

- [ ] **Step 5: Verify git state**

```powershell
git status --short
git log --oneline -15
```

Expected: clean worktree and one focused commit per completed task.

- [ ] **Step 6: Completion statement**

Only claim completion if automated verification and `42-UAT.md` both pass.
Report real audio and hidden input controls as deferred, not silently complete.

---

## Dependency and sequencing summary

```text
Task 1 Phase 41 authority rebaseline
  ↓
Tasks 2–3 atomic utterance timing bridge
  ↓
Tasks 4–5 tokens + localization
  ↓
Task 6 atmosphere + sentence plane
  ↓
Task 7 non-modal Dock
  ↓
Tasks 8–10 screen loop + truthful audio state + accessibility
  ↓
Task 11 visual baselines
  ↓
Tasks 12–13 old-code removal + semantic firewall
  ↓
Task 14 Android UAT
  ↓
Task 15 final verification
```

Do not parallelize Tasks 2 and 3 because they modify the same utterance contract.
Tasks 4 and 5 may run in parallel after Task 3. Tasks 6 and 7 may run in parallel
only if their public APIs are frozen first and they have disjoint write sets.

## Acceptance boundary

The implementation is accepted only when this remains true in the running
Android app:

> 父母在真实育儿时刻打开这里，不需要学习界面，也不需要证明什么；
> 第一眼就得到一句现在能够对宝宝说的话。

The plan intentionally does not authorize a real audio dependency, visible
voice/free-text/strategy controls, production Garden state, or additional
illustration generation.
