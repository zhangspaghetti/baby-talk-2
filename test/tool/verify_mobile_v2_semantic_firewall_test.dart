import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_mobile_v2_semantic_firewall.dart' as verifier;

void main() {
  group('M010-P39 mobile_v2 semantic firewall scan', () {
    test('allows clean Family English Micro-ritual boundary code', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mobile-v2-firewall-clean-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writeProjectFile(
        tempDir,
        'mobile_v2/lib/family_micro_ritual_boundary.dart',
        '''
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
''',
      );

      final report = verifier.scanMobileV2SemanticFirewall(
        projectRoot: tempDir.path,
      );

      expect(report.hasBlockingViolations, isFalse);
      expect(report.violations, isEmpty);
      expect(report.scannedRuntimeFileCount, 1);
      expect(
        verifier.renderMobileV2SemanticFirewallReport(report),
        contains('mobile_v2_semantic_firewall_status=pass'),
      );
    });

    test(
      'rejects forbidden package imports from old product features',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'mobile-v2-firewall-package-import-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        await _writeProjectFile(
          tempDir,
          'mobile_v2/lib/imports_old_practice.dart',
          '''
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
export 'package:mobile/features/garden/presentation/garden_screen.dart';
''',
        );

        final report = verifier.scanMobileV2SemanticFirewall(
          projectRoot: tempDir.path,
        );

        expect(
          report.countByType(
            verifier.MobileV2SemanticFirewallViolationType.forbiddenImport,
          ),
          3,
        );
        expect(report.hasBlockingViolations, isTrue);
        expect(
          report.violations.map((violation) => violation.reason),
          everyElement(contains('old mobile product feature')),
        );
      },
    );

    test(
      'rejects relative imports resolving into old product features',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'mobile-v2-firewall-relative-import-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        await _writeProjectFile(
          tempDir,
          'mobile_v2/lib/src/relative_old_import.dart',
          '''
import '../../../mobile/lib/features/practice/domain/models/practice_phrase.dart';
export '../../../mobile/lib/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'safe_local_boundary.dart';
''',
        );
        await _writeProjectFile(
          tempDir,
          'mobile_v2/lib/src/safe_local_boundary.dart',
          'class SafeLocalBoundary {}\n',
        );

        final report = verifier.scanMobileV2SemanticFirewall(
          projectRoot: tempDir.path,
        );

        expect(
          report.countByType(
            verifier.MobileV2SemanticFirewallViolationType.forbiddenImport,
          ),
          2,
        );
        expect(report.hasBlockingViolations, isTrue);
      },
    );

    test('rejects banned old runtime terms under mobile_v2/lib', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mobile-v2-firewall-banned-terms-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writeProjectFile(tempDir, 'mobile_v2/lib/old_semantics.dart', '''
class OldSemanticLeak {
  final String phraseId = 'p1';
  final String activityId = 'a1';
  final bool completedPhrase = false;
  final int completedPhraseCount = 0;
  final List<String> completedPhraseIds = [];
  final String nextPhraseId = 'p2';
  final int currentStreakDays = 3;
  final String streak = 'keep going';
  final String GardenGrowth = 'bloom';
  final String starterPhraseId = 'starter';
}
''');

      final report = verifier.scanMobileV2SemanticFirewall(
        projectRoot: tempDir.path,
      );

      expect(
        report.countByType(
          verifier.MobileV2SemanticFirewallViolationType.bannedRuntimeTerm,
        ),
        greaterThanOrEqualTo(10),
      );
      for (final term in const [
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
      ]) {
        expect(
          report.violations.any((violation) => violation.term == term),
          isTrue,
          reason: '$term should be reported',
        );
      }
    });

    test('reports old terms in allowlisted reference material only', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mobile-v2-firewall-allowlist-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writeProjectFile(
        tempDir,
        'mobile_v2/lib/boundary.dart',
        'class Boundary { final String fixedSound = "Peek-a-boo"; }\n',
      );
      await _writeProjectFile(
        tempDir,
        'mobile_v2/reference_assets/old_phrase_note.md',
        'old phraseId and completedPhrase material stays reference only\n',
      );
      await _writeProjectFile(
        tempDir,
        'mobile_v2/legacy_reference/garden_fixture.dart',
        'const oldGarden = "GardenGrowth currentStreakDays";\n',
      );
      await _writeProjectFile(
        tempDir,
        'mobile_v2/docs/migration-notes.md',
        'starterPhraseId is migration reference language only\n',
      );
      await _writeProjectFile(
        tempDir,
        'mobile_v2/test/fixtures/old_terms_fixture.dart',
        'const fixture = "activityId nextPhraseId streak";\n',
      );

      final report = verifier.scanMobileV2SemanticFirewall(
        projectRoot: tempDir.path,
      );

      expect(report.hasBlockingViolations, isFalse);
      expect(report.violations, isEmpty);
      final allowlistedPaths = report.allowlistedReferences
          .map((reference) => reference.sourcePath)
          .toSet();
      expect(allowlistedPaths, hasLength(4));
      expect(
        allowlistedPaths,
        containsAll([
          'mobile_v2/docs/migration-notes.md',
          'mobile_v2/legacy_reference/garden_fixture.dart',
          'mobile_v2/reference_assets/old_phrase_note.md',
          'mobile_v2/test/fixtures/old_terms_fixture.dart',
        ]),
      );
    });

    test('fails closed when mobile_v2/lib is missing', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mobile-v2-firewall-missing-lib-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final report = verifier.scanMobileV2SemanticFirewall(
        projectRoot: tempDir.path,
      );

      expect(report.hasBlockingViolations, isTrue);
      expect(
        report.countByType(
          verifier.MobileV2SemanticFirewallViolationType.missingBoundary,
        ),
        1,
      );
    });

    test('CLI rejects unknown arguments', () {
      final options = verifier.MobileV2SemanticFirewallCliOptions.parse(const [
        '--strict',
      ]);

      expect(options.usageError, contains('Unknown argument'));
    });
  });
}

Future<void> _writeProjectFile(
  Directory projectRoot,
  String relativePath,
  String content,
) async {
  final targetFile = File('${projectRoot.path}/$relativePath');
  await targetFile.parent.create(recursive: true);
  await targetFile.writeAsString(content);
}
