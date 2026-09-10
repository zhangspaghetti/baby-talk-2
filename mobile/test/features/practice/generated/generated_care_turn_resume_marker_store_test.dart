import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';

void main() {
  group('GeneratedCareTurnResumeMarkerStore', () {
    late Directory tempDir;
    late String? householdScope;
    late GeneratedCareTurnResumeMarkerStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('generated_resume_');
      householdScope = null;
      store = GeneratedCareTurnResumeMarkerStore(
        directoryResolver: () async => tempDir,
        householdScopeLoader: () async => householdScope,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('clears only resume markers from revoked household scope', () async {
      householdScope = 'household_a';
      await store.write(
        accountContext: 'account_a',
        generatedContentId: 'generated_a',
        confirmedAt: DateTime.utc(2026, 9, 9),
      );
      householdScope = 'household_b';
      await store.write(
        accountContext: 'account_b',
        generatedContentId: 'generated_b',
        confirmedAt: DateTime.utc(2026, 9, 9),
      );
      householdScope = null;
      await store.write(
        accountContext: 'account_standalone',
        generatedContentId: 'generated_standalone',
        confirmedAt: DateTime.utc(2026, 9, 9),
      );

      await store.clearForHouseholdScope('household_a');

      expect(await store.readForAccount('account_a'), isNull);
      householdScope = 'household_b';
      expect(
        (await store.readForAccount('account_b'))?.generatedContentId,
        'generated_b',
      );
      householdScope = null;
      expect(
        (await store.readForAccount('account_standalone'))?.generatedContentId,
        'generated_standalone',
      );
      final raw = await File(
        '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
      ).readAsString();
      expect(raw, isNot(contains('household_a')));
      expect(raw, contains('householdScopeFingerprint'));
    });

    test(
      'does not return a marker after the current household scope changes',
      () async {
        householdScope = 'household_a';
        await store.write(
          accountContext: 'account_a',
          generatedContentId: 'generated_a',
          confirmedAt: DateTime.utc(2026, 9, 9),
        );
        householdScope = 'household_b';

        expect(await store.readForAccount('account_a'), isNull);
      },
    );

    test(
      'retries household marker cleanup after a failed replacement',
      () async {
        householdScope = 'household_a';
        await store.write(
          accountContext: 'account_a',
          generatedContentId: 'generated_a',
          confirmedAt: DateTime.utc(2026, 9, 9),
        );
        householdScope = 'household_b';
        await store.write(
          accountContext: 'account_b',
          generatedContentId: 'generated_b',
          confirmedAt: DateTime.utc(2026, 9, 9),
        );
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final temporary = Directory('${file.path}.tmp');
        await temporary.create();

        await expectLater(
          store.clearForHouseholdScope('household_a'),
          throwsA(isA<FileSystemException>()),
        );
        expect(await file.exists(), isTrue);
        expect(
          await File('${file.path}.clear').readAsString(),
          startsWith('household:'),
        );

        await temporary.delete();
        final recovered = GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => tempDir,
        );
        expect(await recovered.readForAccount('account_a'), isNull);
        expect(
          (await recovered.readForAccount('account_b'))?.generatedContentId,
          'generated_b',
        );
        expect(await File('${file.path}.clear').exists(), isFalse);
      },
    );

    test(
      'migrates legacy markers without household scope as standalone',
      () async {
        await store.write(
          accountContext: 'account_a',
          generatedContentId: 'generated_a',
          confirmedAt: DateTime.utc(2026, 9, 9),
        );
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final root =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        root['schemaVersion'] = 1;
        for (final value in root['records'] as List<dynamic>) {
          (value as Map<String, dynamic>).remove('householdScopeFingerprint');
        }
        await file.writeAsString(jsonEncode(root));

        expect(
          (await store.readForAccount('account_a'))?.generatedContentId,
          'generated_a',
        );
        final migrated =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(migrated['schemaVersion'], 2);
        expect(
          (migrated['records'] as List<dynamic>).single,
          isA<Map<String, dynamic>>().having(
            (record) => record['householdScopeFingerprint'],
            'householdScopeFingerprint',
            isNull,
          ),
        );
      },
    );

    test(
      'lifecycle clear is idempotent when resume directory is absent',
      () async {
        final missingDirectory = Directory(
          '${tempDir.path}${Platform.pathSeparator}missing_resume_directory',
        );
        final missingStore = GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => missingDirectory,
        );

        await missingStore.clearForLifecycle();

        expect(await missingDirectory.exists(), isFalse);
      },
    );

    test('serializes writes from instances sharing a canonical path', () async {
      final first = GeneratedCareTurnResumeMarkerStore(
        directoryResolver: () async => tempDir,
      );
      final alias = GeneratedCareTurnResumeMarkerStore(
        directoryResolver: () async =>
            Directory('${tempDir.path}${Platform.pathSeparator}.'),
      );

      await Future.wait(<Future<void>>[
        for (var index = 0; index < 4; index++)
          first.write(
            accountContext: 'account_first_$index',
            generatedContentId: 'generated_first_$index',
            confirmedAt: DateTime.utc(2026, 9, 9),
          ),
        for (var index = 0; index < 4; index++)
          alias.write(
            accountContext: 'account_alias_$index',
            generatedContentId: 'generated_alias_$index',
            confirmedAt: DateTime.utc(2026, 9, 9),
          ),
      ]);

      final records =
          jsonDecode(
                await File(
                  '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect((records['records'] as List<dynamic>), hasLength(8));
      for (var index = 0; index < 4; index++) {
        expect(
          (await first.readForAccount(
            'account_first_$index',
          ))?.generatedContentId,
          'generated_first_$index',
        );
        expect(
          (await alias.readForAccount(
            'account_alias_$index',
          ))?.generatedContentId,
          'generated_alias_$index',
        );
      }
    });
  });
}
