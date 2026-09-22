import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';

import '../../../support/generated_care_moment_fixture.dart';

void main() {
  late Directory tempDir;
  late GeneratedCareMomentLocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('generated_store_');
    store = GeneratedCareMomentLocalStore(
      directoryResolver: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('persists current safety policy and content refresh epoch', () async {
    final moment = generatedCareMomentFixture(
      generatedContentId: 'generated_1',
    );

    await store.upsert(
      StoredGeneratedCareMoment(accountContext: 'account_a', moment: moment),
    );

    final raw = await File(
      '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
    ).readAsString();
    final record =
        ((jsonDecode(raw) as Map<String, dynamic>)['records'] as List<dynamic>)
                .single
            as Map<String, dynamic>;
    expect(record['safetyPolicyVersion'], generatedCareSafetyPolicyVersion);
    expect(
      record['contentRefreshEpoch'],
      generatedCareMomentContentRefreshEpoch,
    );
    expect(
      (await store.readAll()).single.safetyPolicyVersion,
      generatedCareSafetyPolicyVersion,
    );
    expect(
      (await store.readAll()).single.contentRefreshEpoch,
      generatedCareMomentContentRefreshEpoch,
    );
  });

  test(
    'missing or stale provenance is removed before callers read content',
    () async {
      final moment = generatedCareMomentFixture(
        generatedContentId: 'generated_2',
      );
      await store.upsert(
        StoredGeneratedCareMoment(accountContext: 'account_a', moment: moment),
      );
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
      );
      final root =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final record =
          (root['records'] as List<dynamic>).single as Map<String, dynamic>;
      record['contentRefreshEpoch'] = 1;
      await file.writeAsString(jsonEncode(root));

      expect(await store.readAll(), isEmpty);
      expect(await store.readQuarantineDiagnostics(), hasLength(1));
      expect(
        await file.readAsString(),
        isNot(contains(moment.starter.english)),
      );
    },
  );
}
