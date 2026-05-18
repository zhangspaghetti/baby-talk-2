import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_refactor_013_sensitive_lifecycle.dart' as verifier;

void main() {
  group('REFACTOR-013 sensitive data lifecycle scan', () {
    test('classifies documented local stores and the installation ID gap', () async {
      final tempDir = await Directory.systemTemp.createTemp('refactor-013-');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writeProjectFile(
        tempDir,
        verifier.sensitiveLifecyclePolicyPath,
        _policyDocumentWithAllSurfaces(),
      );
      await _writeProjectFile(
        tempDir,
        'mobile/lib/features/account/data/local/account_local_store.dart',
        'class AccountLocalStore { FlutterSecureStorage? s; Future<void> deleteIfExists() async {} }',
      );
      await _writeProjectFile(
        tempDir,
        'mobile/lib/features/onboarding/data/local/onboarding_snapshot_store.dart',
        'class OnboardingSnapshotStore { Future<void> deleteIfExists() async {} }',
      );
      await _writeProjectFile(
        tempDir,
        'mobile/lib/features/household/data/local/household_local_store.dart',
        'class HouseholdLocalStore { Future<void> deleteIfExists() async {} }',
      );
      await _writeProjectFile(
        tempDir,
        'mobile/lib/features/practice/data/local/practice_local_data_source.dart',
        'class PracticeLocalDataSource { Future<void> close({bool deleteFromDisk = false}) async {} }',
      );
      await _writeProjectFile(
        tempDir,
        'mobile/lib/features/mentor/data/local/mentor_local_data_source.dart',
        'class MentorLocalDataSource { Future<void> close({bool deleteFromDisk = false}) async {} }',
      );
      await _writeProjectFile(
        tempDir,
        'mobile/lib/core/device/installation_id_service.dart',
        'class InstallationIdService { Future<String?> readExisting() async => null; }',
      );

      final report = verifier.scanSensitiveLifecycle(projectRoot: tempDir.path);

      expect(report.findings, hasLength(6));
      expect(
        report.countByStatus(
          verifier.SensitiveLifecycleStatus.coveredDeletePrimitive,
        ),
        5,
      );
      expect(
        report.countByStatus(
          verifier.SensitiveLifecycleStatus.missingDeletePrimitive,
        ),
        1,
      );

      final installationFinding = report.findings.singleWhere(
        (finding) => finding.spec.id == 'installation_id',
      );
      expect(
        installationFinding.status,
        verifier.SensitiveLifecycleStatus.missingDeletePrimitive,
      );
      expect(
        installationFinding.missingDeletePrimitiveMarkers,
        contains('Future<void> deleteIfExists()'),
      );

      final rendered = verifier.renderSensitiveLifecycleReport(report);
      expect(rendered, contains('sensitive_lifecycle_scan_status=report_only'));
      expect(rendered, contains('account_local_snapshot'));
      expect(rendered, contains('installation_id'));
    });

    test('missing policy rows remain report-only documentation gaps', () async {
      final tempDir = await Directory.systemTemp.createTemp('refactor-013-');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writeProjectFile(
        tempDir,
        verifier.sensitiveLifecyclePolicyPath,
        '| Surface ID | Classification |\n|---|---|\n| account_local_snapshot | sensitive_account_auth |\n',
      );
      for (final spec in verifier.expectedSensitiveSurfaces) {
        await _writeProjectFile(
          tempDir,
          spec.sourcePath,
          '${spec.requiredSourceMarkers.join(' ')} ${spec.deletePrimitiveMarkers.join(' ')}',
        );
      }

      final report = verifier.scanSensitiveLifecycle(projectRoot: tempDir.path);

      expect(
        report.countByStatus(
          verifier.SensitiveLifecycleStatus.missingDocumentation,
        ),
        5,
      );
    });

    test('CLI rejects unknown arguments', () {
      final options = verifier.SensitiveLifecycleCliOptions.parse(const [
        '--strict',
      ]);

      expect(options.usageError, contains('Unknown argument'));
    });
  });
}

String _policyDocumentWithAllSurfaces() {
  final buffer = StringBuffer('| Surface ID | Classification |\n|---|---|\n');
  for (final spec in verifier.expectedSensitiveSurfaces) {
    buffer.writeln('| ${spec.id} | ${spec.classification} |');
  }
  return buffer.toString();
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
