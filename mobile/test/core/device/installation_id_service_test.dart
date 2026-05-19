import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/device/installation_id_service.dart';

void main() {
  group('InstallationIdService', () {
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
