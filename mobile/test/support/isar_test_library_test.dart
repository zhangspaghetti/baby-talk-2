import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'isar_test_library.dart';

void main() {
  late Directory cacheRoot;

  setUp(() {
    cacheRoot = Directory.systemTemp.createTempSync('isar-test-library-');
    final package = Directory(
      '${cacheRoot.path}${Platform.pathSeparator}hosted'
      '${Platform.pathSeparator}pub.dev'
      '${Platform.pathSeparator}isar_flutter_libs-3.1.0+1',
    );
    File(
      '${package.path}${Platform.pathSeparator}windows'
      '${Platform.pathSeparator}isar.dll',
    ).createSync(recursive: true);
    File(
      '${package.path}${Platform.pathSeparator}linux'
      '${Platform.pathSeparator}libisar.so',
    ).createSync(recursive: true);
  });

  tearDown(() {
    cacheRoot.deleteSync(recursive: true);
  });

  test('selects bundled Windows x64 Isar library', () {
    final path = resolveBundledIsarLibraryPath(
      abi: Abi.windowsX64,
      cacheRoots: [cacheRoot],
    );

    expect(path, endsWith('windows${Platform.pathSeparator}isar.dll'));
  });

  test('selects bundled Linux x64 Isar library', () {
    final path = resolveBundledIsarLibraryPath(
      abi: Abi.linuxX64,
      cacheRoots: [cacheRoot],
    );

    expect(path, endsWith('linux${Platform.pathSeparator}libisar.so'));
  });

  test('rejects an ABI without a bundled desktop test library', () {
    expect(
      () => resolveBundledIsarLibraryPath(
        abi: Abi.macosX64,
        cacheRoots: [cacheRoot],
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
