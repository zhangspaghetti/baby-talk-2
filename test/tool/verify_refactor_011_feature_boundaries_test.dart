import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_refactor_011_feature_boundaries.dart' as verifier;

void main() {
  group('REFACTOR-011 feature boundary scan', () {
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
      await _writeProjectFile(
        tempDir,
        'mobile/lib/features/share/presentation/share_notifier.dart',
        '''
import '../../practice/domain/models/garden_growth_snapshot.dart';
''',
      );
      await _writeProjectFile(
        tempDir,
        'mobile/lib/features/shell/presentation/app_shell.dart',
        '''
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
''',
      );

      final report = verifier.scanFeatureBoundaryImports(
        projectRoot: tempDir.path,
      );

      expect(report.edges, hasLength(4));
      expect(
        report.countByStatus(verifier.FeatureBoundaryStatus.legacyBridge),
        4,
      );
      expect(
        report.countByStatus(verifier.FeatureBoundaryStatus.forbiddenCandidate),
        0,
      );

      final shareEdge = report.edges.singleWhere(
        (edge) => edge.sourceFeature == 'share',
      );
      expect(shareEdge.targetFeature, 'practice');
      expect(shareEdge.targetLayer, 'domain');

      final rendered = verifier.renderFeatureBoundaryReport(report);
      expect(
        rendered,
        contains('feature_boundary_import_scan_status=report_only'),
      );
      expect(rendered, contains('account->practice'));
      expect(rendered, contains('share->practice'));
      expect(rendered, contains('shell->practice'));
    });

    test(
      'unknown source-to-target pairs are report-only forbidden candidates',
      () {
        final classification = verifier.classifyFeatureImport(
          'practice',
          'mentor',
        );

        expect(
          classification.status,
          verifier.FeatureBoundaryStatus.forbiddenCandidate,
        );
        expect(classification.reason, contains('no REFACTOR-011'));
      },
    );

    test('CLI rejects unknown arguments', () {
      final options = verifier.FeatureBoundaryScanCliOptions.parse(const [
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
