import 'dart:io';

/// Read-only guard for the generated-care reaction event contract.
///
/// This verifier intentionally checks structural guards only. Runtime behavior
/// (exact-once persistence and Garden/Today projections) remains covered by
/// `generated_practice_content_registry_test.dart`.
void main() {
  final repoRoot = _resolveRepoRoot();
  final checks = <_SourceCheck>[
    _SourceCheck(
      path:
          'mobile/lib/features/practice/domain/models/interaction_event_payload.dart',
      requiredMarkers: const [
        'String? generatedContentId',
        'String? utteranceId',
        'normalizedGeneratedContentId == null) !=',
        "'generatedContentId': generatedContentId",
        "'utteranceId': utteranceId",
      ],
    ),
    _SourceCheck(
      path:
          'mobile/lib/features/practice/data/local/interaction_event_entity.dart',
      requiredMarkers: const [
        'String? generatedContentId',
        'String? utteranceId',
        'generatedContentId = payload.generatedContentId',
        'utteranceId = payload.utteranceId',
      ],
    ),
    _SourceCheck(
      path:
          'mobile/lib/features/practice/data/repositories/practice_repository.dart',
      requiredMarkers: const [
        'generated_reaction_',
        '_matchesGeneratedEvent',
        'normalizedGeneratedContentId != expectedGeneratedContentId',
        'return event.utteranceId == snapshot.utteranceIdForPhrase',
      ],
    ),
    _SourceCheck(
      path:
          'mobile/lib/features/care_path/data/repositories/care_path_repository.dart',
      requiredMarkers: const [
        'GeneratedCareAudioSource',
        'generatedContentId: generatedContentId',
        'utteranceId: utteranceId',
      ],
    ),
    _SourceCheck(
      path:
          'mobile/lib/features/practice/data/repositories/garden_growth_repository.dart',
      requiredMarkers: const [
        '已记下这次照护回应。',
        '已保留这次照护记录。',
        'completedActivityCount: 0',
        'completedPhraseCount: 0',
      ],
    ),
    _SourceCheck(
      path:
          'mobile/test/features/practice/generated/generated_practice_content_registry_test.dart',
      requiredMarkers: const [
        'generated tuple isolates exact-once trace, Garden, and Today continuity',
        'expect(generatedGardenPatch.activities.single.completedPhraseCount, 0);',
        'generatedContentId, first.generatedContentId',
      ],
    ),
  ];

  final violations = <String>[];
  for (final check in checks) {
    final file = File('${repoRoot.path}${Platform.pathSeparator}${check.path}');
    if (!file.existsSync()) {
      violations.add('${check.path}: missing required source file');
      continue;
    }

    final source = file.readAsStringSync();
    for (final marker in check.requiredMarkers) {
      if (!source.contains(marker)) {
        violations.add('${check.path}: missing contract marker `$marker`');
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('M2 generated reaction contract: FAIL');
    for (final violation in violations) {
      stderr.writeln('- $violation');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('M2 generated reaction contract: PASS');
  stdout.writeln(
    'Runtime evidence: cd mobile && flutter test '
    'test/features/practice/generated/generated_practice_content_registry_test.dart',
  );
}

Directory _resolveRepoRoot() {
  final current = Directory.current;
  final mobileAtCurrent = Directory(
    '${current.path}${Platform.pathSeparator}mobile',
  );
  if (mobileAtCurrent.existsSync()) {
    return current;
  }

  final mobileWorkingDirectory = Directory(
    '${current.path}${Platform.pathSeparator}lib',
  );
  final toolAtParent = Directory(
    '${current.parent.path}${Platform.pathSeparator}tool',
  );
  if (mobileWorkingDirectory.existsSync() && toolAtParent.existsSync()) {
    return current.parent;
  }

  throw StateError(
    'Run this verifier from the repository root or its mobile directory.',
  );
}

class _SourceCheck {
  const _SourceCheck({required this.path, required this.requiredMarkers});

  final String path;
  final List<String> requiredMarkers;
}
