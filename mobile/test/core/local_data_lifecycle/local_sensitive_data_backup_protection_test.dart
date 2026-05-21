import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_backup_protection.dart';

void main() {
  group('LocalSensitiveDataBackupProtection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'backup_protection_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'returns directory without native call when platform does not require it',
      () async {
        var nativeCalled = false;
        final protection = LocalSensitiveDataBackupProtection(
          requiresNativeExclusion: () => false,
          nativeExcluder: (_) async {
            nativeCalled = true;
            return true;
          },
        );

        final result = await protection
            .ensureDirectoryExcludedFromBackupIfRequired(tempDir);

        expect(result.path, tempDir.path);
        expect(nativeCalled, isFalse);
      },
    );

    test(
      'uses native exclusion when platform requires backup protection',
      () async {
        final requestedPaths = <String>[];
        final protection = LocalSensitiveDataBackupProtection(
          requiresNativeExclusion: () => true,
          nativeExcluder: (path) async {
            requestedPaths.add(path);
            return true;
          },
        );

        final result = await protection
            .ensureDirectoryExcludedFromBackupIfRequired(tempDir);

        expect(result.path, tempDir.path);
        expect(requestedPaths, <String>[tempDir.path]);
      },
    );

    test('fails closed when native exclusion is not confirmed', () async {
      final protection = LocalSensitiveDataBackupProtection(
        requiresNativeExclusion: () => true,
        nativeExcluder: (_) async => false,
      );

      await expectLater(
        protection.ensureDirectoryExcludedFromBackupIfRequired(tempDir),
        throwsA(isA<LocalSensitiveDataBackupProtectionException>()),
      );
    });
  });
}
