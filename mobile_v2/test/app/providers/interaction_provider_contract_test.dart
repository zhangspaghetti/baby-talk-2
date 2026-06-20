import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Riverpod stays outside domain and data', () {
    final files = [
      ...Directory(
        'lib/features/ritual_room/domain',
      ).listSync(recursive: true).whereType<File>(),
      ...Directory(
        'lib/features/ritual_room/data',
      ).listSync(recursive: true).whereType<File>(),
    ].where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains('flutter_riverpod')),
        reason: file.path,
      );
    }
  });

  test('provider graph contains no ritual copy or capability dependency', () {
    final providerDirectory = Directory('lib/app/providers');
    final files = providerDirectory.existsSync()
        ? providerDirectory
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .toList()
        : <File>[];

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('Shoes on.')), reason: file.path);
      expect(source, isNot(contains('我们来穿鞋吧')), reason: file.path);
      if (!file.path.endsWith('ritual_room_capability_provider.dart')) {
        expect(
          source,
          isNot(contains('interactionCapabilityMaskProvider')),
          reason: file.path,
        );
      }
    }
  });

  test(
    'provider production files exist and contain no mutable state provider',
    () {
      final required = [
        'lib/app/providers/interaction_engine_providers.dart',
        'lib/app/providers/ritual_room_data_providers.dart',
        'lib/app/providers/ritual_room_capability_provider.dart',
        'lib/app/input/interaction_input_factory.dart',
        'lib/features/ritual_room/presentation/capability/interaction_capability_mask.dart',
      ];

      for (final path in required) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      final providerSources = required
          .where((path) => path.contains('/providers/'))
          .map((path) => File(path).readAsStringSync())
          .join('\n');
      expect(providerSources, isNot(contains('NotifierProvider')));
      expect(providerSources, isNot(contains('ProviderContainer')));
    },
  );
}
