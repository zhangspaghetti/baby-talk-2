# Phase 41 Device UAT Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a real, device-verifiable `READY → SUBMITTING → result not confirmed → exact-event retry → duplicate reconciliation → REVISED` Ritual Room flow at `427×952dp`, with active-utterance-bound local audio and a release-inaccessible UAT harness.

**Architecture:** Replace the snapshot's generic `utterance` projection with one presentation-safe `activeUtterance` identity sourced from validated ritual content. Add a bundled-audio port/adapter and a debug/profile-only `InteractionApi` decorator that delays or discards a real committed response without fabricating snapshots. Rebuild the Ritual Room around D.4.5 geometry, keeping the existing `RitualRoomSessionNotifier` as the sole mutable product-session authority.

**Tech Stack:** Flutter 3 / Dart 3, Riverpod 3.3, Material 3, `audioplayers` 6.5, Flutter widget/integration tests, Android ADB/TalkBack.

**Design source:** `docs/superpowers/specs/2026-06-22-phase-41-device-uat-completion-design.md`

---

## File Structure

### Domain and transport identity

- Create `mobile_v2/lib/features/ritual_room/domain/models/active_utterance.dart` — immutable current user-visible utterance identity.
- Create `mobile_v2/lib/features/ritual_room/domain/repositories/active_utterance_source.dart` — content-owned lookup seam used by seed and realization.
- Delete `mobile_v2/lib/features/ritual_room/domain/models/utterance.dart` after all callers migrate.
- Modify `mobile_v2/lib/features/ritual_room/domain/models/product_snapshot.dart` — expose `activeUtterance` as the only current utterance.
- Modify engine/runtime/DTO/mapper files so active utterance survives commit, replay, and transport.

### Stable content and audio catalog

- Modify `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json` — locked READY/REVISED utterances and opaque audio catalog.
- Add `mobile_v2/assets/audio/ritual_room/shoes_on/rr_shoes_001.mp3`.
- Add `mobile_v2/assets/audio/ritual_room/shoes_on/rr_shoes_002.mp3`.
- Modify ritual content DTO/domain/mapper/repository files — validate, cache, and privately resolve active utterances and audio references.
- Modify `mobile_v2/pubspec.yaml` — register the audio asset directory and add `audioplayers`.

### Audio playback

- Create `mobile_v2/lib/features/ritual_room/domain/audio/audio_playback_port.dart`.
- Create `mobile_v2/lib/features/ritual_room/data/audio/bundled_ritual_audio_playback.dart`.
- Create `mobile_v2/lib/features/ritual_room/presentation/audio/ritual_audio_controller.dart`.
- Create `mobile_v2/lib/app/providers/ritual_audio_providers.dart`.

### UAT harness

- Create `mobile_v2/lib/app/uat/phase41_uat_config.dart`.
- Create `mobile_v2/lib/app/uat/uat_interaction_mode_controller.dart`.
- Create `mobile_v2/lib/features/ritual_room/data/datasources/uat_interaction_api_decorator.dart`.
- Create `mobile_v2/lib/app/uat/uat_overlay_host.dart`.
- Modify provider composition and `BabyTalkApp` to select the decorator and overlay only under the compile-time gate.

### D.4.5 presentation and accessibility

- Modify `ritual_room_screen.dart`, identity, current utterance, listen, reaction, reassurance, and submitting widgets.
- Create `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_recovery_notice.dart`.
- Create `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_utterance_card.dart`.

### Verification and evidence

- Add focused domain/content/audio/UAT/widget tests.
- Add `mobile_v2/integration_test/phase41_device_uat_test.dart`.
- Add `scripts/verify-phase41-release-uat-gate.ps1`.
- Update `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-UAT.md` only after device evidence is collected.

---

### Task 1: Introduce `ProductSnapshot.activeUtterance`

**Files:**
- Create: `mobile_v2/lib/features/ritual_room/domain/models/active_utterance.dart`
- Create: `mobile_v2/lib/features/ritual_room/domain/repositories/active_utterance_source.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/models/product_snapshot.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_seed_source.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_session_initializer.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/runtime/interaction_runtime_state.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/runtime/replay_journal.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/engine/utterance_engine.dart`
- Modify: `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json`
- Modify: `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/repositories/ritual_room_repository.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/repositories/ritual_room_repository_impl.dart`
- Modify: `mobile_v2/lib/app/providers/interaction_engine_providers.dart`
- Modify: `mobile_v2/test/fixtures/interaction_test_fixtures.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/models/interaction_contract_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/engine/utterance_engine_test.dart`
- Test: `mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_replay_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/repositories/ritual_room_repository_test.dart`

- [ ] **Step 1: Write failing active-utterance contract tests**

Add assertions that the snapshot has exactly one current utterance field and that the accepted reaction resolves the locked revised identity:

```dart
test('snapshot owns one presentation-safe active utterance identity', () {
  final snapshot = interactionSnapshot();
  final source = File(
    'lib/features/ritual_room/domain/models/product_snapshot.dart',
  ).readAsStringSync();

  expect(snapshot.activeUtterance.displayId, 'shoes_on_ready_v1');
  expect(snapshot.activeUtterance.primary, "Let’s put your shoes on.");
  expect(snapshot.activeUtterance.zhSupport, '我们来穿鞋吧。');
  expect(snapshot.activeUtterance.audioAssetId, 'rr_shoes_001');
  expect(source, contains('final ActiveUtterance activeUtterance;'));
  expect(source, isNot(contains('final Utterance utterance;')));
});

test('not-ready context resolves the locked revised utterance', () async {
  final source = _FakeActiveUtteranceSource();
  final engine = RuleBasedUtteranceEngine(source: source);

  final result = await engine.realize(
    ritualRoomId: ritualRoomId,
    strategy: interactionStrategy(),
    normalized: interactionNormalizedInput('low_joinability'),
    memory: interactionMemory('low_joinability'),
  );

  expect(result.displayId, 'shoes_on_revised_wait_v1');
  expect(result.primary, "You don’t want your shoes on yet.");
  expect(result.zhSupport, '你现在还不想穿鞋。');
  expect(result.audioAssetId, 'rr_shoes_002');
});
```

Add `import 'dart:io';` to the contract test for the structural source assertion.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/domain/models/interaction_contract_test.dart `
  test/features/ritual_room/domain/engine/utterance_engine_test.dart `
  test/features/ritual_room/domain/engine/interaction_engine_replay_test.dart
```

Expected: FAIL because `ActiveUtterance`, `activeUtterance`, and `ActiveUtteranceSource` do not exist.

- [ ] **Step 3: Add the immutable model and lookup seam**

Create `active_utterance.dart`:

```dart
final class ActiveUtterance {
  const ActiveUtterance({
    required this.displayId,
    required this.primary,
    required this.zhSupport,
    required this.audioAssetId,
    this.contextLabel,
    this.gentleSupport,
  });

  final String displayId;
  final String primary;
  final String zhSupport;
  final String audioAssetId;
  final String? contextLabel;
  final String? gentleSupport;
}

enum ActiveUtteranceSlot { ready, notReadyYet }
```

Create `active_utterance_source.dart`:

```dart
import '../models/active_utterance.dart';

abstract interface class ActiveUtteranceSource {
  Future<ActiveUtterance> resolveActiveUtterance({
    required String ritualRoomId,
    required ActiveUtteranceSlot slot,
  });
}
```

- [ ] **Step 4: Migrate snapshot, engine, seed, runtime, and replay**

Change `ProductSnapshot` and `ProductSnapshot.initial` to require:

```dart
required this.activeUtterance,
final ActiveUtterance activeUtterance;
```

Change `InteractionSeed.utterance` to:

```dart
final ActiveUtterance activeUtterance;
```

Change `UtteranceEngine` to:

```dart
abstract interface class UtteranceEngine {
  Future<ActiveUtterance> realize({
    required String ritualRoomId,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  });
}

final class RuleBasedUtteranceEngine implements UtteranceEngine {
  const RuleBasedUtteranceEngine({required ActiveUtteranceSource source})
    : _source = source;

  final ActiveUtteranceSource _source;

  @override
  Future<ActiveUtterance> realize({
    required String ritualRoomId,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  }) {
    final slot =
        normalized.semanticSignals.contains('low_joinability') ||
            normalized.semanticSignals.contains('avoidance')
        ? ActiveUtteranceSlot.notReadyYet
        : ActiveUtteranceSlot.ready;
    return _source.resolveActiveUtterance(
      ritualRoomId: ritualRoomId,
      slot: slot,
    );
  }
}
```

In `InteractionEngine`, pass `current.snapshot.ritualRoomId`, assign `activeUtterance`, and record `activeUtterance` in `TransitionRecord`. Replay must restore the recorded active utterance directly without invoking the source.

- [ ] **Step 5: Add fixture-owned active utterance lookup**

Add this section to `shoes_on.json` while leaving room-level audio cleanup to Task 3:

```json
"listen_label": "听一遍",
"active_utterances": {
  "ready": {
    "display_id": "shoes_on_ready_v1",
    "primary": "Let’s put your shoes on.",
    "zh_support": "我们来穿鞋吧。",
    "audio_asset_id": "rr_shoes_001"
  },
  "not_ready_yet": {
    "display_id": "shoes_on_revised_wait_v1",
    "primary": "You don’t want your shoes on yet.",
    "zh_support": "你现在还不想穿鞋。",
    "context_label": "还不想穿",
    "gentle_support": "可以先等等。",
    "audio_asset_id": "rr_shoes_002"
  }
}
```

Remove the legacy `bootstrap_utterance` object and `RitualBootstrapUtterance` DTO/domain field. `RitualRoomInteractionSeedSource` must obtain revision-zero content through:

```dart
final activeUtterance = await _repository.resolveActiveUtterance(
  ritualRoomId: ritualRoomId,
  slot: ActiveUtteranceSlot.ready,
);
```

Extend `RitualRoomRepository`:

```dart
abstract interface class RitualRoomRepository
    implements ActiveUtteranceSource {
  Future<RitualRoomContent> loadRoom(String ritualRoomId);
}
```

Map the two private fixture keys to `ActiveUtteranceSlot.ready` and `ActiveUtteranceSlot.notReadyYet`. Cache the mapped response per room in `RitualRoomRepositoryImpl`; `loadRoom` and `resolveActiveUtterance` must share the same cached bundle.

Update `interaction_engine_providers.dart`:

```dart
final utteranceEngineProvider = Provider<UtteranceEngine>(
  (ref) => RuleBasedUtteranceEngine(
    source: ref.watch(ritualRoomRepositoryProvider),
  ),
);
```

- [ ] **Step 6: Update fixtures and all domain tests**

Replace `interactionUtterance()` with:

```dart
ActiveUtterance interactionActiveUtterance({
  String displayId = 'shoes_on_ready_v1',
  String primary = "Let’s put your shoes on.",
  String zhSupport = '我们来穿鞋吧。',
  String audioAssetId = 'rr_shoes_001',
  String? contextLabel,
  String? gentleSupport,
}) => ActiveUtterance(
  displayId: displayId,
  primary: primary,
  zhSupport: zhSupport,
  audioAssetId: audioAssetId,
  contextLabel: contextLabel,
  gentleSupport: gentleSupport,
);
```

Update all references from `.utterance` to `.activeUtterance`, and remove imports of `utterance.dart`.

- [ ] **Step 7: Run domain, engine, and content tests**

Run:

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/domain/models `
  test/features/ritual_room/domain/engine `
  test/features/ritual_room/domain/runtime `
  test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart `
  test/features/ritual_room/data/repositories/ritual_room_repository_test.dart
```

Expected: PASS, including replay proving the active utterance is replayed from recorded output.

- [ ] **Step 8: Commit**

```powershell
git add mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json mobile_v2/lib/features/ritual_room/domain mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart mobile_v2/lib/features/ritual_room/data/repositories/ritual_room_repository_impl.dart mobile_v2/lib/app/providers/interaction_engine_providers.dart mobile_v2/test/features/ritual_room/domain mobile_v2/test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart mobile_v2/test/features/ritual_room/data/repositories/ritual_room_repository_test.dart mobile_v2/test/fixtures/interaction_test_fixtures.dart
git commit -m "refactor(41): make active utterance snapshot truth"
```

---

### Task 2: Carry active utterance through DTO and repository mapping

**Files:**
- Modify: `mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/mappers/interaction_mapper.dart`
- Modify: `mobile_v2/test/features/ritual_room/data/mappers/interaction_mapper_test.dart`
- Modify: `mobile_v2/test/features/ritual_room/data/repositories/interaction_repository_test.dart`
- Modify: `mobile_v2/test/features/ritual_room/interaction_engine_contract_test.dart`

- [ ] **Step 1: Write failing transport round-trip tests**

Add:

```dart
test('active utterance round-trips as one transport object', () {
  final snapshot = interactionSnapshot();
  final response = mapper.snapshotFromDomain(snapshot);
  final restored = mapper.snapshotToDomain(
    InteractionSnapshotResponse.fromJson(response.toJson()),
  );

  expect(restored.activeUtterance.displayId, 'shoes_on_ready_v1');
  expect(restored.activeUtterance.primary, "Let’s put your shoes on.");
  expect(restored.activeUtterance.zhSupport, '我们来穿鞋吧。');
  expect(restored.activeUtterance.audioAssetId, 'rr_shoes_001');
  expect(response.toJson(), contains('activeUtterance'));
  expect(response.toJson(), isNot(contains('utterance')));
});
```

- [ ] **Step 2: Run mapper tests and verify RED**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/data/mappers/interaction_mapper_test.dart `
  test/features/ritual_room/data/repositories/interaction_repository_test.dart
```

Expected: FAIL because transport still uses `InteractionUtteranceResponse`.

- [ ] **Step 3: Replace transport utterance shape**

Replace `InteractionUtteranceResponse` with:

```dart
final class InteractionActiveUtteranceResponse {
  const InteractionActiveUtteranceResponse({
    required this.displayId,
    required this.primary,
    required this.zhSupport,
    required this.audioAssetId,
    this.contextLabel,
    this.gentleSupport,
  });

  factory InteractionActiveUtteranceResponse.fromJson(
    Map<String, Object?> json,
  ) => InteractionActiveUtteranceResponse(
    displayId: _requiredString(json, 'displayId'),
    primary: _requiredString(json, 'primary'),
    zhSupport: _requiredString(json, 'zhSupport'),
    audioAssetId: _requiredString(json, 'audioAssetId'),
    contextLabel: _optionalString(json, 'contextLabel'),
    gentleSupport: _optionalString(json, 'gentleSupport'),
  );

  final String displayId;
  final String primary;
  final String zhSupport;
  final String audioAssetId;
  final String? contextLabel;
  final String? gentleSupport;

  Map<String, Object?> toJson() => {
    'displayId': displayId,
    'primary': primary,
    'zhSupport': zhSupport,
    'audioAssetId': audioAssetId,
    'contextLabel': contextLabel,
    'gentleSupport': gentleSupport,
  };
}
```

Rename the top-level JSON field from `utterance` to `activeUtterance`. Update mapper conversion in both directions.

- [ ] **Step 4: Update parity and privacy assertions**

The full interaction contract must assert:

```dart
expect(direct.snapshot!.activeUtterance.audioAssetId,
    adapter.snapshot!.activeUtterance.audioAssetId);
expect(jsonEncode(response.toJson()), isNot(contains('asset_reference')));
expect(jsonEncode(response.toJson()), isNot(contains('not_ready_yet')));
```

- [ ] **Step 5: Run transport and contract tests**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/data `
  test/features/ritual_room/interaction_engine_contract_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart mobile_v2/lib/features/ritual_room/data/mappers/interaction_mapper.dart mobile_v2/test/features/ritual_room/data mobile_v2/test/features/ritual_room/interaction_engine_contract_test.dart
git commit -m "feat(41): transport active utterance identity"
```

---

### Task 3: Validate fixture-owned utterances and bundled audio catalog

**Files:**
- Modify: `mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json`
- Add: `mobile_v2/assets/audio/ritual_room/shoes_on/rr_shoes_001.mp3`
- Add: `mobile_v2/assets/audio/ritual_room/shoes_on/rr_shoes_002.mp3`
- Modify: `mobile_v2/pubspec.yaml`
- Modify: `mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/repositories/ritual_room_repository.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart`
- Modify: `mobile_v2/lib/features/ritual_room/data/repositories/ritual_room_repository_impl.dart`
- Modify: `mobile_v2/lib/features/ritual_room/domain/runtime/ritual_room_interaction_seed_source.dart`
- Test: `mobile_v2/test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/repositories/ritual_room_repository_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/datasources/mock_ritual_content_api_test.dart`

- [ ] **Step 1: Write failing fixture and fail-fast tests**

Add tests for:

```dart
test('fixture supplies locked ready and revised active utterances', () async {
  final repository = await buildRepository();

  final ready = await repository.resolveActiveUtterance(
    ritualRoomId: ritualRoomId,
    slot: ActiveUtteranceSlot.ready,
  );
  final revised = await repository.resolveActiveUtterance(
    ritualRoomId: ritualRoomId,
    slot: ActiveUtteranceSlot.notReadyYet,
  );

  expect(ready.audioAssetId, 'rr_shoes_001');
  expect(revised.audioAssetId, 'rr_shoes_002');
  expect(revised.primary, "You don’t want your shoes on yet.");
  expect(revised.contextLabel, '还不想穿');
});

test('missing acceptance audio mapping fails fast', () {
  final response = validResponseWithoutAudio('rr_shoes_002');
  expect(() => mapper.toBundle(response), throwsFormatException);
});
```

- [ ] **Step 2: Run content tests and verify RED**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/data/datasources/mock_ritual_content_api_test.dart `
  test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart `
  test/features/ritual_room/data/repositories/ritual_room_repository_test.dart
```

Expected: FAIL because the fixture has one unavailable room-level audio value.

- [ ] **Step 3: Complete the fixture with the private audio catalog**

Keep the `listen_label` and `active_utterances` added in Task 1. Remove the legacy room-level `"audio": {"available": false, ...}` object and add:

```json
"audio_assets": [
  {
    "id": "rr_shoes_001",
    "asset_reference": "assets/audio/ritual_room/shoes_on/rr_shoes_001.mp3"
  },
  {
    "id": "rr_shoes_002",
    "asset_reference": "assets/audio/ritual_room/shoes_on/rr_shoes_002.mp3"
  }
]
```

Keep `not_ready_yet` private to fixture/data lookup. Do not copy it into `ActiveUtterance`.

- [ ] **Step 4: Add the two reviewed binary audio files**

Verify the official `edge-tts` CLI syntax, then generate the Phase 41 acceptance assets with the Microsoft English neural voice:

```powershell
python -m pip install edge-tts
python -m edge_tts `
  --voice en-US-JennyNeural `
  --text "Let's put your shoes on." `
  --write-media mobile_v2/assets/audio/ritual_room/shoes_on/rr_shoes_001.mp3
python -m edge_tts `
  --voice en-US-JennyNeural `
  --text "You don't want your shoes on yet." `
  --write-media mobile_v2/assets/audio/ritual_room/shoes_on/rr_shoes_002.mp3
```

Review the generated audio before committing. The files must contain exactly:

```text
rr_shoes_001.mp3 → “Let’s put your shoes on.”
rr_shoes_002.mp3 → “You don’t want your shoes on yet.”
```

Acceptance constraints:

- spoken English is intelligible at normal device volume
- no leading spoken filename, reaction key, or metadata
- each file is under 500 KB
- both are independently playable by Android MediaPlayer/audioplayers

Verify:

```powershell
Get-Item `
  mobile_v2/assets/audio/ritual_room/shoes_on/rr_shoes_001.mp3, `
  mobile_v2/assets/audio/ritual_room/shoes_on/rr_shoes_002.mp3 |
  Select-Object Name, Length
```

Expected: two non-empty files, each below 512000 bytes.

- [ ] **Step 5: Map into a cached private bundle**

Add internal data/domain values:

```dart
final class RitualAudioAsset {
  const RitualAudioAsset({required this.id, required this.assetReference});
  final String id;
  final String assetReference;
}

final class RitualRoomBundle {
  const RitualRoomBundle({
    required this.room,
    required this.utterances,
    required this.audioAssets,
  });

  final RitualRoomContent room;
  final Map<ActiveUtteranceSlot, ActiveUtterance> utterances;
  final Map<String, RitualAudioAsset> audioAssets;
}
```

`RitualRoomContent` retains only:

```dart
final String listenLabel;
```

Remove the legacy `RitualAudioContent` class and `RitualRoomContent.audio` field completely.

Extend `RitualRoomRepository`:

```dart
abstract interface class RitualRoomRepository implements ActiveUtteranceSource {
  Future<RitualRoomContent> loadRoom(String ritualRoomId);
  Future<String> resolveAudioAssetReference(String audioAssetId);
}
```

Cache the mapped bundle per room so `loadRoom`, seed resolution, utterance resolution, and audio resolution share one fixture read.

- [ ] **Step 6: Validate paths and acceptance coverage**

`RitualRoomMapper.toBundle` must reject:

```dart
if (!asset.assetReference.startsWith(
  'assets/audio/ritual_room/shoes_on/',
)) {
  throw const FormatException('audio asset path is not canonical');
}
if (!audioAssets.containsKey(ready.audioAssetId) ||
    !audioAssets.containsKey(notReady.audioAssetId)) {
  throw const FormatException('acceptance utterance audio is incomplete');
}
```

Use an injected `AssetBundle` or asset-existence validator so tests can prove missing files fail before the room becomes ready.

- [ ] **Step 7: Register assets and dependency**

Update `mobile_v2/pubspec.yaml`:

```yaml
dependencies:
  audioplayers: ^6.5.1
  crypto: ^3.0.7
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

flutter:
  assets:
    - assets/fixtures/ritual_rooms/
    - assets/illustrations/rituals/shoes_on/
    - assets/audio/ritual_room/shoes_on/
```

Run:

```powershell
Set-Location mobile_v2
flutter pub get
flutter test --no-pub test/features/ritual_room/data
```

Expected: dependency resolution succeeds and content tests PASS.

- [ ] **Step 8: Commit**

```powershell
git add mobile_v2/assets mobile_v2/pubspec.yaml mobile_v2/pubspec.lock mobile_v2/lib/features/ritual_room/data mobile_v2/lib/features/ritual_room/domain mobile_v2/test/features/ritual_room/data
git commit -m "feat(41): add validated ritual utterance audio catalog"
```

---

### Task 4: Add audio playback port, adapter, and transient controller

**Files:**
- Create: `mobile_v2/lib/features/ritual_room/domain/audio/audio_playback_port.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/audio/bundled_ritual_audio_playback.dart`
- Create: `mobile_v2/lib/features/ritual_room/presentation/audio/ritual_audio_controller.dart`
- Create: `mobile_v2/lib/app/providers/ritual_audio_providers.dart`
- Modify: `mobile_v2/lib/app/baby_talk_app.dart`
- Test: `mobile_v2/test/features/ritual_room/data/audio/bundled_ritual_audio_playback_test.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/audio/ritual_audio_controller_test.dart`
- Test: `mobile_v2/test/app/providers/ritual_audio_providers_test.dart`

- [ ] **Step 1: Verify current official `audioplayers` asset-source API**

Before coding, check the official package documentation for version 6.5.x and confirm:

```dart
await player.play(AssetSource('audio/ritual_room/shoes_on/rr_shoes_001.mp3'));
await player.stop();
await player.dispose();
player.onPlayerComplete;
```

Record any version-specific correction in the implementation commit message body. Do not use blog or Stack Overflow examples.

- [ ] **Step 2: Write failing port/controller tests**

Use a fake that records opaque IDs:

```dart
import 'dart:async';

final class RecordingAudioPlaybackPort implements AudioPlaybackPort {
  final played = <String>[];
  final _completed = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _completed.stream;

  @override
  Future<void> play(String audioAssetId) async => played.add(audioAssetId);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _completed.close();
}

test('controller plays the active utterance audio id only', () async {
  final port = RecordingAudioPlaybackPort();
  final controller = RitualAudioController(port: port);

  await controller.play('rr_shoes_001');
  await controller.play('rr_shoes_002');

  expect(port.played, ['rr_shoes_001', 'rr_shoes_002']);
});
```

- [ ] **Step 3: Run audio tests and verify RED**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/data/audio `
  test/features/ritual_room/presentation/audio `
  test/app/providers/ritual_audio_providers_test.dart
```

Expected: FAIL because audio classes do not exist.

- [ ] **Step 4: Implement port and adapter**

Port:

```dart
abstract interface class AudioPlaybackPort {
  Stream<void> get completionStream;
  Future<void> play(String audioAssetId);
  Future<void> stop();
  Future<void> dispose();
}
```

Adapter:

```dart
final class BundledRitualAudioPlayback implements AudioPlaybackPort {
  BundledRitualAudioPlayback({
    required RitualRoomRepository repository,
    AudioPlayer? player,
  }) : _repository = repository,
       _player = player ?? AudioPlayer();

  final RitualRoomRepository _repository;
  final AudioPlayer _player;

  @override
  Stream<void> get completionStream => _player.onPlayerComplete;

  @override
  Future<void> play(String audioAssetId) async {
    final reference = await _repository.resolveAudioAssetReference(audioAssetId);
    final playerPath = reference.startsWith('assets/')
        ? reference.substring('assets/'.length)
        : reference;
    await _player.stop();
    await _player.play(AssetSource(playerPath));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
```

- [ ] **Step 5: Implement transient controller**

Use:

```dart
enum RitualAudioStatus { idle, playing, completed, failure }

final class RitualAudioState {
  const RitualAudioState({
    this.status = RitualAudioStatus.idle,
    this.audioAssetId,
  });

  final RitualAudioStatus status;
  final String? audioAssetId;
}
```

The controller must:

- set `playing(id)` before awaiting the port
- set `failure(id)` when playback throws
- observe completion and set `completed(id)`
- stop and return to idle when `activeUtterance.audioAssetId` changes
- never write playback state into `ProductSnapshot`

- [ ] **Step 6: Provide the controller through Riverpod**

In `ritual_audio_providers.dart`:

```dart
final ritualAudioPlaybackPortProvider = Provider<AudioPlaybackPort>(
  (ref) => BundledRitualAudioPlayback(
    repository: ref.watch(ritualRoomRepositoryProvider),
  ),
);

final ritualAudioControllerProvider =
    ChangeNotifierProvider<RitualAudioController>((ref) {
      return RitualAudioController(
        port: ref.watch(ritualAudioPlaybackPortProvider),
      );
    });
```

- [ ] **Step 7: Wire app intent without exposing paths**

Keep `RitualRoomScreen.onListen` as a no-argument intent. In `BabyTalkApp`:

```dart
onListen: () {
  final snapshot = state.snapshot;
  if (snapshot == null) return;
  ref
      .read(ritualAudioControllerProvider)
      .play(snapshot.activeUtterance.audioAssetId);
},
```

Listen for active audio ID changes and call `resetForActiveAudio`.

- [ ] **Step 8: Run audio tests**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/data/audio `
  test/features/ritual_room/presentation/audio `
  test/app/providers/ritual_audio_providers_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```powershell
git add mobile_v2/lib/features/ritual_room/domain/audio mobile_v2/lib/features/ritual_room/data/audio mobile_v2/lib/features/ritual_room/presentation/audio mobile_v2/lib/app/providers/ritual_audio_providers.dart mobile_v2/lib/app/baby_talk_app.dart mobile_v2/test/features/ritual_room/data/audio mobile_v2/test/features/ritual_room/presentation/audio mobile_v2/test/app/providers/ritual_audio_providers_test.dart
git commit -m "feat(41): play active utterance bundled audio"
```

---

### Task 5: Add compile-time-gated UAT API decoration

**Files:**
- Create: `mobile_v2/lib/app/uat/phase41_uat_config.dart`
- Create: `mobile_v2/lib/app/uat/uat_interaction_mode_controller.dart`
- Create: `mobile_v2/lib/features/ritual_room/data/datasources/uat_interaction_api_decorator.dart`
- Modify: `mobile_v2/lib/app/providers/ritual_room_data_providers.dart`
- Test: `mobile_v2/test/app/uat/phase41_uat_config_test.dart`
- Test: `mobile_v2/test/features/ritual_room/data/datasources/uat_interaction_api_decorator_test.dart`
- Test: `mobile_v2/test/app/providers/ritual_room_data_providers_test.dart`

- [ ] **Step 1: Write failing gate and decorator tests**

Decorator test:

```dart
test('commit-then-lose waits after real applied response then throws unknown', () async {
  final delegate = RecordingInteractionApi(
    response: appliedResponse(revision: 1),
  );
  final controller = UatInteractionModeController(
    initialMode: UatInteractionMode.commitThenLoseResponse,
  );
  final decorator = UatInteractionApiDecorator(
    delegate: delegate,
    mode: controller,
    postCommitDelay: const Duration(milliseconds: 20),
  );

  final stopwatch = Stopwatch()..start();
  await expectLater(
    decorator.advance(
      interactionId: interactionId,
      request: interactionRequest(),
    ),
    throwsA(isA<InteractionOutcomeUnknownException>()),
  );

  expect(delegate.advanceCalls, 1);
  expect(stopwatch.elapsed, greaterThanOrEqualTo(
    const Duration(milliseconds: 20),
  ));
});
```

Add a second test proving a duplicate response on exact retry is returned, not discarded.

- [ ] **Step 2: Run UAT data tests and verify RED**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/app/uat `
  test/features/ritual_room/data/datasources/uat_interaction_api_decorator_test.dart `
  test/app/providers/ritual_room_data_providers_test.dart
```

Expected: FAIL because the UAT classes do not exist.

- [ ] **Step 3: Add the fixed compile-time gate**

Create:

```dart
import 'package:flutter/foundation.dart';

const bool phase41UatEnabled =
    bool.fromEnvironment('BABY_TALK_UAT') && !kReleaseMode;
```

Add a source-level test that asserts the expression is present verbatim. Add a truth-table helper only for unit testing:

```dart
bool resolvePhase41UatAvailability({
  required bool flag,
  required bool releaseMode,
}) => flag && !releaseMode;
```

- [ ] **Step 4: Add mode controller**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UatInteractionMode { normal, delayedSuccess, commitThenLoseResponse }

final class UatInteractionModeController extends ChangeNotifier {
  UatInteractionModeController({
    UatInteractionMode initialMode = UatInteractionMode.normal,
  }) : _mode = initialMode;

  UatInteractionMode _mode;
  UatInteractionMode get mode => _mode;

  void select(UatInteractionMode next) {
    if (_mode == next) return;
    _mode = next;
    notifyListeners();
  }

  void restoreNormal() => select(UatInteractionMode.normal);
}

final uatInteractionModeControllerProvider =
    Provider<UatInteractionModeController>((ref) {
      final controller = UatInteractionModeController();
      ref.onDispose(controller.dispose);
      return controller;
    });
```

- [ ] **Step 5: Implement the real API decorator**

```dart
final class UatInteractionApiDecorator implements InteractionApi {
  const UatInteractionApiDecorator({
    required InteractionApi delegate,
    required UatInteractionModeController mode,
    this.responseDelay = const Duration(seconds: 2),
  }) : _delegate = delegate,
       _mode = mode;

  final InteractionApi _delegate;
  final UatInteractionModeController _mode;
  final Duration responseDelay;

  @override
  Future<InteractionSnapshotResponse> getSnapshot(String interactionId) =>
      _delegate.getSnapshot(interactionId);

  @override
  Future<InteractionResultResponse> advance({
    required String interactionId,
    required InteractionAdvanceRequest request,
  }) async {
    final selectedMode = _mode.mode;
    final response = await _delegate.advance(
      interactionId: interactionId,
      request: request,
    );
    if (selectedMode == UatInteractionMode.delayedSuccess) {
      await Future<void>.delayed(responseDelay);
      return response;
    }
    if (selectedMode == UatInteractionMode.commitThenLoseResponse &&
        response.status == AdvanceStatus.applied.wireName) {
      await Future<void>.delayed(responseDelay);
      throw const InteractionOutcomeUnknownException(
        reason: InteractionOutcomeUnknownReason.responseLostAfterDispatch,
      );
    }
    return response;
  }
}
```

The mode is captured before dispatch so changing the overlay during an in-flight request cannot change that request's outcome.

- [ ] **Step 6: Split raw and selected API providers**

In `ritual_room_data_providers.dart`:

```dart
final rawInteractionApiProvider = Provider<InteractionApi>(
  (ref) => MockInteractionApi(
    engine: ref.watch(interactionEnginePortProvider),
    mapper: ref.watch(interactionMapperProvider),
  ),
);

final interactionApiProvider = Provider<InteractionApi>((ref) {
  final raw = ref.watch(rawInteractionApiProvider);
  if (!phase41UatEnabled) return raw;
  return UatInteractionApiDecorator(
    delegate: raw,
    mode: ref.watch(uatInteractionModeControllerProvider),
  );
});
```

Tests with `--dart-define=BABY_TALK_UAT=true` must assert the selected provider is a decorator. Normal tests must assert identity with the raw API.

- [ ] **Step 7: Run normal and flag-on test variants**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/app/uat `
  test/features/ritual_room/data/datasources/uat_interaction_api_decorator_test.dart `
  test/app/providers/ritual_room_data_providers_test.dart

flutter test --no-pub --dart-define=BABY_TALK_UAT=true `
  test/app/uat `
  test/app/providers/ritual_room_data_providers_test.dart
```

Expected: both runs PASS; normal selects raw API, flag-on debug selects decorator.

- [ ] **Step 8: Commit**

```powershell
git add mobile_v2/lib/app/uat mobile_v2/lib/features/ritual_room/data/datasources/uat_interaction_api_decorator.dart mobile_v2/lib/app/providers/ritual_room_data_providers.dart mobile_v2/test/app/uat mobile_v2/test/features/ritual_room/data/datasources/uat_interaction_api_decorator_test.dart mobile_v2/test/app/providers/ritual_room_data_providers_test.dart
git commit -m "feat(41): add release-gated interaction UAT decorator"
```

---

### Task 6: Rebuild Ritual Room to D.4.5 at `427×952dp`

**Files:**
- Modify: `mobile_v2/lib/app/theme/baby_talk_theme.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_identity_header.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_current_utterance.dart`
- Create: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_utterance_card.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_listen_control.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_action_cue.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_reassurance.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_submitting_indicator.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`

- [ ] **Step 1: Replace screen expectations with the accepted product projection**

Add tests that assert:

```dart
expect(find.text(snapshot.activeUtterance.primary), findsOneWidget);
expect(find.text(snapshot.activeUtterance.zhSupport), findsOneWidget);
expect(find.text(snapshot.normalizedContext.eventSummary), findsNothing);
expect(find.textContaining('the shared routine'), findsNothing);
expect(find.textContaining('eventSummary'), findsNothing);
expect(find.textContaining('duplicate_ignored'), findsNothing);
expect(find.textContaining('lost response'), findsNothing);
```

Add one full READY → REVISED widget test asserting `rr_shoes_001` changes to `rr_shoes_002` through the app-level listen fake.

- [ ] **Step 2: Run screen tests and verify RED**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart `
  test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
```

Expected: FAIL because the current widget renders `eventSummary` and lacks D.4.5 card geometry.

- [ ] **Step 3: Use parent constraints for phone layout**

Top-level shape:

```dart
return Scaffold(
  body: SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 400;
        final horizontalPadding = narrow ? 16.0 : 20.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ),
                  sliver: SliverList.list(children: roomChildren),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ),
);
```

Do not branch on orientation or physical device type. Do not add a tablet layout.

- [ ] **Step 4: Remove fixed-height clipping**

Change identity header from `SizedBox(height: 196)` to:

```dart
ConstrainedBox(
  constraints: const BoxConstraints(minHeight: 168),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox.square(dimension: narrow ? 96 : 112, child: illustration),
      const SizedBox(width: 16),
      Expanded(child: identityText),
    ],
  ),
);
```

Pass `narrow` or available width from the parent. The approved illustration path remains unchanged.

- [ ] **Step 5: Build one dominant utterance card**

`RitualUtteranceCard` must render only presentation-safe values:

```dart
final utterance = snapshot.activeUtterance;

if (utterance.contextLabel != null)
  RitualContextChip(label: utterance.contextLabel!),
Text(utterance.primary, key: const Key('ritual-active-utterance')),
Text(utterance.zhSupport),
RitualListenControl(...),
if (utterance.gentleSupport != null) Text(utterance.gentleSupport!),
RitualActionCue(cue: room.actionCue),
if (submitting) RitualSubmittingIndicator(message: room.pendingCopy),
```

Never render `snapshot.normalizedContext.eventSummary`.

- [ ] **Step 6: Keep state geometry stable**

Projection rules:

```dart
final active = snapshotState.snapshot!.activeUtterance;
final isSubmitting = snapshotState is RitualRoomSubmitting;
final unknown = snapshotState is RitualRoomUnknownOutcome
    ? snapshotState as RitualRoomUnknownOutcome
    : null;
```

- SUBMITTING shows selected user label plus prior active utterance.
- Result not confirmed shows prior active utterance plus recovery notice.
- REVISED arrives only through a replaced authoritative snapshot.
- Reaction controls remain below the card and never become a primary filled CTA.

- [ ] **Step 7: Run geometry tests at both viewports**

Test helpers:

```dart
Future<void> setViewport(
  WidgetTester tester, {
  required Size logicalSize,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
```

Run each state at:

```text
427×952, textScale 1.0
427×952, textScale 1.3
390×844, textScale 1.0
390×844, textScale 1.3
```

Assert no exception, no horizontal overflow, and quiet exit is reachable by scrolling.

- [ ] **Step 8: Run focused UI tests**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart `
  test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```powershell
git add mobile_v2/lib/app/theme/baby_talk_theme.dart mobile_v2/lib/features/ritual_room/presentation mobile_v2/test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
git commit -m "feat(41): align Ritual Room with D.4.5"
```

---

### Task 7: Implement TalkBack recovery semantics and hidden UAT overlay

**Files:**
- Create: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_recovery_notice.dart`
- Create: `mobile_v2/lib/app/uat/uat_overlay_host.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart`
- Modify: `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart`
- Modify: `mobile_v2/lib/app/baby_talk_app.dart`
- Test: `mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart`
- Test: `mobile_v2/test/app/uat/uat_overlay_host_test.dart`

- [ ] **Step 1: Write failing semantics and overlay tests**

Required assertions:

```dart
expect(tester.getSize(find.byKey(const Key('ritual-more-reactions'))).height,
    greaterThanOrEqualTo(48));
expect(find.bySemanticsLabel('更多情况'), findsOneWidget);
expect(find.bySemanticsLabel('not_ready_yet'), findsNothing);

final retry = tester.getSemantics(
  find.byKey(const Key('ritual-unknown-outcome-retry')),
);
expect(retry.hasFlag(SemanticsFlag.isButton), isTrue);

final reaction = tester.getSemantics(
  find.byKey(const Key('ritual-reaction-choice-0')),
);
expect(reaction.hasFlag(SemanticsFlag.isEnabled), isFalse);
```

Closed overlay assertions:

```dart
expect(find.text('Phase 41 验收'), findsNothing);
expect(find.bySemanticsLabel('Phase 41 验收'), findsNothing);
expect(tester.getSize(find.byType(UatOverlayHost)), viewportSize);
```

- [ ] **Step 2: Run accessibility tests and verify RED**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/presentation/ritual_room_accessibility_test.dart `
  test/app/uat/uat_overlay_host_test.dart
```

Expected: FAIL because focus control and overlay do not exist.

- [ ] **Step 3: Implement recovery focus**

`RitualRecoveryNotice` is stateful and owns a `FocusNode`:

```dart
@override
void initState() {
  super.initState();
  _retryFocusNode = FocusNode(debugLabel: 'ritual-retry');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _retryFocusNode.requestFocus();
  });
}
```

Use:

```dart
Semantics(
  sortKey: const OrdinalSortKey(1),
  liveRegion: true,
  label: '刚刚没确认成功，我们再试一次。',
  child: ...
),
Semantics(
  sortKey: const OrdinalSortKey(2),
  button: true,
  child: OutlinedButton(
    focusNode: _retryFocusNode,
    key: const Key('ritual-unknown-outcome-retry'),
    onPressed: isRetrying ? null : onRetry,
    child: const Text('再试一次'),
  ),
),
```

Reaction controls use later sort keys and retain `enabled: false` while locked.

- [ ] **Step 4: Keep hidden sheet content out of semantics**

The additional-choice sheet must not exist before opening. When open, wrap its route content in:

```dart
Semantics(
  scopesRoute: true,
  namesRoute: true,
  explicitChildNodes: true,
  label: prompt,
  child: sheetContent,
);
```

Use `minimumSize: const Size(48, 48)` for `更多情况` and every sheet option. Semantics labels use only `choice.label`.

- [ ] **Step 5: Implement shell-level UAT overlay**

`UatOverlayHost` wraps the app child, not `RitualRoomScreen`:

```dart
final class UatOverlayHost extends StatefulWidget {
  const UatOverlayHost({super.key, required this.child});
  final Widget child;
}
```

When closed, return a parent `Listener` around `child`. The listener:

- is outside semantics
- observes pointer-down coordinates without replacing child gesture handlers
- opens only after five taps inside the top-right 48×48 logical region within two seconds

When open, add a modal QA panel with Chinese labels:

```text
Phase 41 验收
正常
延迟成功
提交成功但丢失响应
恢复正常
关闭
```

The mode labels are QA-only and never appear while closed.

- [ ] **Step 6: Gate the overlay in `BabyTalkApp`**

Use:

```dart
builder: (context, child) {
  final resolved = child ?? const SizedBox.shrink();
  if (!phase41UatEnabled) return resolved;
  return UatOverlayHost(child: resolved);
},
```

Do not import UAT widgets into Ritual Room presentation files.

- [ ] **Step 7: Run accessibility and overlay tests**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/presentation/ritual_room_accessibility_test.dart `
  test/app/uat/uat_overlay_host_test.dart

flutter test --no-pub --dart-define=BABY_TALK_UAT=true `
  test/app/uat/uat_overlay_host_test.dart
```

Expected: PASS. The first run has no overlay; the flag-on run can open it with the QA gesture.

- [ ] **Step 8: Commit**

```powershell
git add mobile_v2/lib/features/ritual_room/presentation mobile_v2/lib/app/uat/uat_overlay_host.dart mobile_v2/lib/app/baby_talk_app.dart mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart mobile_v2/test/app/uat/uat_overlay_host_test.dart
git commit -m "feat(41): add TalkBack recovery and hidden UAT shell"
```

---

### Task 8: Prove the single-event reconciliation path end to end

**Files:**
- Modify: `mobile_v2/test/app/providers/ritual_room_session_provider_test.dart`
- Modify: `mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`
- Add: `mobile_v2/integration_test/phase41_device_uat_test.dart`
- Add: `mobile_v2/test/features/ritual_room/phase41_acceptance_flow_test.dart`

- [ ] **Step 1: Write the exact acceptance-flow regression**

Build a real engine/provider container with the UAT decorator in `commitThenLoseResponse`. Record:

```dart
final events = <InputEvent>[];
final ids = <String>[];
```

Required flow:

```dart
await notifier.openRoom(ritualRoomId);
expect(state.snapshot!.activeUtterance.audioAssetId, 'rr_shoes_001');

final submit = notifier.submitReaction('not_ready_yet');
await pumpUntilState<RitualRoomSubmitting>();
final submittingCommand = repository.inputs.single;

await submit;
expect(state, isA<RitualRoomUnknownOutcome>());

await notifier.retryPendingEvent();
expect(repository.inputs, hasLength(2));
expect(repository.inputs[1], same(submittingCommand));
expect(state, isA<RitualRoomReady>());
expect(state.snapshot!.revision, 1);
expect(state.snapshot!.activeUtterance.audioAssetId, 'rr_shoes_002');
expect(
  state.snapshot!.activeUtterance.primary,
  "You don’t want your shoes on yet.",
);
```

- [ ] **Step 2: Run acceptance test and verify RED**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/phase41_acceptance_flow_test.dart
```

Expected: FAIL until all prior tasks are integrated.

- [ ] **Step 3: Add integration-test driver**

The integration test must:

1. open the UAT panel through the documented QA gesture
2. select `提交成功但丢失响应`
3. assert READY text and trigger READY audio
4. tap `还不想穿` once
5. capture or pause while `正在换一种说法…` is visible
6. wait for `刚刚没确认成功，我们再试一次。`
7. tap `再试一次`
8. wait for the REVISED active utterance
9. trigger REVISED audio
10. select `恢复正常`
11. assert the REVISED snapshot remains visible

Use stable keys for every action; do not locate by internal mode keys or event IDs.

- [ ] **Step 4: Run the automated acceptance flow**

```powershell
Set-Location mobile_v2
flutter test --no-pub `
  test/features/ritual_room/phase41_acceptance_flow_test.dart `
  test/app/providers/ritual_room_session_provider_test.dart `
  test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
```

Expected: PASS, proving one event supplies SUBMITTING, result-not-confirmed, and reconciliation evidence.

- [ ] **Step 5: Run integration test on Android emulator**

```powershell
Set-Location mobile_v2
flutter test integration_test/phase41_device_uat_test.dart `
  -d emulator-5554 `
  --dart-define=BABY_TALK_UAT=true
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add mobile_v2/test/app/providers/ritual_room_session_provider_test.dart mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart mobile_v2/test/features/ritual_room/phase41_acceptance_flow_test.dart mobile_v2/integration_test/phase41_device_uat_test.dart
git commit -m "test(41): prove exact-event device acceptance flow"
```

---

### Task 9: Prove release-with-flag remains clean

**Files:**
- Add: `scripts/verify-phase41-release-uat-gate.ps1`
- Modify: `mobile_v2/test/app/uat/phase41_uat_config_test.dart`
- Modify: `mobile_v2/test/app/providers/ritual_room_data_providers_test.dart`

- [ ] **Step 1: Add source and provider assertions**

Tests must prove:

```dart
expect(resolvePhase41UatAvailability(flag: true, releaseMode: true), isFalse);
expect(resolvePhase41UatAvailability(flag: true, releaseMode: false), isTrue);
```

Source assertions must prove the production constant contains:

```text
bool.fromEnvironment('BABY_TALK_UAT') && !kReleaseMode
```

- [ ] **Step 2: Add release verification script**

The PowerShell script must:

```powershell
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mobile = Join-Path $root 'mobile_v2'

Push-Location $mobile
try {
  flutter build apk --release --dart-define=BABY_TALK_UAT=true
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  adb shell am force-stop com.babytalk.mobile_v2
  adb shell monkey -p com.babytalk.mobile_v2 1 | Out-Null
  Start-Sleep -Seconds 3

  # Attempt the documented five-tap QA opener.
  1..5 | ForEach-Object { adb shell input tap 1220 140 | Out-Null }
  Start-Sleep -Milliseconds 500

  adb shell uiautomator dump /sdcard/phase41-release.xml | Out-Null
  adb pull /sdcard/phase41-release.xml $env:TEMP\phase41-release.xml | Out-Null
  $xml = Get-Content -Raw $env:TEMP\phase41-release.xml
  foreach ($forbidden in @(
    'Phase 41 验收',
    '延迟成功',
    '提交成功但丢失响应',
    '恢复正常'
  )) {
    if ($xml.Contains($forbidden)) {
      throw "release UAT gate leaked: $forbidden"
    }
  }
} finally {
  Pop-Location
}
```

Use the current application ID literal `com.babytalk.mobile_v2` shown above.

- [ ] **Step 3: Run release negative evidence**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-phase41-release-uat-gate.ps1
```

Expected: release APK builds and the script exits 0 with no UAT label in the UI hierarchy.

- [ ] **Step 4: Commit**

```powershell
git add scripts/verify-phase41-release-uat-gate.ps1 mobile_v2/test/app/uat/phase41_uat_config_test.dart mobile_v2/test/app/providers/ritual_room_data_providers_test.dart
git commit -m "test(41): prove release UAT gate stays unreachable"
```

---

### Task 10: Run full verification and collect target-device evidence

**Files:**
- Modify: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-UAT.md`
- Modify: `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-VERIFICATION.md`
- Add: `.planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/ready.png`
- Add: `.planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/submitting.png`
- Add: `.planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/result-not-confirmed.png`
- Add: `.planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/revised.png`
- Add: `.planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/talkback-notes.md`

- [ ] **Step 1: Format and analyze**

```powershell
Set-Location mobile_v2
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
```

Expected: formatting check exits 0 and analyzer reports `No issues found!`.

- [ ] **Step 2: Run the complete Flutter suite**

```powershell
Set-Location mobile_v2
flutter test --no-pub
```

Expected: all tests pass. The total may exceed 122; no previously passing baseline test may regress.

- [ ] **Step 3: Run semantic and governance verifiers**

From repository root:

```powershell
dart run tool/verify_mobile_v2_semantic_firewall.dart
dart run tool/verify_activation_governor_contract.dart
```

Expected: zero violations.

- [ ] **Step 4: Build the UAT APK**

Use a profile build when TalkBack and audio plugin behavior match the target device; otherwise use debug:

```powershell
Set-Location mobile_v2
flutter build apk --profile --dart-define=BABY_TALK_UAT=true
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

Expected: successful build and install.

- [ ] **Step 5: Confirm target viewport**

On the target Android device:

```powershell
adb shell wm size
adb shell wm density
adb shell dumpsys window | Select-String -Pattern 'mCurrentFocus|mFocusedApp'
```

Record:

```text
logical viewport: 427×952dp
physical resolution: 1280×2856px
```

If the logical viewport differs, stop the UAT and correct emulator/device display settings before taking screenshots.

- [ ] **Step 6: Execute the one-event main acceptance flow**

1. Open the QA overlay.
2. Select `提交成功但丢失响应`.
3. Capture READY and play `rr_shoes_001`.
4. Select `还不想穿` exactly once.
5. During the decorator's bounded post-commit delay, capture SUBMITTING.
6. Wait for `刚刚没确认成功，我们再试一次。`; capture result-not-confirmed.
7. With TalkBack on, confirm reactions are announced disabled and focus prioritizes `再试一次`.
8. Activate `再试一次`.
9. Confirm authoritative REVISED appears after duplicate reconciliation.
10. Capture REVISED and play `rr_shoes_002`.
11. Select `恢复正常`; confirm REVISED remains.

Do not switch to delayed-success mode and do not create a second reaction event.

- [ ] **Step 7: Capture screenshots**

At each state:

```powershell
$evidenceDir = '.planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android'
New-Item -ItemType Directory -Force $evidenceDir | Out-Null
adb exec-out screencap -p > .planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/ready.png
adb exec-out screencap -p > .planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/submitting.png
adb exec-out screencap -p > .planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/result-not-confirmed.png
adb exec-out screencap -p > .planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat/2026-06-22-target-android/revised.png
```

Use exact filenames:

```text
ready.png
submitting.png
result-not-confirmed.png
revised.png
```

- [ ] **Step 8: Record TalkBack and audio evidence**

Create `talkback-notes.md` containing:

```markdown
# Phase 41 TalkBack and Audio Evidence

- Device logical viewport: 427×952dp
- Physical resolution: 1280×2856px
- “更多情况” target: operable and announced only as “更多情况”
- Hidden sheet content: absent from focus until opened
- Result-not-confirmed reactions: announced disabled
- Recovery focus: “再试一次” receives priority
- Internal key/mode/event ID announcements: none
- READY audio: “Let’s put your shoes on.”
- REVISED audio: “You don’t want your shoes on yet.”
```

- [ ] **Step 9: Run release negative evidence**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-phase41-release-uat-gate.ps1
```

Expected: PASS after the device UAT APK has been replaced by the release-with-flag APK.

- [ ] **Step 10: Update Phase 41 UAT records**

Update `41-UAT.md`:

- status to passed only if every device item passed
- primary viewport to `427×952dp`
- screenshot artifact paths
- TalkBack evidence path
- READY/REVISED audio results
- exact-event reconciliation result
- release-with-flag negative result

Update `41-VERIFICATION.md` only with collected evidence; do not copy planned claims as completed evidence.

- [ ] **Step 11: Commit verification artifacts**

```powershell
git add .planning/phases/41-mobile-v2-runnable-vertical-slice/41-UAT.md .planning/phases/41-mobile-v2-runnable-vertical-slice/41-VERIFICATION.md .planning/phases/41-mobile-v2-runnable-vertical-slice/artifacts/device-uat
git commit -m "test(41): complete target-device UAT"
```

---

## Plan Self-Review

### Spec coverage

- Active utterance single source: Tasks 1–3.
- READY/REVISED locked content and audio IDs: Tasks 1–4.
- No UI asset path or text matching: Tasks 3–4 and 6.
- Real API decorator and exact-event reconciliation: Tasks 5 and 8.
- Release-inaccessible UAT: Tasks 5, 7, and 9.
- D.4.5 at `427×952dp`, narrow regression, text scale 1.3: Task 6.
- TalkBack 48dp, hidden semantics, disabled reactions, retry focus: Task 7.
- One-event device acceptance flow: Tasks 8 and 10.
- Existing 122-test baseline plus new tests: Task 10.

### Type consistency

- `ProductSnapshot.activeUtterance` uses `ActiveUtterance`.
- `ActiveUtterance.audioAssetId` is opaque and is the only audio command input.
- `AudioPlaybackPort.play(String audioAssetId)` never accepts a path.
- `ActiveUtteranceSource.resolveActiveUtterance` is shared by seed and realization.
- `UatInteractionApiDecorator` decorates `InteractionApi`, not the repository or UI.
- `RitualRoomSessionNotifier` remains the only mutable product-session authority.

### Explicit exclusions

- No fake UAT state screen.
- No UI-created snapshot.
- No second event for SUBMITTING evidence.
- No long-term remote audio architecture.
- No visible hidden-channel controls.
- No tablet layout.
