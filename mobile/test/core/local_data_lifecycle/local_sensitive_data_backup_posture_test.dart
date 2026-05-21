import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local sensitive data backup posture', () {
    test(
      'Android manifest disables cloud backup and device transfer extraction',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        final dataExtractionRules = File(
          'android/app/src/main/res/xml/data_extraction_rules.xml',
        ).readAsStringSync();

        expect(manifest, contains('android:allowBackup="false"'));
        expect(manifest, contains('android:fullBackupContent="false"'));
        expect(
          manifest,
          contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
        );
        expect(dataExtractionRules, contains('<cloud-backup>'));
        expect(dataExtractionRules, contains('<device-transfer>'));
        expect(
          dataExtractionRules,
          contains('<exclude domain="root" path="." />'),
        );
      },
    );

    test('iOS app delegate exposes backup exclusion method channel', () {
      final appDelegate = File(
        'ios/Runner/AppDelegate.swift',
      ).readAsStringSync();

      expect(appDelegate, contains('baby_talk/local_sensitive_data_backup'));
      expect(appDelegate, contains('excludeFromBackup'));
      expect(appDelegate, contains('LocalSensitiveDataBackupExcluder'));
      expect(appDelegate, contains('isExcludedFromBackup'));
      expect(appDelegate, contains('isExcludedFromBackupKey'));
    });

    test('iOS XCTest verifies runtime backup exclusion confirmation', () {
      final runnerTests = File(
        'ios/RunnerTests/RunnerTests.swift',
      ).readAsStringSync();

      expect(
        runnerTests,
        contains(
          'testLocalSensitiveDataBackupExcluderMarksDirectoryAsExcluded',
        ),
      );
      expect(runnerTests, contains('LocalSensitiveDataBackupExcluder'));
      expect(runnerTests, contains('isExcludedFromBackupKey'));
    });
  });
}
