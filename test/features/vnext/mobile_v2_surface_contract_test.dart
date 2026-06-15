import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/verify_mobile_v2_semantic_firewall.dart' as verifier;

void main() {
  group('mobile_v2 surface semantic contracts', () {
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

    test('rejects Home next-incomplete-task semantics', () async {
      final report = await _scanSurfaceFixture(
        'features/home/current_moment_orientation.dart',
        '''
class CurrentMomentOrientation {
  final String nextPhraseId = 'next-incomplete-task';
}
''',
      );

      _expectBannedTerm(report, 'nextPhraseId');
    });

    test('rejects Practice phrase-completion semantics', () async {
      final report = await _scanSurfaceFixture(
        'features/practice/micro_ritual_support.dart',
        '''
class MicroRitualSupport {
  final bool completedPhrase = true;
  final int completedPhraseCount = 1;
  final List<String> completedPhraseIds = ['old'];
}
''',
      );

      _expectBannedTerm(report, 'completedPhrase');
      _expectBannedTerm(report, 'completedPhraseCount');
      _expectBannedTerm(report, 'completedPhraseIds');
    });

    test('rejects Practice child-response-required tracking terms', () async {
      final report = await _scanSurfaceFixture(
        'features/practice/child_response_required.dart',
        '''
class ChildResponseRequiredPractice {
  final String phraseId = 'old-phrase';
  final String activityId = 'old-activity';
}
''',
      );

      _expectBannedTerm(report, 'phraseId');
      _expectBannedTerm(report, 'activityId');
    });

    test('rejects Garden streak and old growth semantics', () async {
      final report = await _scanSurfaceFixture(
        'features/garden/non_scoring_memory_boundary.dart',
        '''
class NonScoringMemoryBoundary {
  final int currentStreakDays = 7;
  final String streak = 'daily';
  final String GardenGrowth = 'flower-stage';
}
''',
      );

      _expectBannedTerm(report, 'currentStreakDays');
      _expectBannedTerm(report, 'streak');
      _expectBannedTerm(report, 'GardenGrowth');
    });
  });
}

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

  final targetFile = File('${tempDir.path}/mobile_v2/lib/$runtimePath');
  await targetFile.parent.create(recursive: true);
  await targetFile.writeAsString(content);

  return verifier.scanMobileV2SemanticFirewall(projectRoot: tempDir.path);
}

void _expectBannedTerm(
  verifier.MobileV2SemanticFirewallReport report,
  String term,
) {
  expect(report.hasBlockingViolations, isTrue);
  expect(
    report.violations.any(
      (violation) =>
          violation.type ==
              verifier.MobileV2SemanticFirewallViolationType.bannedRuntimeTerm &&
          violation.term == term,
    ),
    isTrue,
    reason: '$term should be rejected in mobile_v2 surface runtime paths',
  );
}
