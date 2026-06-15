# Phase 39: vNext 产品承诺与 Family English Micro-ritual 单元收敛 - Pattern Map

**Mapped:** 2026-06-15
**Files analyzed:** 7 implied new/modified files
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `tool/verify_mobile_v2_semantic_firewall.dart` | utility | batch / file-I/O / transform | `tool/verify_refactor_011_feature_boundaries.dart` | exact |
| `test/tool/verify_mobile_v2_semantic_firewall_test.dart` | test | batch / file-I/O | `test/tool/verify_refactor_011_feature_boundaries_test.dart` | exact |
| `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` | test | delegation | `mobile/test/tool/verify_m006_s14_release_closure_test.dart` | exact |
| `mobile_v2/pubspec.yaml` | config | build config | `mobile/pubspec.yaml` | role-match |
| `mobile_v2/lib/app/theme/app_theme.dart` | utility / config | transform | `mobile/lib/app/theme/app_theme.dart` | role-match |
| `mobile_v2/lib/features/onboarding/...` | component / provider / model | event-driven / request-response UI | `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart` | role-match, semantic-reference-only |
| `mobile_v2/lib/features/practice/...` | component / provider / model | event-driven UI | `mobile/lib/features/practice/presentation/widgets/phrase_card.dart` | role-match, semantic-reference-only |
| `docs/mobile_v2_supersession.md` or phase-local supersession proof | documentation | transform / proof | `.planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md` | exact |

## Pattern Assignments

### `tool/verify_mobile_v2_semantic_firewall.dart` (utility, batch / file-I/O / transform)

**Analog:** `tool/verify_refactor_011_feature_boundaries.dart`

**Imports and CLI pattern** (lines 1-15):
```dart
import 'dart:collection';
import 'dart:io';

const featureBoundaryScanUsage =
    '''Usage: dart tool/verify_refactor_011_feature_boundaries.dart [--help]

Scans mobile/lib/features for cross-feature import/export directives.
This verifier is report-only: legacy edges and forbidden candidates are printed,
but the command exits successfully so existing violations can be tracked before
hard enforcement is introduced.
''';

const featureBoundarySuccessMarker =
    'REFACTOR-011 feature boundary report-only scan completed.';
```

**Adaptation for Phase 39:** keep the pure Dart, no-dependency shape, but make the mobile_v2 verifier fail closed instead of report-only. Usage should be `dart tool/verify_mobile_v2_semantic_firewall.dart [--help]`. Success marker should be unique, for example `M010-P39 mobile_v2 semantic firewall verified.`

**Directive parsing pattern** (lines 86-105):
```dart
final _directivePattern = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''');

Future<void> main(List<String> args) async {
  final options = FeatureBoundaryScanCliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(featureBoundaryScanUsage);
    return;
  }

  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(featureBoundaryScanUsage);
    exit(64);
  }

  final report = scanFeatureBoundaryImports(
    projectRoot: Directory.current.path,
  );
  stdout.write(renderFeatureBoundaryReport(report));
  stdout.writeln(featureBoundarySuccessMarker);
}
```

**Core file scan pattern** (lines 224-292):
```dart
final featureRoot = Directory('$resolvedProjectRoot/mobile/lib/features');

if (!featureRoot.existsSync()) {
  throw FileSystemException(
    'Mobile feature root does not exist',
    featureRoot.path,
  );
}

final dartFiles =
    featureRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('.g.dart'))
        .where((file) => !file.path.endsWith('.freezed.dart'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));

for (final dartFile in dartFiles) {
  final sourcePath = _projectRelativePath(dartFile.path, resolvedProjectRoot);
  final sourceFeature = featureFromProjectPath(sourcePath);
  if (sourceFeature == null) {
    continue;
  }

  final lines = dartFile.readAsLinesSync();
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    final directive = _parseDirective(lines[lineIndex]);
    if (directive == null) {
      continue;
    }
```

**Adaptation for Phase 39:** scan `mobile_v2/lib` recursively. If `mobile_v2/lib` does not exist yet, return a clear failure unless the planner intentionally creates a minimal skeleton first. Keep ignoring generated Dart files. Add a second pass over each line for banned terms: `phraseId`, `activityId`, `completedPhrase`, `completedPhraseCount`, `completedPhraseIds`, `nextPhraseId`, `currentStreakDays`, `streak`, and `GardenGrowth`.

**Report rendering pattern** (lines 339-371):
```dart
buffer.writeln('feature_boundary_import_scan_status=report_only');
buffer.writeln('project_root=${report.projectRoot}');
buffer.writeln('known_features=${knownMobileFeatures.join(',')}');
buffer.writeln('total_cross_feature_imports=${report.edges.length}');
for (final status in FeatureBoundaryStatus.values) {
  buffer.writeln('${status.label}=${report.countByStatus(status)}');
}

buffer.writeln('');
buffer.writeln('edges:');
if (report.edges.isEmpty) {
  buffer.writeln('  none');
} else {
  for (final edge in report.edges) {
    buffer.writeln(
      '  ${edge.status.label} ${edge.pair} ${edge.targetLayer} '
      '${edge.sourcePath}:${edge.lineNumber} ${edge.directive} '
      '${edge.importUri} | ${edge.reason}',
    );
  }
}
```

**Adaptation for Phase 39:** render separate sections for `forbidden_imports`, `banned_terms`, and `allowlisted_reference_paths`. Exit non-zero if forbidden imports or banned terms are found in runtime/product paths.

**Import URI normalization pattern** (lines 374-392):
```dart
String? projectPathForDartImport(
  String importUri, {
  required String sourcePath,
}) {
  if (importUri.startsWith('package:mobile/')) {
    return _normalizePath(
      'mobile/lib/${importUri.substring('package:mobile/'.length)}',
    );
  }

  if (importUri.startsWith('dart:') ||
      importUri.startsWith('package:') ||
      importUri.contains(':')) {
    return null;
  }

  final sourceDirectory = Uri.file(sourcePath).resolve('.');
  final resolvedPath = sourceDirectory.resolve(importUri).path;
  return _normalizePath(resolvedPath);
}
```

**Adaptation for Phase 39:** reject imports that resolve into old `mobile/lib/features/practice`, `mobile/lib/features/onboarding`, `mobile/lib/features/garden`, or other old product-domain/data/presentation paths. Do not reject `dart:` or external packages by default.

---

### `test/tool/verify_mobile_v2_semantic_firewall_test.dart` (test, batch / file-I/O)

**Analog:** `test/tool/verify_refactor_011_feature_boundaries_test.dart`

**Imports pattern** (lines 1-5):
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_refactor_011_feature_boundaries.dart' as verifier;
```

**Temp project fixture pattern** (lines 9-43):
```dart
test('classifies package and relative cross-feature imports', () async {
  final tempDir = await Directory.systemTemp.createTemp('refactor-011-');
  addTearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  await _writeProjectFile(
    tempDir,
    'mobile/lib/features/account/presentation/account_entry.dart',
    '''
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
export 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import '../domain/models/account_session.dart';
''',
  );

  final report = verifier.scanFeatureBoundaryImports(
    projectRoot: tempDir.path,
  );
```

**Assertions/report pattern** (lines 45-68):
```dart
expect(report.edges, hasLength(4));
expect(
  report.countByStatus(verifier.FeatureBoundaryStatus.legacyBridge),
  4,
);
expect(
  report.countByStatus(verifier.FeatureBoundaryStatus.forbiddenCandidate),
  0,
);

final rendered = verifier.renderFeatureBoundaryReport(report);
expect(
  rendered,
  contains('feature_boundary_import_scan_status=report_only'),
);
expect(rendered, contains('account->practice'));
```

**Fixture writer pattern** (lines 97-105):
```dart
Future<void> _writeProjectFile(
  Directory projectRoot,
  String relativePath,
  String content,
) async {
  final targetFile = File('${projectRoot.path}/$relativePath');
  await targetFile.parent.create(recursive: true);
  await targetFile.writeAsString(content);
}
```

**Adaptation for Phase 39:** create temp `mobile_v2/lib` files that prove: clean code passes; old `package:mobile/features/practice/...` import fails; relative import into old `mobile/lib/...` fails; banned terms fail in `mobile_v2/lib`; banned terms pass only in explicit quarantine/reference/test-fixture paths if the verifier intentionally scans them.

---

### `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` (test, delegation)

**Analog:** `mobile/test/tool/verify_m006_s14_release_closure_test.dart`

**Forwarder pattern** (lines 1-4):
```dart
import '../../../test/tool/verify_m006_s14_release_closure_test.dart'
    as root_test;

void main() => root_test.main();
```

**Adaptation for Phase 39:** if root/mobile Flutter test delegation needs a mobile-side entrypoint, create the same one-line wrapper pointing at `../../../test/tool/verify_mobile_v2_semantic_firewall_test.dart`.

---

### `mobile_v2/pubspec.yaml` (config, build config)

**Analog:** `mobile/pubspec.yaml`

**Pattern:** copy only the package-level Flutter dependency shape needed for a separate app/package. Keep `mobile_v2` independent from old `mobile`. Do not add `mobile` as a path dependency and do not use package imports that rely on old `package:mobile/...` domain, data, or presentation models.

**Planner note:** I did not read `mobile/pubspec.yaml` for excerpts because the phase research already captured the relevant stack: Flutter SDK, `flutter_test`, Riverpod, Freezed/json_serializable, and GoRouter. The planner should inspect the current file before generating a skeleton to avoid stale dependency versions.

---

### `mobile_v2/lib/app/theme/app_theme.dart` (utility / config, transform)

**Analog:** `mobile/lib/app/theme/app_theme.dart`

**Imports and ThemeExtension pattern** (lines 1-32):
```dart
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';

@immutable
class BabyTalkColors extends ThemeExtension<BabyTalkColors> {
  const BabyTalkColors({
    required this.bgBase,
    required this.bgSurface,
    required this.bgSunken,
    required this.bgAccentSoft,
    required this.accent,
    required this.accentDark,
    required this.english,
    required this.englishSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.info,
    required this.infoSoft,
    required this.outlineSoft,
    required this.warmShadowSm,
    required this.warmShadowMd,
    required this.warmShadowLg,
  });
```

**Light factory pattern** (lines 58-83):
```dart
factory BabyTalkColors.light() => const BabyTalkColors(
  bgBase: AppTheme.bgBase,
  bgSurface: AppTheme.bgSurface,
  bgSunken: AppTheme.bgSunken,
  bgAccentSoft: AppTheme.bgAccentSoft,
  accent: AppTheme.accent,
  accentDark: AppTheme.accentDark,
  english: AppTheme.english,
  englishSoft: AppTheme.englishSoft,
  textPrimary: AppTheme.textPrimary,
  textSecondary: AppTheme.textSecondary,
  textMuted: AppTheme.textMuted,
  success: AppTheme.success,
  successSoft: AppTheme.successSoft,
  warning: AppTheme.warning,
  warningSoft: AppTheme.warningSoft,
  error: AppTheme.error,
  errorSoft: AppTheme.errorSoft,
  info: AppTheme.info,
  infoSoft: AppTheme.infoSoft,
  outlineSoft: AppTheme.outlineSoft,
  warmShadowSm: AppTheme.warmShadowSm,
  warmShadowMd: AppTheme.warmShadowMd,
  warmShadowLg: AppTheme.warmShadowLg,
);
```

**Adaptation for Phase 39:** copy/rederive warm visual tokens only. Change imports to `package:mobile_v2/...`. Avoid carrying Garden growth/progress semantics through color names, visual labels, or component state names.

---

### `mobile_v2/lib/features/onboarding/...` (component / provider / model, event-driven UI)

**Analog:** `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart`

**Imports pattern to rederive, not copy verbatim** (lines 1-14):
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_design_widgets.dart';
```

**Low-pressure flow style pattern** (lines 45-75):
```dart
return OnboardingWarmScaffold(
  bottomNavigationBar: _BottomActionBar(notifier: notifier),
  child: Column(
    children: [
      _PracticeHeader(
        scene: scene,
        showEndAction: !notifier.showReactionPicker,
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          children: [
            if (notifier.showReactionPicker) ...[
              OnboardingProgressBar(
                current: notifier.currentPhraseIndex,
                total: notifier.totalPhrasesInScene,
              ),
              const SizedBox(height: 48),
              const OnboardingMentorBubble(
                message: '你说得真好，\n宝宝一定感受到了你的爱 ♡',
                assetName: OnboardingAssets.mentorPraying,
              ),
```

**Exit affordance pattern** (lines 140-151):
```dart
SizedBox(
  width: 72,
  child: showEndAction
      ? const SizedBox.shrink()
      : TextButton(
          onPressed: () => context.push('/onboarding/complete'),
          child: Text(
            '稍后再说',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
),
```

**Adaptation for Phase 39:** use the warm scaffold, mentor-bubble, gentle exit, and spacing style as reference. Do not copy `ScenePhrase`, `PracticeScene`, `currentPhraseIndex`, `totalPhrasesInScene`, phrase exhaustion, or starter-phrase semantics into `mobile_v2` product truth.

---

### `mobile_v2/lib/features/practice/...` (component / provider / model, event-driven UI)

**Analog:** `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`

**Interaction imports to quarantine semantically** (lines 1-9):
```dart
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_audio_button.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/widgets/scene_reaction_chip_row.dart';
import 'package:mobile/l10n/app_localizations.dart';
```

**Audio/pronunciation display pattern** (lines 158-191):
```dart
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
const SizedBox(height: AppLayoutConstants.spacingSm),
Text(
  phrase.pronunciation,
  textAlign: TextAlign.center,
  style: Theme.of(context).textTheme.bodySmall?.copyWith(
    fontFamily: 'JetBrains Mono',
    color: colors.textSecondary,
  ),
),
const SizedBox(height: 4),
Text(
  phrase.chinese,
  textAlign: TextAlign.center,
  style: Theme.of(context).textTheme.bodySmall?.copyWith(
    color: colors.textSecondary,
  ),
),
const SizedBox(height: AppLayoutConstants.spacingMd),
_buildPlayButton(context),
```

**Error/status message pattern** (lines 192-203):
```dart
if (playbackMessage != null) ...[
  const SizedBox(height: AppLayoutConstants.spacingSm),
  _MessageBanner(
    key: const Key('playback-banner'),
    message: playbackMessage!,
    backgroundColor: playbackStatus == PracticePlaybackStatus.error
        ? colors.errorSoft
        : colors.infoSoft,
    foregroundColor: playbackStatus == PracticePlaybackStatus.error
        ? colors.error
        : colors.info,
  ),
],
```

**Do not copy this semantic pattern** (lines 41-64):
```dart
final PracticePhrase phrase;
final bool isActive;
final bool isCompleted;
...
key: Key('phrase-card-${phrase.phraseId}'),
```

**Adaptation for Phase 39:** copy/rederive audio button, readable English sound display, pronunciation styling, and message banner interaction. Replace old `PracticePhrase`, `phraseId`, completion state, reaction-as-success, and phrase-card identity with micro-ritual concepts that pass the semantic firewall.

---

### `docs/mobile_v2_supersession.md` or phase-local supersession proof (documentation, transform / proof)

**Analog:** `.planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md`

**Surface boundary table pattern** (lines 63-70):
```markdown
## Surface Supersession Boundaries

| Surface | vNext WHAT | Invalid old assumptions | Deferred |
|---|---|---|---|
| Home | Orients the parent to the current family moment and whether a micro-ritual can lightly join. | Home is not a task dashboard, activity launcher, phrase card list, completion prompt, or route to "do more". | Layout, navigation, and concrete entry components go to discuss/plan. Activation prompts and capacity rules go to Phase 40. |
| Practice | Helps one family micro-ritual become speakable in a real routine without testing the child or completing a phrase list. | Practice is not phrase progression, fixed phrase completion, mandatory reaction capture, streak contribution, or "say N sentences". | Turn/state mechanics, runtime response contract, Primitive selection, Pack/Graph integration go to Phase 41. |
| Onboarding | Proves low-pressure entry into a first candidate micro-ritual and establishes parent comfort/readiness signals. | Onboarding is not primarily choosing an activity/path, collecting required profile fields, completing a fixed phrase set, or seeding `starterPhraseId` as product truth. | Exact onboarding flow, screens, data persistence, and consent UX go to discuss/plan; activation readiness policy goes to Phase 40. |
| Garden | Remembers parent-confirmed family-language transfer states without shame, score, streak, or completion pressure. | Garden is not growth/progress visualization from completed phrases, not streak tracking, not fertilizer/reward loop, and not automatic proof that a child learned. | Garden Memory state transition and parent-confirmation rules go to Phase 40; transfer metrics implementation go to Phase 41. |
```

**Supersession matrix pattern** (lines 72-99):
```markdown
## Supersession Matrix

| Item | Classification | Pass/fail rule |
|---|---|---|
| `Phrase` as core product unit | Deprecated | FAIL if a vNext plan treats phrase as the unit of product progress or family transfer. |
| `PracticePhrase` model and phrase catalog data | Reference only | PASS only if used as source material for wording/audio/examples; FAIL if copied as vNext domain truth. |
| `completedPhraseCount`, `completedPhraseIds`, `nextPhraseId`, "all phrases completed" | Deprecated | FAIL if completion count determines success, Garden state, or user progress. |
| Practice phrase card, audio, pronunciation, "I said it" widgets | Reference only | PASS only as interaction/material reference; FAIL if they define vNext loop completion. |
| Auth, consent, local-first sensitive data practices | Keep | PASS if reused without importing old product progression semantics. |
| Append-only event sourcing pattern | Keep | PASS if event truth is reused with new micro-ritual events, not old phrase completion meaning. |
```

**Adaptation for Phase 39:** if the plan adds a durable docs proof, keep this table-driven style. The proof should list every reused asset or file and classify it as Deprecated, Reference only, Re-derived, Deferred to Phase 40, Deferred to Phase 41, or Keep.

## Shared Patterns

### Semantic Firewall
**Source:** `tool/verify_refactor_011_feature_boundaries.dart` lines 224-292, 339-392  
**Apply to:** `tool/verify_mobile_v2_semantic_firewall.dart`, its tests, and any future `mobile_v2/lib` runtime path.

Rules to encode:
- `mobile_v2/lib` must not import old `mobile/lib/features/*` product/domain/data/presentation models.
- Banned old product terms fail in runtime paths.
- Generated files can be skipped only if generated from clean `mobile_v2` source; do not skip hand-written runtime files.
- Quarantine/reference paths are explicit and cannot feed UI/state/repository/domain truth.

### Test Fixture Style
**Source:** `test/tool/verify_refactor_011_feature_boundaries_test.dart` lines 9-43 and 97-105  
**Apply to:** verifier tests.

Use temp directories, write small project files, run the scanner directly, assert structured report contents, and clean up with `addTearDown`.

### Mobile Test Delegation
**Source:** `mobile/test/tool/verify_m006_s14_release_closure_test.dart` lines 1-4  
**Apply to:** optional mobile-side verifier test wrapper.

Keep mobile wrappers as simple root-test forwarders.

### Warm Visual Tone
**Source:** `mobile/lib/app/theme/app_theme.dart` lines 1-83  
**Apply to:** future `mobile_v2` theme and shared visual components.

Re-derive design tokens under `package:mobile_v2/...`; do not import `package:mobile/...` from runtime code.

### Reference-Only UI Interaction
**Source:** `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart` and `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`  
**Apply to:** future onboarding/practice surfaces.

Copy only interaction ideas: gentle exit, warm scaffold, English audio display, pronunciation styling, and non-alarming message banners. Do not copy phrase/activity/completion/streak/Garden-growth state.

## No Analog Found

None. Every implied file has at least a role-match analog. The closest matches for future `mobile_v2` UI are intentionally semantic-reference-only because old product meaning is deprecated.

## Metadata

**Analog search scope:** `tool/`, `test/tool/`, `mobile/test/tool/`, `.planning/phases/39-vnext-family-english-micro-ritual/`, `mobile/lib/app/`, `mobile/lib/features/onboarding/`, `mobile/lib/features/practice/presentation/widgets/`  
**Files scanned:** 20+ candidate files via `rg --files` plus targeted reads  
**Pattern extraction date:** 2026-06-15
