import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';
import 'package:path_provider/path_provider.dart';

typedef PresetSceneCatalogDirectoryResolver = Future<Directory> Function();
typedef PresetSceneCatalogFileExists = Future<bool> Function(File file);
typedef PresetSceneCatalogFileDelete = Future<void> Function(File file);
typedef PresetSceneCatalogFileRename =
    Future<File> Function(File source, String targetPath);
typedef PresetSceneCatalogFileWrite =
    Future<void> Function(File file, String contents, {required bool flush});

enum PresetSceneCatalogStoreReadStatus {
  notFound,
  available,
  malformed,
  ioFailure,
}

class PresetSceneCatalogStoreReadResult {
  const PresetSceneCatalogStoreReadResult({
    required this.status,
    this.snapshot,
  });

  final PresetSceneCatalogStoreReadStatus status;
  final PresetSceneCatalogSnapshot? snapshot;
}

/// Atomic last-good cache for public preset metadata.
class PresetSceneCatalogStore {
  PresetSceneCatalogStore({
    PresetSceneCatalogDirectoryResolver? directoryResolver,
    this.fileName = 'preset_scene_catalog.json',
    PresetSceneCatalogFileExists? existsFile,
    PresetSceneCatalogFileDelete? deleteFile,
    PresetSceneCatalogFileRename? renameFile,
    PresetSceneCatalogFileWrite? writeFile,
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory,
       _existsFile = existsFile ?? _defaultExists,
       _deleteFile = deleteFile ?? _defaultDelete,
       _renameFile = renameFile ?? _defaultRename,
       _writeFile = writeFile ?? _defaultWrite;

  static const int schemaVersion = 1;
  static const int maxQuarantineFiles = 3;

  final PresetSceneCatalogDirectoryResolver _directoryResolver;
  final PresetSceneCatalogFileExists _existsFile;
  final PresetSceneCatalogFileDelete _deleteFile;
  final PresetSceneCatalogFileRename _renameFile;
  final PresetSceneCatalogFileWrite _writeFile;
  final String fileName;
  Future<void> _mutationTail = Future<void>.value();

  Future<PresetSceneCatalogSnapshot?> read() async {
    return (await readResult()).snapshot;
  }

  Future<PresetSceneCatalogSnapshot?> readSnapshot() => read();

  Future<PresetSceneCatalogStoreReadResult> readResult() {
    return _enqueueMutation(_readResult);
  }

  Future<PresetSceneCatalogStoreReadResult> _readResult() async {
    final File file;
    try {
      file = await _resolveFile();
      if (!await _existsFile(file)) {
        await _restoreBackupIfNeeded(file);
      }
      if (!await _existsFile(file)) {
        return const PresetSceneCatalogStoreReadResult(
          status: PresetSceneCatalogStoreReadStatus.notFound,
        );
      }
    } on Object {
      return const PresetSceneCatalogStoreReadResult(
        status: PresetSceneCatalogStoreReadStatus.ioFailure,
      );
    }

    final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object {
      return const PresetSceneCatalogStoreReadResult(
        status: PresetSceneCatalogStoreReadStatus.ioFailure,
      );
    }

    final String raw;
    try {
      raw = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return _malformedResult(file);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('preset catalog root is invalid');
      }
      if (decoded.keys.any((key) => key is! String)) {
        throw const FormatException('preset catalog root keys are invalid');
      }
      final root = Map<String, dynamic>.from(decoded);
      _requireExactKeys(root, const <String>{'schemaVersion', 'scenes'});
      final version = root['schemaVersion'];
      if (version is! int || version != schemaVersion) {
        throw const FormatException('preset catalog schema is unsupported');
      }
      final scenes = PresetSceneDefinition.parseList(root['scenes']);
      return PresetSceneCatalogStoreReadResult(
        status: PresetSceneCatalogStoreReadStatus.available,
        snapshot: PresetSceneCatalogSnapshot(
          source: PresetSceneCatalogSource.cache,
          scenes: scenes,
        ),
      );
    } on Object {
      return _malformedResult(file);
    }
  }

  Future<void> write(PresetSceneCatalogSnapshot snapshot) {
    return _enqueueMutation(() => _write(snapshot));
  }

  Future<void> writeScenes(Iterable<PresetSceneDefinition> scenes) {
    return write(
      PresetSceneCatalogSnapshot(
        source: PresetSceneCatalogSource.remote,
        scenes: scenes,
      ),
    );
  }

  Future<void> _write(PresetSceneCatalogSnapshot snapshot) async {
    // Validate before touching the last-good file. The remote API already
    // validates, but this protects direct store callers and cache migrations.
    final scenes = PresetSceneDefinition.parseList(
      snapshot.scenes.map((scene) => scene.toJsonMap()).toList(growable: false),
    );
    File? temporaryFile;
    File? backupFile;
    var backupCreated = false;
    try {
      final file = await _resolveFile();
      temporaryFile = File('${file.path}.tmp');
      backupFile = File('${file.path}.bak');
      await file.parent.create(recursive: true);
      await _deleteFileIfExists(temporaryFile);
      final root = <String, Object?>{
        'schemaVersion': schemaVersion,
        'scenes': scenes
            .map((scene) => scene.toJsonMap())
            .toList(growable: false),
      };
      await _writeFile(temporaryFile, jsonEncode(root), flush: true);

      // Recover an interrupted prior replacement before rotating the current
      // last-good target into its backup.
      if (!await _existsFile(file) && await _existsFile(backupFile)) {
        await _renameFile(backupFile, file.path);
      }
      await _deleteFileIfExists(backupFile);
      if (await _existsFile(file)) {
        await _renameFile(file, backupFile.path);
        backupCreated = true;
      }
      await _renameFile(temporaryFile, file.path);
      await _deleteFileIfExists(backupFile);
      backupCreated = false;
    } on Object {
      if (backupCreated && backupFile != null && temporaryFile != null) {
        try {
          final file = await _resolveFile();
          if (await _existsFile(file)) {
            await _deleteFileIfExists(file);
          }
          await _renameFile(backupFile, file.path);
          backupCreated = false;
        } on Object {
          // Preserve backup for a later recovery attempt if restore is blocked.
        }
      }
      if (temporaryFile != null) {
        try {
          await _deleteFileIfExists(temporaryFile);
        } on Object {
          // Preserve the primary storage error surface.
        }
      }
      throw const PresetSceneCatalogStoreException();
    } finally {
      if (temporaryFile != null) {
        try {
          await _deleteFileIfExists(temporaryFile);
        } on Object {
          // Temporary cleanup is best effort after the primary operation.
        }
      }
    }
  }

  Future<PresetSceneCatalogStoreReadResult> _malformedResult(File file) async {
    try {
      await _quarantine(file);
    } on Object {
      // The malformed cache remains fail-closed when quarantine itself fails.
    }
    return const PresetSceneCatalogStoreReadResult(
      status: PresetSceneCatalogStoreReadStatus.malformed,
    );
  }

  Future<void> _restoreBackupIfNeeded(File file) async {
    final backup = File('${file.path}.bak');
    if (await _existsFile(file) || !await _existsFile(backup)) {
      return;
    }
    try {
      await _renameFile(backup, file.path);
    } on Object {
      // Read remains a safe miss; leave backup in place for a future retry.
    }
  }

  Future<void> _quarantine(File file) async {
    await _deleteOutOfRangeQuarantineFiles(file);
    final oldest = File('${file.path}.quarantine.$maxQuarantineFiles');
    await _deleteFileIfExists(oldest);

    for (var index = maxQuarantineFiles - 1; index >= 1; index--) {
      final current = File('${file.path}.quarantine.$index');
      if (!await current.exists()) {
        continue;
      }
      final next = File('${file.path}.quarantine.${index + 1}');
      await _deleteFileIfExists(next);
      await current.rename(next.path);
    }

    final first = File('${file.path}.quarantine.1');
    await _deleteFileIfExists(first);
    await file.rename(first.path);
  }

  Future<void> _deleteOutOfRangeQuarantineFiles(File file) async {
    final directory = file.parent;
    if (!await directory.exists()) {
      return;
    }
    final prefix = '${file.path}.quarantine.';
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.startsWith(prefix)) {
        continue;
      }
      final suffix = entity.path.substring(prefix.length);
      final index = int.tryParse(suffix);
      if (index != null && index > maxQuarantineFiles) {
        await _deleteFileIfExists(entity);
      }
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<void> _deleteFileIfExists(File file) async {
    if (await _existsFile(file)) {
      await _deleteFile(file);
    }
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
  }
}

Future<bool> _defaultExists(File file) => file.exists();

Future<void> _defaultDelete(File file) => file.delete();

Future<File> _defaultRename(File source, String targetPath) {
  return source.rename(targetPath);
}

Future<void> _defaultWrite(File file, String contents, {required bool flush}) {
  return file.writeAsString(contents, flush: flush);
}

class PresetSceneCatalogStoreException implements Exception {
  const PresetSceneCatalogStoreException();

  @override
  String toString() => 'Preset scene catalog storage unavailable.';
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const FormatException('preset catalog fields are invalid');
  }
}
