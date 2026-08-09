import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mobile/features/practice/domain/generated_care_turn_resume.dart';
import 'package:path_provider/path_provider.dart';

typedef GeneratedCareTurnResumeDirectoryResolver = Future<Directory> Function();
typedef GeneratedCareTurnResumeFileReader = Future<String> Function(File file);

/// Stores only opaque generated-content identity and ordering metadata.
/// Account identity is persisted as a one-way scope fingerprint.
class GeneratedCareTurnResumeMarkerStore
    implements GeneratedCareTurnResumeStore {
  GeneratedCareTurnResumeMarkerStore({
    GeneratedCareTurnResumeDirectoryResolver? directoryResolver,
    GeneratedCareTurnResumeFileReader? fileReader,
    this.fileName = 'generated_care_turn_resume.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory,
       _fileReader = fileReader ?? ((file) => file.readAsString());

  static const _schemaVersion = 1;

  final GeneratedCareTurnResumeDirectoryResolver _directoryResolver;
  final GeneratedCareTurnResumeFileReader _fileReader;
  final String fileName;
  Future<void> _mutationTail = Future<void>.value();

  @override
  Future<void> write({
    required String accountContext,
    required String generatedContentId,
    required DateTime confirmedAt,
  }) {
    final scopeFingerprint = _scopeFingerprint(accountContext);
    final marker = GeneratedCareTurnResumeMarker(
      generatedContentId: generatedContentId,
      confirmedAt: confirmedAt,
    );
    return _enqueueMutation(() async {
      final records = await _readRecords();
      final retained = records
          .where((record) => record.scopeFingerprint != scopeFingerprint)
          .toList(growable: true);
      retained.add(
        _StoredResumeMarker(scopeFingerprint: scopeFingerprint, marker: marker),
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
      await _persistOrDelete(retained);
    });
  }

  @override
  Future<void> clearForLifecycle() => _enqueueMutation(_deleteFiles);

  Future<List<_StoredResumeMarker>> _readRecords() async {
    final file = await _resolveFile();
    if (!await file.exists()) {
      return const <_StoredResumeMarker>[];
    }
    final raw = await _fileReader(file);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('invalid resume marker root');
      }
      final root = Map<String, dynamic>.from(decoded);
      _requireExactKeys(root, const <String>{'schemaVersion', 'records'});
      if (root['schemaVersion'] != _schemaVersion || root['records'] is! List) {
        throw const FormatException('unsupported resume marker schema');
      }
      final records = <_StoredResumeMarker>[
        for (final value in root['records'] as List<dynamic>)
          _StoredResumeMarker.fromJson(value),
      ];
      if (records.map((record) => record.scopeFingerprint).toSet().length !=
          records.length) {
        throw const FormatException('duplicate resume marker scope');
      }
      return records;
    } on Object {
      await _deleteFilesBestEffort();
      return const <_StoredResumeMarker>[];
    }
  }

  Future<void> _persistOrDelete(List<_StoredResumeMarker> records) {
    return records.isEmpty ? _deleteFiles() : _writeRecords(records);
  }

  Future<void> _writeRecords(List<_StoredResumeMarker> records) async {
    final file = await _resolveFile();
    final temporary = File('${file.path}.tmp');
    await file.parent.create(recursive: true);
    await _deleteFileIfExists(temporary);
    try {
      await temporary.writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': _schemaVersion,
          'records': <Object?>[for (final record in records) record.toJson()],
        }),
        flush: true,
      );
      if (Platform.isWindows) {
        await _deleteFileIfExists(file);
      }
      await temporary.rename(file.path);
    } on Object {
      await _deleteFileIfExists(temporary);
      rethrow;
    }
  }

  Future<void> _deleteFiles() async {
    final file = await _resolveFile();
    await _deleteFileIfExists(file);
    await _deleteFileIfExists(File('${file.path}.tmp'));
  }

  Future<void> _deleteFilesBestEffort() async {
    try {
      await _deleteFiles();
    } on Object {
      // Corrupt marker cleanup is best-effort and never blocks recovery.
    }
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
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
  }
}

class _StoredResumeMarker {
  const _StoredResumeMarker({
    required this.scopeFingerprint,
    required this.marker,
  });

  final String scopeFingerprint;
  final GeneratedCareTurnResumeMarker marker;

  factory _StoredResumeMarker.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('invalid resume marker record');
    }
    final json = Map<String, dynamic>.from(value);
    _requireExactKeys(json, const <String>{
      'scopeFingerprint',
      'generatedContentId',
      'confirmedAt',
    });
    final scopeFingerprint = _required(
      json['scopeFingerprint'],
      'scopeFingerprint',
    );
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(scopeFingerprint)) {
      throw const FormatException('invalid resume marker scope fingerprint');
    }
    final confirmedAtValue = _required(json['confirmedAt'], 'confirmedAt');
    final confirmedAt = DateTime.tryParse(confirmedAtValue);
    if (confirmedAt == null || !confirmedAt.isUtc) {
      throw const FormatException('invalid resume marker confirmedAt');
    }
    return _StoredResumeMarker(
      scopeFingerprint: scopeFingerprint,
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
    'generatedContentId': marker.generatedContentId,
    'confirmedAt': marker.confirmedAt.toIso8601String(),
  };
}

String _scopeFingerprint(String accountContext) {
  final normalized = _required(accountContext, 'accountContext');
  return sha256.convert(utf8.encode(normalized)).toString();
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
