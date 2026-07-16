import 'dart:ffi';
import 'dart:io';

String resolveBundledIsarLibraryPath({
  Abi? abi,
  Iterable<Directory>? cacheRoots,
}) {
  final targetAbi = abi ?? Abi.current();
  final (platformDirectory, libraryName) = switch (targetAbi) {
    Abi.windowsX64 => ('windows', 'isar.dll'),
    Abi.linuxX64 => ('linux', 'libisar.so'),
    _ => throw UnsupportedError(
      'No bundled Isar test library is supported for ABI $targetAbi.',
    ),
  };

  final roots = cacheRoots ?? _defaultPubCacheRoots();
  for (final root in roots) {
    final hostedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}hosted',
    );
    if (!hostedDirectory.existsSync()) {
      continue;
    }

    for (final host in hostedDirectory.listSync().whereType<Directory>()) {
      for (final packageDirectory in host.listSync().whereType<Directory>()) {
        final packageName = packageDirectory.path.split(RegExp(r'[\\/]')).last;
        if (!packageName.startsWith('isar_flutter_libs-')) {
          continue;
        }

        final library = File(
          '${packageDirectory.path}${Platform.pathSeparator}'
          '$platformDirectory${Platform.pathSeparator}$libraryName',
        );
        if (library.existsSync()) {
          return library.path;
        }
      }
    }
  }

  throw StateError(
    'Unable to locate isar_flutter_libs/$platformDirectory/$libraryName.',
  );
}

Iterable<Directory> _defaultPubCacheRoots() sync* {
  final environment = Platform.environment;
  final pubCache = environment['PUB_CACHE'];
  if (pubCache != null && pubCache.isNotEmpty) {
    yield Directory(pubCache);
  }

  final localAppData = environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    yield Directory(
      '$localAppData${Platform.pathSeparator}Pub'
      '${Platform.pathSeparator}Cache',
    );
  }

  final home = environment['HOME'];
  if (home != null && home.isNotEmpty) {
    yield Directory('$home${Platform.pathSeparator}.pub-cache');
  }
}
