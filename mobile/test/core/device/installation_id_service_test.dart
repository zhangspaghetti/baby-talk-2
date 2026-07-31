import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/device/installation_id_service.dart';

void main() {
  group('InstallationIdService', () {
    test('default ID satisfies backend discovery identity contract', () async {
      final tempDir = await Directory.systemTemp.createTemp('installation-id-');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = InstallationIdService(
        directoryResolver: () async => tempDir,
      );

      final installationId = await service.getOrCreate();

      expect(
        RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(installationId),
        isTrue,
      );
      expect(RegExp(r'[0-9]{11,}').hasMatch(installationId), isFalse);
    });

    test(
      'migrates unsupported persisted ID and reuses replacement after restart',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'installation-id-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final storedFile = File(
          '${tempDir.path}${Platform.pathSeparator}installation_id.txt',
        );
        await storedFile.writeAsString('install_1722391920000000_dead_beef');
        var generationCount = 0;
        final service = InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () {
            generationCount += 1;
            return 'install_safe_abcd_1234';
          },
        );

        expect(await service.getOrCreate(), 'install_safe_abcd_1234');
        expect(generationCount, 1);

        final restartedService = InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => throw StateError('must reuse persisted identity'),
        );
        expect(await restartedService.getOrCreate(), 'install_safe_abcd_1234');
        expect(await restartedService.readExisting(), 'install_safe_abcd_1234');
      },
    );

    test(
      'deleteIfExists removes the stored ID and allows regeneration',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'installation-id-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final generatedIds = Queue<String>.from(<String>[
          'install_first',
          'install_second',
        ]);
        final service = InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: generatedIds.removeFirst,
        );

        expect(await service.getOrCreate(), 'install_first');
        expect(await service.readExisting(), 'install_first');

        await service.deleteIfExists();

        expect(await service.readExisting(), isNull);
        expect(await service.getOrCreate(), 'install_second');
      },
    );

    test('deleteIfExists is idempotent when no stored ID exists', () async {
      final tempDir = await Directory.systemTemp.createTemp('installation-id-');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => 'install_unused',
      );

      await service.deleteIfExists();

      expect(await service.readExisting(), isNull);
    });
  });
}
