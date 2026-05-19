import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generated code location gate', () {
    test('rejects co-located generated outputs under lib/features', () {
      final offenders = _findFeatureGeneratedOutputs();

      expect(
        offenders,
        isEmpty,
        reason:
            'Generated Dart outputs must live under lib/generated/. Move these files and update part directives/build.yaml:\n${offenders.join('\n')}',
      );
    });

    test('feature part directives point at lib/generated outputs', () {
      final offenders = _findFeatureGeneratedPartDirectives();

      expect(
        offenders,
        isEmpty,
        reason:
            'Feature sources must not point part directives at co-located generated outputs. Update these directives to lib/generated/:\n${offenders.join('\n')}',
      );
    });
  });
}

List<String> _findFeatureGeneratedOutputs() {
  final featureRoot = Directory('lib/features');
  if (!featureRoot.existsSync()) {
    return const <String>[];
  }

  final offenders = <String>[];
  for (final entity in featureRoot.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final path = _normalizePath(entity.path);
    if (path.endsWith('.freezed.dart') || path.endsWith('.g.dart')) {
      offenders.add(path);
    }
  }
  offenders.sort();
  return offenders;
}

List<String> _findFeatureGeneratedPartDirectives() {
  final featureRoot = Directory('lib/features');
  if (!featureRoot.existsSync()) {
    return const <String>[];
  }

  final offenders = <String>[];
  final generatedPartPattern = RegExp(
    r'''part\s+['"]([^'"]+\.(?:freezed|g)\.dart)['"];''',
  );
  for (final entity in featureRoot.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final sourcePath = _normalizePath(entity.path);
    if (!sourcePath.endsWith('.dart') ||
        sourcePath.endsWith('.freezed.dart') ||
        sourcePath.endsWith('.g.dart')) {
      continue;
    }

    final source = entity.readAsStringSync();
    for (final match in generatedPartPattern.allMatches(source)) {
      final partPath = match.group(1)!;
      if (!partPath.contains('/generated/')) {
        offenders.add('$sourcePath -> $partPath');
      }
    }
  }
  offenders.sort();
  return offenders;
}

String _normalizePath(String path) => path.replaceAll('\\', '/');
