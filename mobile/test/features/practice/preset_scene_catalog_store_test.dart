import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/data/local/preset_scene_catalog_store.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';

void main() {
  group('PresetSceneCatalogStore', () {
    late Directory tempDir;
    late PresetSceneCatalogStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('preset_catalog_store_');
      store = PresetSceneCatalogStore(directoryResolver: () async => tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('distinguishes missing cache from a valid empty snapshot', () async {
      final missing = await store.readResult();
      expect(missing.status, PresetSceneCatalogStoreReadStatus.notFound);
      expect(missing.snapshot, isNull);

      await store.write(_snapshot(const <PresetSceneDefinition>[]));
      final empty = await store.readResult();
      expect(empty.status, PresetSceneCatalogStoreReadStatus.available);
      expect(empty.snapshot, isNotNull);
      expect(empty.snapshot!.scenes, isEmpty);
    });

    test(
      'round-trips exact fields and API order through versioned JSON',
      () async {
        final snapshot = _snapshot(<PresetSceneDefinition>[
          _definition('bedtime', sortOrder: 99),
          _definition('bath_time', sortOrder: 1),
        ]);

        await store.write(snapshot);

        final raw = await File(
          '${tempDir.path}/preset_scene_catalog.json',
        ).readAsString();
        expect(jsonDecode(raw), <String, Object>{
          'schemaVersion': 1,
          'scenes': <Object>[
            <String, Object>{
              'presetSceneId': 'bedtime',
              'publishedVersion': 1,
              'spaceId': 'daily_care',
              'title': 'Title bedtime',
              'summary': 'Summary bedtime',
              'sceneTag': 'tag_bedtime',
              'coachTip': 'Tip bedtime',
              'sortOrder': 99,
            },
            <String, Object>{
              'presetSceneId': 'bath_time',
              'publishedVersion': 1,
              'spaceId': 'daily_care',
              'title': 'Title bath_time',
              'summary': 'Summary bath_time',
              'sceneTag': 'tag_bath_time',
              'coachTip': 'Tip bath_time',
              'sortOrder': 1,
            },
          ],
        });
        final roundTrip = await store.read();
        expect(roundTrip!.scenes.map((scene) => scene.presetSceneId), [
          'bedtime',
          'bath_time',
        ]);
      },
    );

    test(
      'uses temporary sibling and leaves no temporary file after atomic write',
      () async {
        await store.write(
          _snapshot(<PresetSceneDefinition>[_definition('bath_time')]),
        );

        expect(
          File('${tempDir.path}/preset_scene_catalog.json').existsSync(),
          isTrue,
        );
        expect(
          File('${tempDir.path}/preset_scene_catalog.json.tmp').existsSync(),
          isFalse,
        );
      },
    );

    test(
      'quarantines malformed cache and bounds retained quarantine files',
      () async {
        final primary = File('${tempDir.path}/preset_scene_catalog.json');
        await primary.parent.create(recursive: true);
        await primary.writeAsString(
          '{"schemaVersion":1,"scenes":[{"generationBrief":"secret"}]}',
        );
        for (
          var index = 1;
          index <= PresetSceneCatalogStore.maxQuarantineFiles + 1;
          index++
        ) {
          await File(
            '${primary.path}.quarantine.$index',
          ).writeAsString('old $index');
        }

        final result = await store.readResult();

        expect(result.status, PresetSceneCatalogStoreReadStatus.malformed);
        expect(result.snapshot, isNull);
        expect(primary.existsSync(), isFalse);
        final retained = tempDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.contains('.quarantine.'))
            .toList();
        expect(
          retained.length,
          lessThanOrEqualTo(PresetSceneCatalogStore.maxQuarantineFiles),
        );
      },
    );

    test(
      'restores existing last-good cache when final replacement fails',
      () async {
        await store.write(
          _snapshot(<PresetSceneDefinition>[_definition('old_scene')]),
        );
        var failFinalRename = true;
        final failingStore = PresetSceneCatalogStore(
          directoryResolver: () async => tempDir,
          renameFile: (source, target) async {
            if (failFinalRename &&
                source.path.endsWith('.tmp') &&
                target.endsWith('preset_scene_catalog.json')) {
              failFinalRename = false;
              throw const FileSystemException(
                'simulated final replace failure',
              );
            }
            return source.rename(target);
          },
        );

        await expectLater(
          failingStore.write(
            _snapshot(<PresetSceneDefinition>[_definition('new_scene')]),
          ),
          throwsA(isA<PresetSceneCatalogStoreException>()),
        );
        final restored = await store.read();
        expect(restored!.scenes.single.presetSceneId, 'old_scene');
        expect(
          File('${tempDir.path}/preset_scene_catalog.json.tmp').existsSync(),
          isFalse,
        );
        expect(
          File('${tempDir.path}/preset_scene_catalog.json.bak').existsSync(),
          isFalse,
        );
      },
    );

    test(
      'strictly rejects invalid UTF-8 as malformed and quarantines it',
      () async {
        final file = File('${tempDir.path}/preset_scene_catalog.json');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(<int>[0x7b, 0xff, 0x7d]);

        final result = await store.readResult();

        expect(result.status, PresetSceneCatalogStoreReadStatus.malformed);
        expect(file.existsSync(), isFalse);
        expect(
          tempDir.listSync().whereType<File>().any(
            (entry) => entry.path.contains('.quarantine.'),
          ),
          isTrue,
        );
      },
    );

    test('keeps I/O read failures distinct from malformed cache', () async {
      final failingStore = PresetSceneCatalogStore(
        directoryResolver: () async {
          throw const FileSystemException('support directory unavailable');
        },
      );

      final result = await failingStore.readResult();

      expect(result.status, PresetSceneCatalogStoreReadStatus.ioFailure);
      expect(result.snapshot, isNull);
    });

    test(
      'clearForLifecycle removes cache, quarantine, temporary, and backup artifacts',
      () async {
        final primary = File('${tempDir.path}/preset_scene_catalog.json');
        await store.write(
          _snapshot(<PresetSceneDefinition>[_definition('bath_time')]),
        );
        await File('${primary.path}.tmp').writeAsString('temporary');
        await File('${primary.path}.bak').writeAsString('backup');
        await File('${primary.path}.quarantine.1').writeAsString('quarantine');
        await File(
          '${primary.path}.quarantine.99',
        ).writeAsString('old quarantine');

        await store.clearForLifecycle();

        expect(await primary.exists(), isFalse);
        expect(await File('${primary.path}.tmp').exists(), isFalse);
        expect(await File('${primary.path}.bak').exists(), isFalse);
        expect(
          tempDir.listSync().whereType<File>().where(
            (file) => file.path.contains('.preset_scene_catalog.json.'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'lifecycle marker makes reads fail closed and blocks late writes until recovery',
      () async {
        final primary = File('${tempDir.path}/preset_scene_catalog.json');
        await store.write(
          _snapshot(<PresetSceneDefinition>[_definition('old_scene')]),
        );
        await File('${primary.path}.tmp').writeAsString('temporary');
        await File('${primary.path}.bak').writeAsString('backup');
        await File('${primary.path}.quarantine.1').writeAsString('quarantine');
        final marker = File('${primary.path}.clear');
        await marker.writeAsString('clear', flush: true);

        await expectLater(
          store.write(_snapshot(<PresetSceneDefinition>[_definition('late')])),
          throwsA(isA<PresetSceneCatalogStoreException>()),
        );
        expect(await primary.exists(), isTrue);

        final result = await store.readResult();

        expect(result.status, PresetSceneCatalogStoreReadStatus.notFound);
        expect(await primary.exists(), isFalse);
        expect(await marker.exists(), isFalse);
        expect(await File('${primary.path}.tmp').exists(), isFalse);
        expect(await File('${primary.path}.bak').exists(), isFalse);
        expect(
          tempDir.listSync().whereType<File>().any(
            (file) => file.path.contains('.quarantine.'),
          ),
          isFalse,
        );
      },
    );
  });
}

PresetSceneCatalogSnapshot _snapshot(List<PresetSceneDefinition> scenes) {
  return PresetSceneCatalogSnapshot(
    source: PresetSceneCatalogSource.remote,
    scenes: scenes,
  );
}

PresetSceneDefinition _definition(String id, {int sortOrder = 1}) {
  return PresetSceneDefinition(
    presetSceneId: id,
    publishedVersion: 1,
    spaceId: 'daily_care',
    title: 'Title $id',
    summary: 'Summary $id',
    sceneTag: 'tag_$id',
    coachTip: 'Tip $id',
    sortOrder: sortOrder,
  );
}
