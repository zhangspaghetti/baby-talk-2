import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:path_provider/path_provider.dart';

typedef GeneratedCareMomentDirectoryResolver = Future<Directory> Function();

class StoredGeneratedCareMoment {
  StoredGeneratedCareMoment({
    required String accountContext,
    required this.moment,
  }) : accountContext = _requiredString(accountContext, 'accountContext');

  final String accountContext;
  final GeneratedCareMoment moment;
}

/// Public diagnostics deliberately omit account context and generated text.
class GeneratedCareMomentQuarantineDiagnostic {
  const GeneratedCareMomentQuarantineDiagnostic({
    required this.reasonCode,
    required this.schemaVersion,
    required this.quarantinedAt,
    required this.recordCount,
    required this.irreversibleFingerprint,
  });

  final String reasonCode;
  final String schemaVersion;
  final DateTime quarantinedAt;
  final int recordCount;
  final String irreversibleFingerprint;
}

/// Stores approved display content only. Invalid/legacy payloads are atomically
/// replaced by metadata-only quarantine before callers can receive them.
class GeneratedCareMomentLocalStore {
  GeneratedCareMomentLocalStore({
    GeneratedCareMomentDirectoryResolver? directoryResolver,
    this.fileName = 'generated_care_moments.json',
    DateTime Function()? clock,
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;

  static const _storeSchemaVersion = 2;

  final GeneratedCareMomentDirectoryResolver _directoryResolver;
  final DateTime Function() _clock;
  final String fileName;
  Future<void> _mutationTail = Future<void>.value();

  Future<List<StoredGeneratedCareMoment>> readAll() {
    return _enqueueMutation(() async => (await _readState()).records);
  }

  Future<List<GeneratedCareMomentQuarantineDiagnostic>>
  readQuarantineDiagnostics() {
    return _enqueueMutation(() async {
      final diagnostics = (await _readState()).diagnostics;
      return List<GeneratedCareMomentQuarantineDiagnostic>.unmodifiable(
        diagnostics.map((entry) => entry.toPublic()),
      );
    });
  }

  Future<void> upsert(StoredGeneratedCareMoment record) {
    return _enqueueMutation(() async {
      final state = await _readState();
      final next = <StoredGeneratedCareMoment>[
        for (final candidate in state.records)
          if (candidate.accountContext != record.accountContext ||
              candidate.moment.generatedContentId !=
                  record.moment.generatedContentId)
            candidate,
        record,
      ];
      await _writeState(next, state.diagnostics);
    });
  }

  /// Low-priority, account-scoped and idempotent. Quarantined text was removed
  /// during the atomic transition; this only drops metadata for this scope.
  Future<void> purgeQuarantinedForAccount(String accountContext) {
    final normalized = _requiredString(accountContext, 'accountContext');
    final scopeFingerprint = _fingerprint(normalized);
    return _enqueueMutation(() async {
      final state = await _readState();
      final retainedDiagnostics = state.diagnostics
          .where((entry) => entry.scopeFingerprint != scopeFingerprint)
          .toList(growable: false);
      if (retainedDiagnostics.length != state.diagnostics.length) {
        await _writeState(state.records, retainedDiagnostics);
      }
    });
  }

  Future<void> clearForAccount(String accountContext) {
    final normalized = _requiredString(accountContext, 'accountContext');
    final scopeFingerprint = _fingerprint(normalized);
    return _enqueueMutation(() async {
      final state = await _readState();
      // Remove accepted textual/derived content before its quarantine metadata.
      final retainedRecords = state.records
          .where((record) => record.accountContext != normalized)
          .toList(growable: false);
      final retainedDiagnostics = state.diagnostics
          .where((entry) => entry.scopeFingerprint != scopeFingerprint)
          .toList(growable: false);
      if (retainedRecords.isEmpty && retainedDiagnostics.isEmpty) {
        await _deleteIfExists();
        return;
      }
      await _writeState(retainedRecords, retainedDiagnostics);
    });
  }

  Future<void> clearForLifecycle() {
    return _enqueueMutation(_deleteIfExists);
  }

  Future<_StoreState> _readState() async {
    final File file;
    try {
      file = await _resolveFile();
      if (!await file.exists()) {
        return const _StoreState.empty();
      }
      final raw = await file.readAsString();
      final Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on Object {
        return _quarantineWholeFile(raw, 'invalid_store_json', 'unknown', 0);
      }
      if (decoded is! Map) {
        return _quarantineWholeFile(raw, 'invalid_store_root', 'unknown', 0);
      }
      final root = _stringKeyedMap(decoded, 'generated care moment root');
      final schemaVersion = root['schemaVersion'];
      if (schemaVersion != _storeSchemaVersion) {
        return _quarantineWholeFile(
          raw,
          'unsupported_store_schema',
          schemaVersion?.toString() ?? 'unknown',
          _recordCount(root),
          accountContexts: _accountContextsFromRoot(root),
        );
      }
      _requireExactKeys(root, const <String>{
        'schemaVersion',
        'records',
        'quarantineDiagnostics',
      });
      final encodedDiagnostics = root['quarantineDiagnostics'];
      if (encodedDiagnostics is! List) {
        return _quarantineWholeFile(raw, 'invalid_quarantine_metadata', '2', 0);
      }
      final diagnostics = <_QuarantineEntry>[
        for (final entry in encodedDiagnostics)
          _QuarantineEntry.fromJson(_stringKeyedMap(entry, 'quarantine entry')),
      ];
      final encodedRecords = root['records'];
      if (encodedRecords is! List) {
        return _quarantineWholeFile(raw, 'invalid_store_records', '2', 0);
      }
      final parsed = <StoredGeneratedCareMoment>[];
      final quarantined = <_QuarantineEntry>[...diagnostics];
      for (final entry in encodedRecords) {
        try {
          parsed.add(
            _decodeRecord(_stringKeyedMap(entry, 'generated care moment')),
          );
        } on Object {
          quarantined.add(
            _quarantineEntry(
              reasonCode: 'invalid_generated_bundle',
              schemaVersion: generatedCareMomentSchemaVersion,
              recordCount: 1,
              source: entry,
              accountContext: _optionalAccountContext(entry),
            ),
          );
        }
      }
      final keys = parsed
          .map(
            (record) =>
                '${record.accountContext}/${record.moment.generatedContentId}',
          )
          .toSet();
      if (keys.length != parsed.length) {
        return _quarantineWholeFile(
          raw,
          'duplicate_generated_bundle',
          generatedCareMomentSchemaVersion,
          parsed.length,
          accountContexts: parsed.map((record) => record.accountContext),
        );
      }
      if (quarantined.length != diagnostics.length) {
        final state = _StoreState(parsed, quarantined);
        await _writeState(state.records, state.diagnostics);
        return state;
      }
      return _StoreState(parsed, diagnostics);
    } on GeneratedCareMomentLocalStoreException {
      rethrow;
    } on Object {
      throw const GeneratedCareMomentLocalStoreException();
    }
  }

  Future<_StoreState> _quarantineWholeFile(
    String raw,
    String reasonCode,
    String schemaVersion,
    int recordCount, {
    Iterable<String>? accountContexts,
  }) async {
    final scopes = (accountContexts ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final entries = scopes.isEmpty
        ? <_QuarantineEntry>[
            _quarantineEntry(
              reasonCode: reasonCode,
              schemaVersion: schemaVersion,
              recordCount: recordCount,
              source: raw,
              accountContext: null,
            ),
          ]
        : <_QuarantineEntry>[
            for (final accountContext in scopes)
              _quarantineEntry(
                reasonCode: reasonCode,
                schemaVersion: schemaVersion,
                recordCount: recordCount,
                source: raw,
                accountContext: accountContext,
              ),
          ];
    const records = <StoredGeneratedCareMoment>[];
    final diagnostics = entries;
    await _writeState(records, diagnostics);
    return _StoreState(records, diagnostics);
  }

  _QuarantineEntry _quarantineEntry({
    required String reasonCode,
    required String schemaVersion,
    required int recordCount,
    required Object? source,
    required String? accountContext,
  }) {
    return _QuarantineEntry(
      reasonCode: reasonCode,
      schemaVersion: schemaVersion,
      quarantinedAt: _clock().toUtc(),
      recordCount: recordCount,
      irreversibleFingerprint: _fingerprint(_canonicalFingerprintInput(source)),
      scopeFingerprint: accountContext == null
          ? null
          : _fingerprint(accountContext),
    );
  }

  Future<void> _writeState(
    List<StoredGeneratedCareMoment> records,
    List<_QuarantineEntry> diagnostics,
  ) async {
    File? temporaryFile;
    try {
      final file = await _resolveFile();
      temporaryFile = File('${file.path}.tmp');
      await file.parent.create(recursive: true);
      await _deleteFileIfExists(temporaryFile);
      await temporaryFile.writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': _storeSchemaVersion,
          'records': records.map(_encodeRecord).toList(growable: false),
          'quarantineDiagnostics': diagnostics
              .map((entry) => entry.toJson())
              .toList(growable: false),
        }),
        flush: true,
      );
      if (Platform.isWindows && await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } on Object {
      if (temporaryFile != null) {
        try {
          await _deleteFileIfExists(temporaryFile);
        } on Object {
          // Primary persistence failure remains the caller surface.
        }
      }
      throw const GeneratedCareMomentLocalStoreException();
    }
  }

  Future<void> _deleteIfExists() async {
    try {
      final file = await _resolveFile();
      await _deleteFileIfExists(file);
      await _deleteFileIfExists(File('${file.path}.tmp'));
    } on Object {
      throw const GeneratedCareMomentLocalStoreException();
    }
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
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
}

class GeneratedCareMomentLocalStoreException implements Exception {
  const GeneratedCareMomentLocalStoreException();

  @override
  String toString() => 'Generated care moment storage unavailable.';
}

class _StoreState {
  const _StoreState(this.records, this.diagnostics);

  const _StoreState.empty()
    : records = const <StoredGeneratedCareMoment>[],
      diagnostics = const <_QuarantineEntry>[];

  final List<StoredGeneratedCareMoment> records;
  final List<_QuarantineEntry> diagnostics;
}

class _QuarantineEntry {
  const _QuarantineEntry({
    required this.reasonCode,
    required this.schemaVersion,
    required this.quarantinedAt,
    required this.recordCount,
    required this.irreversibleFingerprint,
    required this.scopeFingerprint,
  });

  factory _QuarantineEntry.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'reasonCode',
      'schemaVersion',
      'quarantinedAt',
      'recordCount',
      'irreversibleFingerprint',
      'scopeFingerprint',
    });
    final parsedAt = DateTime.tryParse(
      _requiredString(json['quarantinedAt'], 'quarantinedAt'),
    );
    if (parsedAt == null) {
      throw const FormatException(
        'invalid generated care moment quarantine time',
      );
    }
    final scopeFingerprint = json['scopeFingerprint'];
    if (scopeFingerprint != null && scopeFingerprint is! String) {
      throw const FormatException(
        'invalid generated care moment quarantine scope',
      );
    }
    return _QuarantineEntry(
      reasonCode: _requiredString(json['reasonCode'], 'reasonCode'),
      schemaVersion: _requiredString(json['schemaVersion'], 'schemaVersion'),
      quarantinedAt: parsedAt.toUtc(),
      recordCount: _requiredNonNegativeInt(json['recordCount'], 'recordCount'),
      irreversibleFingerprint: _requiredString(
        json['irreversibleFingerprint'],
        'irreversibleFingerprint',
      ),
      scopeFingerprint: scopeFingerprint,
    );
  }

  final String reasonCode;
  final String schemaVersion;
  final DateTime quarantinedAt;
  final int recordCount;
  final String irreversibleFingerprint;
  final String? scopeFingerprint;

  GeneratedCareMomentQuarantineDiagnostic toPublic() {
    return GeneratedCareMomentQuarantineDiagnostic(
      reasonCode: reasonCode,
      schemaVersion: schemaVersion,
      quarantinedAt: quarantinedAt,
      recordCount: recordCount,
      irreversibleFingerprint: irreversibleFingerprint,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'reasonCode': reasonCode,
    'schemaVersion': schemaVersion,
    'quarantinedAt': quarantinedAt.toIso8601String(),
    'recordCount': recordCount,
    'irreversibleFingerprint': irreversibleFingerprint,
    'scopeFingerprint': scopeFingerprint,
  };
}

Map<String, Object?> _encodeRecord(StoredGeneratedCareMoment record) {
  final moment = record.moment;
  return <String, Object?>{
    'accountContext': record.accountContext,
    'schemaVersion': moment.schemaVersion,
    'generatedContentId': moment.generatedContentId,
    'sceneId': moment.sceneId,
    'spaceId': moment.spaceId,
    'momentId': moment.momentId,
    'activityId': moment.activityId,
    'title': moment.title,
    'sceneTag': moment.sceneTag,
    'coachTip': moment.coachTip,
    'source': moment.source,
    'starter': _encodeUtterance(moment.starter),
    'reactionSupports': <String, Object?>{
      for (final reaction in BabyReactionType.values)
        reaction.wireValue: _encodeUtterance(moment.reactionSupports[reaction]),
    },
  };
}

StoredGeneratedCareMoment _decodeRecord(Map<String, dynamic> json) {
  _requireExactKeys(json, const <String>{
    'accountContext',
    'schemaVersion',
    'generatedContentId',
    'sceneId',
    'spaceId',
    'momentId',
    'activityId',
    'title',
    'sceneTag',
    'coachTip',
    'source',
    'starter',
    'reactionSupports',
  });
  final supports = _stringKeyedMap(
    json['reactionSupports'],
    'reactionSupports',
  );
  _requireExactKeys(
    supports,
    BabyReactionType.values.map((reaction) => reaction.wireValue).toSet(),
  );
  final source = _requiredString(json['source'], 'source');
  if (source != 'generated') {
    throw const FormatException('invalid generated care moment source');
  }
  return StoredGeneratedCareMoment(
    accountContext: _requiredString(json['accountContext'], 'accountContext'),
    moment: GeneratedCareMoment(
      schemaVersion: _requiredString(json['schemaVersion'], 'schemaVersion'),
      generatedContentId: _requiredString(
        json['generatedContentId'],
        'generatedContentId',
      ),
      sceneId: _requiredString(json['sceneId'], 'sceneId'),
      spaceId: _requiredString(json['spaceId'], 'spaceId'),
      momentId: _requiredString(json['momentId'], 'momentId'),
      activityId: _requiredString(json['activityId'], 'activityId'),
      title: _requiredString(json['title'], 'title'),
      sceneTag: _requiredString(json['sceneTag'], 'sceneTag'),
      coachTip: _requiredString(json['coachTip'], 'coachTip'),
      source: source,
      inputSource: SceneGenerationSourceType.custom,
      starter: _decodeUtterance(_stringKeyedMap(json['starter'], 'starter')),
      reactionSupports: GeneratedReactionSupportMap(
        <BabyReactionType, GeneratedCareUtterance>{
          for (final reaction in BabyReactionType.values)
            reaction: _decodeUtterance(
              _stringKeyedMap(supports[reaction.wireValue], reaction.wireValue),
            ),
        },
      ),
    ),
  );
}

Map<String, Object?> _encodeUtterance(GeneratedCareUtterance utterance) {
  return <String, Object?>{
    'utteranceId': utterance.utteranceId,
    'phraseId': utterance.phraseId,
    'english': utterance.english,
    'chinese': utterance.chinese,
    'pronunciation': utterance.pronunciation,
    'tprActionZh': utterance.tprActionZh,
    'deliveryGuidanceZh': utterance.deliveryGuidanceZh,
    'difficulty': utterance.difficulty,
    'source': utterance.source,
    'role': utterance.role.wireValue,
    'reaction': utterance.reaction?.wireValue,
    'displayOrder': utterance.displayOrder,
    'providerProvenance': <String, Object?>{
      'origin': utterance.providerProvenance.origin.wireValue,
      'providerName': utterance.providerProvenance.providerName,
      'modelName': utterance.providerProvenance.modelName,
      'attemptNumber': utterance.providerProvenance.attemptNumber,
    },
  };
}

GeneratedCareUtterance _decodeUtterance(Map<String, dynamic> json) {
  _requireExactKeys(json, const <String>{
    'utteranceId',
    'phraseId',
    'english',
    'chinese',
    'pronunciation',
    'tprActionZh',
    'deliveryGuidanceZh',
    'difficulty',
    'source',
    'role',
    'reaction',
    'displayOrder',
    'providerProvenance',
  });
  final reaction = json['reaction'];
  if (reaction != null && reaction is! String) {
    throw const FormatException('invalid generated care moment reaction');
  }
  final provenance = _stringKeyedMap(
    json['providerProvenance'],
    'providerProvenance',
  );
  _requireExactKeys(provenance, const <String>{
    'origin',
    'providerName',
    'modelName',
    'attemptNumber',
  });
  final source = _requiredString(json['source'], 'source');
  if (source != 'generated') {
    throw const FormatException('unsupported generated care moment source');
  }
  return GeneratedCareUtterance(
    utteranceId: _requiredString(json['utteranceId'], 'utteranceId'),
    phraseId: _requiredString(json['phraseId'], 'phraseId'),
    english: _requiredString(json['english'], 'english'),
    chinese: _requiredString(json['chinese'], 'chinese'),
    pronunciation: _requiredString(json['pronunciation'], 'pronunciation'),
    tprActionZh: _requiredString(json['tprActionZh'], 'tprActionZh'),
    deliveryGuidanceZh: _requiredString(
      json['deliveryGuidanceZh'],
      'deliveryGuidanceZh',
    ),
    difficulty: _requiredString(json['difficulty'], 'difficulty'),
    source: source,
    role: GeneratedCareUtteranceRole.parse(
      _requiredString(json['role'], 'role'),
    ),
    reaction: reaction == null ? null : parseBabyReactionType(reaction),
    displayOrder: _requiredNonNegativeInt(json['displayOrder'], 'displayOrder'),
    providerProvenance: GeneratedCareProviderProvenance(
      origin: GeneratedCareProviderOrigin.parse(
        _requiredString(provenance['origin'], 'origin'),
      ),
      providerName: _requiredString(provenance['providerName'], 'providerName'),
      modelName: _requiredString(provenance['modelName'], 'modelName'),
      attemptNumber: _requiredNonNegativeInt(
        provenance['attemptNumber'],
        'attemptNumber',
      ),
    ),
  );
}

Map<String, dynamic> _stringKeyedMap(Object? value, String name) {
  if (value is! Map) {
    throw FormatException('invalid generated care moment $name');
  }
  final mapped = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('invalid generated care moment $name');
    }
    mapped[entry.key as String] = entry.value;
  }
  return mapped;
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const FormatException('invalid generated care moment fields');
  }
}

String _requiredString(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('invalid generated care moment $name');
  }
  return value.trim();
}

int _requiredNonNegativeInt(Object? value, String name) {
  if (value is! int || value < 0) {
    throw FormatException('invalid generated care moment $name');
  }
  return value;
}

int _recordCount(Map<String, dynamic> root) {
  final records = root['records'];
  return records is List ? records.length : 0;
}

String? _optionalAccountContext(Object? value) {
  if (value is! Map) {
    return null;
  }
  final accountContext = value['accountContext'];
  if (accountContext is! String || accountContext.trim().isEmpty) {
    return null;
  }
  return accountContext.trim();
}

Iterable<String> _accountContextsFromRoot(Map<String, dynamic> root) sync* {
  final records = root['records'];
  if (records is! List) {
    return;
  }
  for (final record in records) {
    final accountContext = _optionalAccountContext(record);
    if (accountContext != null) {
      yield accountContext;
    }
  }
}

String _canonicalFingerprintInput(Object? value) {
  if (value is String) {
    return value;
  }
  try {
    return jsonEncode(value);
  } on Object {
    return value.runtimeType.toString();
  }
}

String _fingerprint(String value) {
  var hash = 1469598103934665603;
  for (final codeUnit in value.codeUnits) {
    hash = (hash ^ codeUnit) * 1099511628211;
    hash &= 0xffffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0').substring(0, 16);
}
