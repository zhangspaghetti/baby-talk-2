# Phase 41: mobile_v2 可运行 First Micro-ritual Vertical Slice - Pattern Map

**Mapped:** 2026-06-16
**Files analyzed:** 14
**Analogs found:** 14 / 14

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `mobile_v2/lib/main.dart` | config | request-response | `mobile_v2/pubspec.yaml` + Flutter `runApp` pattern from `41-RESEARCH.md` | partial |
| `mobile_v2/lib/baby_talk_v2_app.dart` | component | request-response | `mobile_v2/pubspec.yaml` + `mobile/lib/app/theme/app_theme.dart` | role-match, reference-only old visual source |
| `mobile_v2/lib/vnext_semantic_boundary.dart` | config | transform | existing `mobile_v2/lib/vnext_semantic_boundary.dart` | exact |
| `mobile_v2/lib/first_micro_ritual/ritual_room_models.dart` | model | transform | `test/tool/verify_mobile_v2_semantic_firewall_test.dart` clean boundary fixture | exact semantic analog |
| `mobile_v2/lib/first_micro_ritual/first_micro_ritual_fixture.dart` | model | transform | `mobile_v2/lib/vnext_semantic_boundary.dart` + `test/tool/verify_mobile_v2_semantic_firewall_test.dart` | exact semantic analog |
| `mobile_v2/lib/first_micro_ritual/ritual_lens_controller.dart` | store | event-driven | `test/features/vnext/activation_governor_contract_surface_test.dart` typed fixture flow | role-match |
| `mobile_v2/lib/first_micro_ritual/widgets/ritual_room_surface.dart` | component | request-response | `mobile/lib/features/practice/presentation/widgets/activation_frame.dart` | role-match, reference-only visual source |
| `mobile_v2/lib/first_micro_ritual/widgets/first_entry_lens.dart` | component | request-response | `test/features/vnext/mobile_v2_surface_contract_test.dart` First Entry rejection fixture | semantic exact |
| `mobile_v2/lib/first_micro_ritual/widgets/today_orientation_lens.dart` | component | request-response | `test/features/vnext/activation_governor_contract_surface_test.dart` activation copy fixtures | semantic exact |
| `mobile_v2/lib/first_micro_ritual/widgets/room_support_lens.dart` | component | request-response | `mobile/lib/features/practice/presentation/widgets/phrase_card.dart` + `mobile/lib/app/widgets/app_audio_button.dart` | role-match, reference-only visual source |
| `mobile_v2/lib/first_micro_ritual/widgets/memory_lens.dart` | component | event-driven | `test/tool/verify_activation_governor_contract_test.dart` parent confirmation cases | semantic exact |
| `mobile_v2/test/first_micro_ritual_flow_test.dart` | test | event-driven | `41-RESEARCH.md` Flutter widget test example + root verifier test style | role-match |
| `mobile_v2/test/first_micro_ritual_fixture_test.dart` | test | transform | `test/tool/verify_mobile_v2_semantic_firewall_test.dart` clean and banned fixture cases | exact |
| `mobile_v2/test/accessibility_smoke_test.dart` | test | request-response | `41-RESEARCH.md` accessibility guideline example + `mobile/lib/app/widgets/app_audio_button.dart` semantics pattern | role-match |

## Pattern Assignments

### `mobile_v2/lib/main.dart` (config, request-response)

**Analog:** `mobile_v2/pubspec.yaml` and Flutter app-root pattern in `41-RESEARCH.md`.

**Package boundary pattern** (`mobile_v2/pubspec.yaml` lines 1-18):
```yaml
name: mobile_v2
description: Baby Talk vNext mobile boundary
publish_to: 'none'
version: 0.0.1

environment:
  sdk: ^3.11.4

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
```

**Implementation guidance:** keep `main.dart` minimal: import only Flutter and `baby_talk_v2_app.dart`, then call `runApp(const BabyTalkV2App())`. Do not import old `mobile/` code or add Riverpod/GoRouter for this phase.

---

### `mobile_v2/lib/baby_talk_v2_app.dart` (component, request-response)

**Analog:** `mobile/lib/app/theme/app_theme.dart` is visual reference only. Re-derive locally; do not import it.

**Warm palette reference** (`mobile/lib/app/theme/app_theme.dart` lines 215-236):
```dart
static const Color bgBase = Color(0xFFFFF8F0);
static const Color bgSurface = Color(0xFFFFFFFF);
static const Color bgSunken = Color(0xFFF5F0EB);
static const Color bgAccentSoft = Color(0xFFFFF0E5);
static const Color accent = Color(0xFFFF8C42);
static const Color accentDark = Color(0xFFE67A30);
static const Color english = Color(0xFF3B8577);
static const Color englishSoft = Color(0xFFD4E8E3);
static const Color textPrimary = Color(0xFF2D2926);
static const Color textSecondary = Color(0xFF6B5E57);
static const Color textMuted = Color(0xFF8A7D76);
```

**Theme root reference** (`mobile/lib/app/theme/app_theme.dart` lines 296-329):
```dart
static ThemeData build() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.light,
    primary: accent,
    secondary: english,
    surface: bgSurface,
    error: error,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: bgBase,
    fontFamily: 'DM Sans',
    dividerColor: outlineSoft,
    textTheme: const TextTheme(
      displayMedium: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 1.2,
```

**Implementation guidance:** create a small local `ThemeData` in `baby_talk_v2_app.dart` or a local theme helper under `mobile_v2/lib`; use the UI-SPEC sizes/weights exactly and no old package imports.

---

### `mobile_v2/lib/vnext_semantic_boundary.dart` (config, transform)

**Analog:** existing same file.

**Boundary constants** (`mobile_v2/lib/vnext_semantic_boundary.dart` lines 1-9):
```dart
const familyEnglishMicroRitualUnit = 'Family English Micro-ritual';

const contextSeedEvidenceBoundary =
    'Observed Moment is Context Seed evidence only';

const joinabilityHypothesisBoundary =
    'Interpreted Moment is Joinability hypothesis only';

const activationCandidateBoundary = 'Candidate matching is not activation';
```

**Implementation guidance:** preserve these anchors. If adding Phase 41 constants, keep them about Ritual Room / Context Seed / Joinability / fake `allow_activation`, not phrase/activity/progress terms.

---

### `mobile_v2/lib/first_micro_ritual/ritual_room_models.dart` (model, transform)

**Analog:** clean semantic model fixture in `test/tool/verify_mobile_v2_semantic_firewall_test.dart`.

**Safe model fields** (`test/tool/verify_mobile_v2_semantic_firewall_test.dart` lines 23-49):
```dart
class FamilyEnglishMicroRitualBoundary {
  const FamilyEnglishMicroRitualBoundary({
    required this.fixedSound,
    required this.routineAnchor,
    required this.actionBinding,
    required this.toneHint,
    required this.childNoResponseRule,
  });

  final String fixedSound;
  final String routineAnchor;
  final String actionBinding;
  final String toneHint;
  final String childNoResponseRule;
}

class ContextSeedEvidenceBoundary {
  const ContextSeedEvidenceBoundary(this.observedMoment);

  final String observedMoment;
}

class JoinabilityHypothesisBoundary {
  const JoinabilityHypothesisBoundary(this.hypothesis);

  final String hypothesis;
}
```

**Forbidden model terms** (`tool/verify_mobile_v2_semantic_firewall.dart` lines 15-26):
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
];
```

**Implementation guidance:** model names should be `RitualRoom`, `ContextSeed`, `JoinabilityHypothesis`, `FakeGovernorDecision`, and `GardenMemorySnapshot` or similar. Avoid every banned term above in runtime source, including comments and tests under `mobile_v2/lib`.

---

### `mobile_v2/lib/first_micro_ritual/first_micro_ritual_fixture.dart` (model, transform)

**Analog:** existing semantic boundary constants and clean verifier fixture.

**Runtime scan pattern that will inspect fixture code** (`tool/verify_mobile_v2_semantic_firewall.dart` lines 182-214):
```dart
MobileV2SemanticFirewallReport scanMobileV2SemanticFirewall({
  String? projectRoot,
}) {
  final resolvedProjectRoot = _normalizePath(
    projectRoot ?? Directory.current.path,
  );
  final runtimeRoot = Directory('$resolvedProjectRoot/mobile_v2/lib');
  final violations = <MobileV2SemanticFirewallViolation>[];

  var scannedRuntimeFileCount = 0;
  if (!runtimeRoot.existsSync()) {
    violations.add(
      const MobileV2SemanticFirewallViolation(
        type: MobileV2SemanticFirewallViolationType.missingBoundary,
        sourcePath: 'mobile_v2/lib',
```

**Implementation guidance:** fixture must be local const data for exactly one rendered active room: `shoes_on_room_v1`, `出门小声音`, `Shoes on.`, fake Context Seed, Joinability `action_bound` + `routine_ready`, fake Governor `allow_activation`, and Garden Memory state `active`. Keep it structurally future-compatible but render only one room.

---

### `mobile_v2/lib/first_micro_ritual/ritual_lens_controller.dart` (store, event-driven)

**Analog:** typed contract fixtures in `tool/verify_activation_governor_contract.dart`; source scan rules from the same verifier.

**Activation/Garden contract case shape** (`tool/verify_activation_governor_contract.dart` lines 220-254):
```dart
class ActivationGovernorContractCase {
  const ActivationGovernorContractCase({
    required this.id,
    required this.description,
    required this.surface,
    required this.producer,
    required this.consumer,
    required this.decisionSource,
    required this.text,
    required this.gardenAction,
    required this.hasGovernorDecision,
    required this.hasParentIntent,
    required this.requiresGovernorDecision,
    required this.requiresParentConfirmation,
    required this.weakSignalOnly,
    required this.expectedPass,
    required this.expectedReason,
  });
```

**Source scan authority rule** (`tool/verify_activation_governor_contract.dart` lines 592-631):
```dart
void _scanRuntimeSourceFile(
  File dartFile,
  String sourcePath,
  List<ActivationGovernorContractViolation> violations,
) {
  final lines = dartFile.readAsLinesSync();
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    final lineNumber = lineIndex + 1;
    final line = lines[lineIndex];
    if (_hasActivationIntent(line) && !_lineMentionsGovernorDecision(line)) {
      violations.add(
        ActivationGovernorContractViolation(
          type: ActivationGovernorContractViolationType.sourceScan,
          sourcePath: sourcePath,
          lineNumber: lineNumber,
          reason:
              'mobile_v2/lib activation-intent copy must mention a Governor decision or stay outside runtime truth',
        ),
      );
    }
```

**Implementation guidance:** make this a tiny local state holder or `StatefulWidget` state, not a production store. It should track current lens, whether support has been seen, and selected memory option. Any active-state naming should be backed by fake Governor `allow_activation` in nearby code.

---

### `mobile_v2/lib/first_micro_ritual/widgets/ritual_room_surface.dart` (component, request-response)

**Analog:** `mobile/lib/features/practice/presentation/widgets/activation_frame.dart` is visual reference only.

**Warm frame structure** (`mobile/lib/features/practice/presentation/widgets/activation_frame.dart` lines 22-73):
```dart
return Semantics(
  label: l.activationFrameLabel,
  container: true,
  child: Container(
    key: const Key('activation-frame'),
    padding: AppLayoutConstants.bannerPadding,
    decoration: BoxDecoration(
      color: colors.bgSunken,
      borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.practiceActivationKicker,
          key: const Key('practice-activation-kicker'),
```

**Implementation guidance:** re-derive as `RitualRoomSurface` with local `EdgeInsets`, `Color`, and `BorderRadius.circular(16)`. Do not carry over step labels, practice localization, or activation-frame keys.

---

### `mobile_v2/lib/first_micro_ritual/widgets/first_entry_lens.dart` (component, request-response)

**Analog:** semantic rejection fixture for old onboarding semantics.

**Forbidden First Entry shape** (`test/features/vnext/mobile_v2_surface_contract_test.dart` lines 9-19):
```dart
test('rejects onboarding starter-phrase semantics', () async {
  final report = await _scanSurfaceFixture(
    'features/onboarding/first_micro_ritual_entry.dart',
    '''
class FirstMicroRitualEntry {
  final String starterPhraseId = 'legacy-starter';
}
''',
  );

  _expectBannedTerm(report, 'starterPhraseId');
});
```

**Implementation guidance:** First Entry opens only `shoes_on_room_v1` with CTA `进入小声音房间`. Do not call it onboarding in runtime paths/classes and do not create a reusable future onboarding lifecycle.

---

### `mobile_v2/lib/first_micro_ritual/widgets/today_orientation_lens.dart` (component, request-response)

**Analog:** activation-intent surface fixtures and source scan.

**Unsafe copy examples** (`test/features/vnext/activation_governor_contract_surface_test.dart` lines 107-145):
```dart
const _activationIntentFixtures = <_SurfaceFixture>[
  _SurfaceFixture(
    name: 'Home',
    path: 'features/home/today_card.dart',
    content: '''
class TodayCard {
  final String copy = '今天试试这个声音。';
}
''',
  ),
  _SurfaceFixture(
    name: 'Onboarding',
    path: 'features/onboarding/first_sound.dart',
    content: '''
class FirstSound {
  final String copy = '加一个新声音到你们家的日常。';
}
''',
  ),
```

**Governor line exception** (`tool/verify_activation_governor_contract.dart` lines 699-704):
```dart
bool _lineMentionsGovernorDecision(String line) {
  final normalized = _normalizeToken(line);
  return normalized.contains('activationgovernor') ||
      normalized.contains('allowactivation') ||
      normalized.contains('allow_activation');
}
```

**Implementation guidance:** UI-SPEC locks CTA `试试这句小声音`, but this may match the verifier pattern `今天\s*试试` only if combined with `今天`. Keep fake Governor `allow_activation` explicit in code and avoid adding `今天试试...` as one source line.

---

### `mobile_v2/lib/first_micro_ritual/widgets/room_support_lens.dart` (component, request-response)

**Analog:** `PhraseCard` and `AppAudioButton` are visual/interaction references only. Do not import old widgets or old practice models.

**English display visual reference** (`mobile/lib/features/practice/presentation/widgets/phrase_card.dart` lines 158-170):
```dart
// ── Hero: English phrase ─────────────────────────────────────────
Semantics(
  header: true,
  child: Text(
    phrase.english,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.displayMedium?.copyWith(
          color: colors.english,
          fontSize: 36,
          fontWeight: FontWeight.w600,
        ),
  ),
),
```

**Audio control reference** (`mobile/lib/app/widgets/app_audio_button.dart` lines 42-67):
```dart
return Semantics(
  label: semanticsLabel,
  button: true,
  child: InkWell(
    key: buttonKey,
    borderRadius: BorderRadius.circular(9999),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppLayoutConstants.minTouchTarget,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: colors.textSecondary),
```

**Implementation guidance:** build `FixedSoundDisplay`, `ActionBindingHint`, and optional local `AudioPlayControl`. Copy no `PracticePhrase`, `phraseId`, saved state, reaction row, recording, scoring, or completion behavior.

---

### `mobile_v2/lib/first_micro_ritual/widgets/memory_lens.dart` (component, event-driven)

**Analog:** parent-confirmation and Garden pressure cases from Phase 40 tests.

**Allowed low-pressure parent confirmation cases** (`test/tool/verify_activation_governor_contract_test.dart` lines 886-935):
```dart
const _parentConfirmationCases = <verifier.ActivationGovernorContractCase>[
  verifier.ActivationGovernorContractCase(
    id: 'familiar-low-pressure',
    description: 'Parent confirms familiar with low-pressure language',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'ParentConfirmation',
    text: '这句最近会自然冒出来吗？',
    gardenAction: 'set_familiar',
    hasGovernorDecision: false,
    hasParentIntent: true,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Low-pressure familiar confirmation is allowed',
  ),
```

**Garden pressure scanner** (`tool/verify_activation_governor_contract.dart` lines 125-149):
```dart
final _gardenPressurePatterns = <RegExp>[
  RegExp(r'\bchecklist\b', caseSensitive: false),
  RegExp(r'\bstreak\b', caseSensitive: false),
  RegExp(r'\bcompletion\b', caseSensitive: false),
  RegExp(r'\bcompleted\b', caseSensitive: false),
  RegExp(r'\bscore\b', caseSensitive: false),
  RegExp(r'\bgrowth\b', caseSensitive: false),
  RegExp(r'\bfertilizer\b', caseSensitive: false),
  RegExp(r'\breward\b', caseSensitive: false),
  RegExp(r'\bunlock\b', caseSensitive: false),
  RegExp(r'\bprogress\s+bar\b', caseSensitive: false),
```

**Implementation guidance:** use the locked prompt `这句最近有没有更容易从嘴边冒出来？` and exactly three low-pressure options. Option selection may update local UI only; avoid production state method names like `markFamiliar`, `setActive`, or `activationPolicy` unless the name includes an allowed parent-confirmation/Governor boundary.

---

### `mobile_v2/test/first_micro_ritual_flow_test.dart` (test, event-driven)

**Analog:** official Flutter widget-test pattern from `41-RESEARCH.md`; root verifier tests show the repo’s expectation/fixture style.

**Repo test style** (`test/tool/verify_mobile_v2_semantic_firewall_test.dart` lines 7-15):
```dart
void main() {
  group('M010-P39 mobile_v2 semantic firewall scan', () {
    test('allows clean Family English Micro-ritual boundary code', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mobile-v2-firewall-clean-',
      );
      addTearDown(() async {
```

**Surface fixture scanner style** (`test/features/vnext/mobile_v2_surface_contract_test.dart` lines 90-103):
```dart
Future<verifier.MobileV2SemanticFirewallReport> _scanSurfaceFixture(
  String runtimePath,
  String content,
) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'mobile-v2-surface-contract-',
  );
  addTearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });
```

**Implementation guidance:** use `testWidgets`, pump `BabyTalkV2App`, tap through First Entry -> Today Orientation -> Room Support -> Memory Lens, and assert locked copy plus absence of forbidden copy. Keep tests inside `mobile_v2/test` for app/widget behavior.

---

### `mobile_v2/test/first_micro_ritual_fixture_test.dart` (test, transform)

**Analog:** clean and banned model fixtures in `test/tool/verify_mobile_v2_semantic_firewall_test.dart`.

**Clean report expectation** (`test/tool/verify_mobile_v2_semantic_firewall_test.dart` lines 53-61):
```dart
final report = verifier.scanMobileV2SemanticFirewall(
  projectRoot: tempDir.path,
);

expect(report.hasBlockingViolations, isFalse);
expect(report.violations, isEmpty);
expect(report.scannedRuntimeFileCount, 1);
expect(
  verifier.renderMobileV2SemanticFirewallReport(report),
```

**Banned term expectation** (`test/features/vnext/mobile_v2_surface_contract_test.dart` lines 108-123):
```dart
void _expectBannedTerm(
  verifier.MobileV2SemanticFirewallReport report,
  String term,
) {
  expect(report.hasBlockingViolations, isTrue);
  expect(
    report.violations.any(
      (violation) =>
          violation.type ==
              verifier
                  .MobileV2SemanticFirewallViolationType
                  .bannedRuntimeTerm &&
          violation.term == term,
```

**Implementation guidance:** assert fixture values exactly: `shoes_on_room_v1`, `出门小声音`, `Shoes on.`, routine/action/no-response rule, fake Governor `allow_activation`, active Garden Memory state, and only one rendered room.

---

### `mobile_v2/test/accessibility_smoke_test.dart` (test, request-response)

**Analog:** Material semantics patterns from old audio/frame widgets plus Flutter guideline example in `41-RESEARCH.md`.

**Semantics pattern** (`mobile/lib/app/widgets/app_audio_button.dart` lines 42-49):
```dart
return Semantics(
  label: semanticsLabel,
  button: true,
  child: InkWell(
    key: buttonKey,
    borderRadius: BorderRadius.circular(9999),
    onTap: onTap,
```

**Touch target pattern** (`mobile/lib/app/widgets/app_audio_button.dart` lines 49-52):
```dart
child: ConstrainedBox(
  constraints: const BoxConstraints(
    minHeight: AppLayoutConstants.minTouchTarget,
  ),
```

**Implementation guidance:** test core tappables with `meetsGuideline(androidTapTargetGuideline)`, `meetsGuideline(iOSTapTargetGuideline)`, and `meetsGuideline(labeledTapTargetGuideline)` if Flutter CLI health permits. Otherwise keep it as a focused smoke test over semantic labels for CTA/play/options.

## Shared Patterns

### Runtime Boundary
**Source:** `mobile_v2/pubspec.yaml`, `mobile_v2/lib/vnext_semantic_boundary.dart`  
**Apply to:** all `mobile_v2/lib/**`

```dart
const familyEnglishMicroRitualUnit = 'Family English Micro-ritual';
const activationCandidateBoundary = 'Candidate matching is not activation';
```

Keep new runtime truth under `mobile_v2/lib`. Old `mobile/` files are reference-only and must not be imported into v2 runtime.

### Semantic Firewall
**Source:** `tool/verify_mobile_v2_semantic_firewall.dart`  
**Apply to:** all runtime files and fixture/model tests

```dart
void _scanRuntimeFile(
  File dartFile,
  String sourcePath,
  List<MobileV2SemanticFirewallViolation> violations,
) {
  final lines = dartFile.readAsLinesSync();
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    final lineNumber = lineIndex + 1;
    final line = lines[lineIndex];
    final directive = _parseDirective(line);
```

The scan checks imports and banned terms under `mobile_v2/lib`; planners should include this gate after implementation: `dart run tool/verify_mobile_v2_semantic_firewall.dart`.

### Reference Quarantine
**Source:** `tool/verify_mobile_v2_semantic_firewall.dart` lines 34-39 and 461-466  
**Apply to:** old snippets, assets, copied wording

```dart
const _allowlistedReferencePrefixes = <String>[
  'mobile_v2/reference_assets/',
  'mobile_v2/legacy_reference/',
  'mobile_v2/docs/',
  'mobile_v2/test/fixtures/',
];
```

```dart
bool _isQuarantinedReferencePath(String? projectPath) {
  if (projectPath == null) {
    return false;
  }
  final normalized = _normalizePath(projectPath);
  return _allowlistedReferencePrefixes.any(normalized.startsWith);
}
```

Do not import these paths from `mobile_v2/lib`.

### Activation Governor Guard
**Source:** `tool/verify_activation_governor_contract.dart`  
**Apply to:** Today Orientation, Room Support, fixture/controller naming, Memory Lens

```dart
final _activationIntentPatterns = <RegExp>[
  RegExp(r'\btoday\s+try\b', caseSensitive: false),
  RegExp(r'\btry\s+this\s+today\b', caseSensitive: false),
  RegExp(r'\badd\s+this\s+sound\b', caseSensitive: false),
  RegExp(r'\bstart\s+this\s+micro-?ritual\b', caseSensitive: false),
```

```dart
bool _lineMentionsGovernorDecision(String line) {
  final normalized = _normalizeToken(line);
  return normalized.contains('activationgovernor') ||
      normalized.contains('allowactivation') ||
      normalized.contains('allow_activation');
}
```

Include final gate: `dart run tool/verify_activation_governor_contract.dart`.

### Visual Re-Derivation Only
**Source:** `mobile/lib/app/theme/app_theme.dart`, `mobile/lib/app/widgets/app_audio_button.dart`, `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`, `mobile/lib/features/practice/presentation/widgets/activation_frame.dart`  
**Apply to:** v2 theme, room surface, fixed sound display, optional audio button

Use old visual ideas only after rewriting locally with v2 names and local constants. Never import `package:mobile/...` or relative old `mobile/lib/features/...` paths.

## No Analog Found

No file is completely without an analog. The app shell has only a partial local analog because `mobile_v2` has no existing runnable Flutter app yet; use the Flutter app-root pattern recorded in `41-RESEARCH.md` plus the local package boundary.

## Metadata

**Analog search scope:** `mobile_v2/`, `tool/verify_mobile_v2_semantic_firewall.dart`, `tool/verify_activation_governor_contract.dart`, `test/tool/`, `test/features/vnext/`, reference-only `mobile/lib/app/theme/app_theme.dart`, `mobile/lib/app/widgets/app_audio_button.dart`, `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`, `mobile/lib/features/practice/presentation/widgets/activation_frame.dart`.

**Files scanned:** 15 primary files plus phase inputs.
**Pattern extraction date:** 2026-06-16
