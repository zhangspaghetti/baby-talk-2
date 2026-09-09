import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/domain/generated_care_turn_resume.dart';
import 'package:path_provider/path_provider.dart';

typedef GeneratedCareTurnResumeDirectoryResolver = Future<Directory> Function();
typedef GeneratedCareTurnResumeFileReader = Future<String> Function(File file);
typedef GeneratedCareTurnResumeHouseholdScopeLoader =
    Future<String?> Function();

/// Stores only opaque generated-content identity and ordering metadata.
/// Account identity is persisted as a one-way scope fingerprint.
class GeneratedCareTurnResumeMarkerStore
    implements GeneratedCareTurnResumeStore {
  GeneratedCareTurnResumeMarkerStore({
    GeneratedCareTurnResumeDirectoryResolver? directoryResolver,
    GeneratedCareTurnResumeFileReader? fileReader,
    GeneratedCareTurnResumeHouseholdScopeLoader? householdScopeLoader,
    this.fileName = 'generated_care_turn_resume.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory,
       _fileReader = fileReader ?? ((file) => file.readAsString()),
       _householdScopeLoader = householdScopeLoader ?? (() async => null);

  static const _schemaVersion = 2;
  static const _legacySchemaVersion = 1;
  static final Map<String, Future<void>> _sharedMutationTails =
      <String, Future<void>>{};

  final GeneratedCareTurnResumeDirectoryResolver _directoryResolver;
  final GeneratedCareTurnResumeFileReader _fileReader;
  final GeneratedCareTurnResumeHouseholdScopeLoader _householdScopeLoader;
  final String fileName;
  Future<void> _mutationTail = Future<void>.value();

  @override
  Future<void> write({
    required String accountContext,
    required String generatedContentId,
    required DateTime confirmedAt,
  }) {
    final scopeFingerprint = _scopeFingerprint(accountContext);
    return _enqueueMutation(() async {
      final householdScope = await _householdScopeLoader();
      final marker = GeneratedCareTurnResumeMarker(
        generatedContentId: generatedContentId,
        confirmedAt: confirmedAt,
      );
      final records = await _readRecords();
      final retained = records
          .where((record) => record.scopeFingerprint != scopeFingerprint)
          .toList(growable: true);
      retained.add(
        _StoredResumeMarker(
          scopeFingerprint: scopeFingerprint,
          householdScopeFingerprint: householdScope == null
              ? null
              : householdScopeFingerprint(householdScope),
          marker: marker,
        ),
      );
      await _writeRecords(retained);
    });
  }

  @override
  Future<GeneratedCareTurnResumeMarker?> readForAccount(String accountContext) {
    final scopeFingerprint = _scopeFingerprint(accountContext);
    return _enqueueMutation(() async {
      final matches = (await _readRecords())
          .where((record) => record.scopeFingerprint == scopeFingerprint)
          .toList(growable: false);
      if (matches.length != 1) {
        return null;
      }
      return matches.single.marker;
    });
  }

  @override
  Future<void> clearMatching({
    required String accountContext,
    required String generatedContentId,
  }) {
    final scopeFingerprint = _scopeFingerprint(accountContext);
    final normalizedContentId = _required(
      generatedContentId,
      'generatedContentId',
    );
    return _enqueueMutation(() async {
      final records = await _readRecords();
      final retained = records
          .where(
            (record) =>
                record.scopeFingerprint != scopeFingerprint ||
                record.marker.generatedContentId != normalizedContentId,
          )
          .toList(growable: false);
      await _persistOrDelete(retained);
    });
  }

  @override
  Future<void> clearForAccount(String accountContext) {
    final scopeFingerprint = _scopeFingerprint(accountContext);
    return _enqueueMutation(() async {
      final retained = (await _readRecords())
          .where((record) => record.scopeFingerprint != scopeFingerprint)
          .toList(growable: false);
      await _persistOrDelete(
        retained,
        clearIntent: _ClearIntent.account(scopeFingerprint),
      );
    });
  }

  @override
  Future<void> clearForHouseholdScope(String householdScope) {
    return clearForHouseholdScopeFingerprint(
      householdScopeFingerprint(householdScope),
    );
  }

  @override
  Future<void> clearForHouseholdScopeFingerprint(String scopeFingerprint) {
    _requireHouseholdScopeFingerprint(scopeFingerprint);
    return _enqueueMutation(() async {
      final file = await _resolveFile();
      if (!await file.parent.exists()) {
        return;
      }
      await File('${file.path}.clear').writeAsString(
        _ClearIntent.household(scopeFingerprint).markerValue,
        flush: true,
      );
      // _readRecords consumes marker and only removes it after replacement.
      await _readRecords();
    });
  }

  @override
  Future<void> clearForLifecycle() => _enqueueMutation(
    () => _deleteFiles(clearIntent: const _ClearIntent.lifecycle()),
  );

  Future<List<_StoredResumeMarker>> _readRecords() async {
    final file = await _resolveFile();
    final clearMarker = File('${file.path}.clear');
    final pendingClearIntent = await _readClearIntent(clearMarker);
    final clearIntent =
        pendingClearIntent?.kind == _ClearScopeKind.lifecycle &&
            await file.exists()
        ? null
        : pendingClearIntent;
    if (pendingClearIntent?.kind == _ClearScopeKind.lifecycle &&
        clearIntent != null) {
      await _deleteFiles(clearIntent: clearIntent);
      return const <_StoredResumeMarker>[];
    }
    if (!await file.exists()) {
      final restored = await _restoreBackupIfNeeded(file);
      if (!restored && clearIntent != null) {
        throw const FileSystemException('resume marker backup restore failed');
      }
    }
    if (!await file.exists()) {
      if (clearIntent != null) {
        await _deleteFileIfExists(clearMarker);
      }
      return const <_StoredResumeMarker>[];
    }

    final raw = await _fileReader(file);
    final List<_StoredResumeMarker> records;
    final bool isLegacy;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('invalid resume marker root');
      }
      final root = Map<String, dynamic>.from(decoded);
      _requireExactKeys(root, const <String>{'schemaVersion', 'records'});
      final schemaVersion = root['schemaVersion'];
      isLegacy = schemaVersion == _legacySchemaVersion;
      if (schemaVersion != _schemaVersion && !isLegacy ||
          root['records'] is! List) {
        throw const FormatException('unsupported resume marker schema');
      }
      records = <_StoredResumeMarker>[
        for (final value in root['records'] as List<dynamic>)
          _StoredResumeMarker.fromJson(
            value,
            allowLegacyMissingHouseholdScope: isLegacy,
          ),
      ];
      if (records.map((record) => record.scopeFingerprint).toSet().length !=
          records.length) {
        throw const FormatException('duplicate resume marker scope');
      }
    } on Object {
      await _deleteFilesBestEffort();
      return const <_StoredResumeMarker>[];
    }

    final retained = clearIntent == null
        ? records
        : records
              .where(
                (record) => clearIntent.kind == _ClearScopeKind.account
                    ? record.scopeFingerprint != clearIntent.scopeFingerprint
                    : record.householdScopeFingerprint !=
                          clearIntent.scopeFingerprint,
              )
              .toList(growable: false);
    if (clearIntent != null || isLegacy) {
      await _persistOrDelete(retained, clearIntent: clearIntent);
    }
    return retained;
  }

  Future<void> _persistOrDelete(
    List<_StoredResumeMarker> records, {
    _ClearIntent? clearIntent,
  }) {
    return records.isEmpty
        ? _deleteFiles(clearIntent: clearIntent)
        : _writeRecords(records, clearIntent: clearIntent);
  }

  Future<void> _writeRecords(
    List<_StoredResumeMarker> records, {
    _ClearIntent? clearIntent,
  }) async {
    File? temporary;
    File? backup;
    var backupCreated = false;
    try {
      final file = await _resolveFile();
      temporary = File('${file.path}.tmp');
      backup = File('${file.path}.bak');
      final clearMarker = File('${file.path}.clear');
      await file.parent.create(recursive: true);
      if (clearIntent == null) {
        await _deleteFileIfExists(clearMarker);
      } else {
        await clearMarker.writeAsString(clearIntent.markerValue, flush: true);
      }
      await _deleteFileIfExists(temporary);
      await temporary.writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': _schemaVersion,
          'records': <Object?>[for (final record in records) record.toJson()],
        }),
        flush: true,
      );
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      await _deleteFileIfExists(backup);
      if (await file.exists()) {
        await file.rename(backup.path);
        backupCreated = true;
      }
      await temporary.rename(file.path);
      await _deleteFileIfExists(backup);
      backupCreated = false;
      await _deleteFileIfExists(clearMarker);
    } on Object {
      if (temporary != null && backup != null) {
        try {
          final file = await _resolveFile();
          if (await backup.exists() &&
              (backupCreated || !await file.exists())) {
            if (await file.exists()) {
              await _deleteFileIfExists(file);
            }
            await backup.rename(file.path);
          }
        } on Object {
          // Keep backup and clear marker for a later retry.
        }
      }
      if (temporary != null) {
        try {
          await _deleteFileIfExists(temporary);
        } on Object {
          // Preserve primary failure while leaving marker durable.
        }
      }
      rethrow;
    }
  }

  Future<void> _deleteFiles({_ClearIntent? clearIntent}) async {
    final file = await _resolveFile();
    if (!await file.parent.exists()) {
      return;
    }
    final clearMarker = File('${file.path}.clear');
    if (clearIntent != null) {
      await clearMarker.writeAsString(clearIntent.markerValue, flush: true);
    }
    await _deleteFileIfExists(File('${file.path}.tmp'));
    await _deleteFileIfExists(File('${file.path}.bak'));
    await _deleteFileIfExists(file);
    await _deleteFileIfExists(clearMarker);
  }

  Future<void> _deleteFilesBestEffort() async {
    try {
      await _deleteFiles(clearIntent: const _ClearIntent.lifecycle());
    } on Object {
      // Corrupt marker cleanup is best-effort and never blocks recovery.
    }
  }

  Future<bool> _restoreBackupIfNeeded(File file) async {
    final backup = File('${file.path}.bak');
    if (await file.exists() || !await backup.exists()) {
      return true;
    }
    try {
      await backup.rename(file.path);
      return true;
    } on Object {
      return await file.exists();
    }
  }

  Future<_ClearIntent?> _readClearIntent(File marker) async {
    if (!await marker.exists()) {
      return null;
    }
    final raw = await marker.readAsString();
    if (raw == 'clear') {
      return const _ClearIntent.lifecycle();
    }
    const accountPrefix = 'account:';
    if (raw.startsWith(accountPrefix)) {
      final fingerprint = raw.substring(accountPrefix.length);
      if (RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
        return _ClearIntent.account(fingerprint);
      }
    }
    const householdPrefix = 'household:';
    if (raw.startsWith(householdPrefix)) {
      final fingerprint = raw.substring(householdPrefix.length);
      if (RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
        return _ClearIntent.household(fingerprint);
      }
    }
    throw const FormatException('invalid resume marker clear intent');
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => _enqueueSharedMutation(mutation));
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
  }

  Future<T> _enqueueSharedMutation<T>(Future<T> Function() mutation) async {
    final file = await _resolveFile();
    final key = _sharedPathKey(file);
    final previous = _sharedMutationTails[key] ?? Future<void>.value();
    final current = previous.then((_) => mutation());
    _sharedMutationTails[key] = current.then<void>((_) {}, onError: (_, _) {});
    return current;
  }

  String _sharedPathKey(File file) {
    final path = _canonicalizeLexicalPath(file.absolute.path);
    return Platform.isWindows ? path.toLowerCase() : path;
  }

  String _canonicalizeLexicalPath(String rawPath) {
    final path = Platform.isWindows ? rawPath.replaceAll('\\', '/') : rawPath;
    String prefix;
    String remainder;
    if (RegExp(r'^[A-Za-z]:/').hasMatch(path)) {
      prefix = path.substring(0, 3);
      remainder = path.substring(3);
    } else if (path.startsWith('//')) {
      if (Platform.isWindows) {
        prefix = '//';
        remainder = path.substring(2);
      } else {
        prefix = '/';
        remainder = path.replaceFirst(RegExp(r'^/+'), '');
      }
    } else if (path.startsWith('/')) {
      prefix = '/';
      remainder = path.substring(1);
    } else {
      prefix = '';
      remainder = path;
    }

    final segments = <String>[];
    for (final segment in remainder.split('/')) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..') {
        if (segments.isNotEmpty && segments.last != '..') {
          segments.removeLast();
        } else if (prefix.isEmpty) {
          segments.add(segment);
        }
        continue;
      }
      segments.add(segment);
    }
    final joined = segments.join('/');
    if (prefix == '/') {
      return joined.isEmpty ? '/' : '/$joined';
    }
    if (prefix == '//') {
      return joined.isEmpty ? '//' : '//$joined';
    }
    if (prefix.isNotEmpty) {
      return '$prefix$joined';
    }
    return joined.isEmpty ? '.' : joined;
  }
}

class _StoredResumeMarker {
  const _StoredResumeMarker({
    required this.scopeFingerprint,
    required this.householdScopeFingerprint,
    required this.marker,
  });

  final String scopeFingerprint;
  final String? householdScopeFingerprint;
  final GeneratedCareTurnResumeMarker marker;

  factory _StoredResumeMarker.fromJson(
    Object? value, {
    required bool allowLegacyMissingHouseholdScope,
  }) {
    if (value is! Map) {
      throw const FormatException('invalid resume marker record');
    }
    final json = Map<String, dynamic>.from(value);
    _requireExactKeys(json, <String>{
      'scopeFingerprint',
      'generatedContentId',
      'confirmedAt',
      if (!allowLegacyMissingHouseholdScope) 'householdScopeFingerprint',
    });
    final scopeFingerprint = _required(
      json['scopeFingerprint'],
      'scopeFingerprint',
    );
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(scopeFingerprint)) {
      throw const FormatException('invalid resume marker scope fingerprint');
    }
    final householdScopeFingerprint = allowLegacyMissingHouseholdScope
        ? null
        : _optionalHouseholdScopeFingerprint(json['householdScopeFingerprint']);
    final confirmedAtValue = _required(json['confirmedAt'], 'confirmedAt');
    final confirmedAt = DateTime.tryParse(confirmedAtValue);
    if (confirmedAt == null || !confirmedAt.isUtc) {
      throw const FormatException('invalid resume marker confirmedAt');
    }
    return _StoredResumeMarker(
      scopeFingerprint: scopeFingerprint,
      householdScopeFingerprint: householdScopeFingerprint,
      marker: GeneratedCareTurnResumeMarker(
        generatedContentId: _required(
          json['generatedContentId'],
          'generatedContentId',
        ),
        confirmedAt: confirmedAt,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'scopeFingerprint': scopeFingerprint,
    'householdScopeFingerprint': householdScopeFingerprint,
    'generatedContentId': marker.generatedContentId,
    'confirmedAt': marker.confirmedAt.toIso8601String(),
  };
}

enum _ClearScopeKind { lifecycle, account, household }

class _ClearIntent {
  const _ClearIntent.lifecycle()
    : kind = _ClearScopeKind.lifecycle,
      scopeFingerprint = null;

  const _ClearIntent.account(this.scopeFingerprint)
    : kind = _ClearScopeKind.account;

  const _ClearIntent.household(this.scopeFingerprint)
    : kind = _ClearScopeKind.household;

  final _ClearScopeKind kind;
  final String? scopeFingerprint;

  String get markerValue => switch (kind) {
    _ClearScopeKind.lifecycle => 'clear',
    _ClearScopeKind.account => 'account:$scopeFingerprint',
    _ClearScopeKind.household => 'household:$scopeFingerprint',
  };
}

String? _optionalHouseholdScopeFingerprint(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('invalid resume marker household scope');
  }
  return value;
}

String _scopeFingerprint(String accountContext) {
  final normalized = _required(accountContext, 'accountContext');
  return sha256.convert(utf8.encode(normalized)).toString();
}

void _requireHouseholdScopeFingerprint(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'scopeFingerprint',
      'household scope fingerprint is invalid.',
    );
  }
}

String _required(Object? value, String field) {
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw FormatException('$field is required');
  }
  return value;
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(json.keys.toSet()).isNotEmpty) {
    throw const FormatException('unexpected resume marker fields');
  }
}
