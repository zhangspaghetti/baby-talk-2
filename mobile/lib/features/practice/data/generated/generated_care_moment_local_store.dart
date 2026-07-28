import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
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

/// Stores approved display content only. Raw scene input and audio bytes never
/// enter this file.
class GeneratedCareMomentLocalStore {
  GeneratedCareMomentLocalStore({
    GeneratedCareMomentDirectoryResolver? directoryResolver,
    this.fileName = 'generated_care_moments.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  final GeneratedCareMomentDirectoryResolver _directoryResolver;
  final String fileName;
  Future<void> _mutationTail = Future<void>.value();

  Future<List<StoredGeneratedCareMoment>> readAll() {
    return _enqueueMutation(_readAll);
  }

  Future<void> upsert(StoredGeneratedCareMoment record) {
    return _enqueueMutation(() async {
      final existing = await _readAll();
      final next = <StoredGeneratedCareMoment>[
        for (final candidate in existing)
          if (candidate.accountContext != record.accountContext ||
              candidate.moment.generatedContentId !=
                  record.moment.generatedContentId)
            candidate,
        record,
      ];
      await _writeAll(next);
    });
  }

  Future<void> clearForAccount(String accountContext) {
    final normalized = _requiredString(accountContext, 'accountContext');
    return _enqueueMutation(() async {
      final existing = await _readAll();
      final retained = existing
          .where((record) => record.accountContext != normalized)
          .toList(growable: false);
      if (retained.isEmpty) {
        await _deleteIfExists();
        return;
      }
      await _writeAll(retained);
    });
  }

  Future<void> clearForLifecycle() {
    return _enqueueMutation(_deleteIfExists);
  }

  Future<List<StoredGeneratedCareMoment>> _readAll() async {
    final File file;
    try {
      file = await _resolveFile();
      if (!await file.exists()) {
        return const <StoredGeneratedCareMoment>[];
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        throw const FormatException('empty generated care moment store');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('generated care moment root is not object');
      }
      _requireExactKeys(decoded, const <String>{'schemaVersion', 'records'});
      if (_requiredInt(decoded, 'schemaVersion') != 1) {
        throw const FormatException('unsupported generated care moment schema');
      }
      final records = decoded['records'];
      if (records is! List) {
        throw const FormatException(
          'generated care moment records are invalid',
        );
      }
      final parsed = <StoredGeneratedCareMoment>[
        for (final record in records)
          _decodeRecord(_requiredMap(record, 'generated care moment record')),
      ];
      final keys = parsed
          .map(
            (record) =>
                '${record.accountContext}/${record.moment.generatedContentId}',
          )
          .toSet();
      if (keys.length != parsed.length) {
        throw const FormatException('duplicate generated care moment record');
      }
      return List<StoredGeneratedCareMoment>.unmodifiable(parsed);
    } on GeneratedCareMomentLocalStoreException {
      rethrow;
    } on Object {
      throw const GeneratedCareMomentLocalStoreException();
    }
  }

  Future<void> _writeAll(List<StoredGeneratedCareMoment> records) async {
    File? temporaryFile;
    try {
      final file = await _resolveFile();
      temporaryFile = File('${file.path}.tmp');
      await file.parent.create(recursive: true);
      await _deleteFileIfExists(temporaryFile);
      await temporaryFile.writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'records': records.map(_encodeRecord).toList(growable: false),
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
          // Primary persistence failure remains the only caller surface.
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

Map<String, Object?> _encodeRecord(StoredGeneratedCareMoment record) {
  final moment = record.moment;
  return <String, Object?>{
    'accountContext': record.accountContext,
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
  final supports = _requiredMap(json['reactionSupports'], 'reactionSupports');
  _requireExactKeys(
    supports,
    BabyReactionType.values.map((reaction) => reaction.wireValue).toSet(),
  );
  return StoredGeneratedCareMoment(
    accountContext: _requiredString(json['accountContext'], 'accountContext'),
    moment: GeneratedCareMoment(
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
      source: _requiredString(json['source'], 'source'),
      starter: _decodeUtterance(_requiredMap(json['starter'], 'starter')),
      reactionSupports: GeneratedReactionSupportMap(
        <BabyReactionType, GeneratedCareUtterance>{
          for (final reaction in BabyReactionType.values)
            reaction: _decodeUtterance(
              _requiredMap(supports[reaction.wireValue], reaction.wireValue),
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
    'difficulty': utterance.difficulty,
    'source': utterance.source,
    'tprActionZh': utterance.tprActionZh,
    'deliveryGuidanceZh': utterance.deliveryGuidanceZh,
  };
}

GeneratedCareUtterance _decodeUtterance(Map<String, dynamic> json) {
  _requireExactKeys(json, const <String>{
    'utteranceId',
    'phraseId',
    'english',
    'chinese',
    'pronunciation',
    'difficulty',
    'source',
    'tprActionZh',
    'deliveryGuidanceZh',
  });
  return GeneratedCareUtterance(
    utteranceId: _requiredString(json['utteranceId'], 'utteranceId'),
    phraseId: _requiredString(json['phraseId'], 'phraseId'),
    english: _requiredString(json['english'], 'english'),
    chinese: _requiredString(json['chinese'], 'chinese'),
    pronunciation: _requiredString(json['pronunciation'], 'pronunciation'),
    difficulty: _requiredString(json['difficulty'], 'difficulty'),
    source: _requiredString(json['source'], 'source'),
    tprActionZh: _optionalString(json['tprActionZh'], 'tprActionZh'),
    deliveryGuidanceZh: _optionalString(
      json['deliveryGuidanceZh'],
      'deliveryGuidanceZh',
    ),
  );
}

Map<String, dynamic> _requiredMap(Object? value, String name) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('invalid generated care moment $name');
  }
  return value;
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

String? _optionalString(Object? value, String name) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('invalid generated care moment $name');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw const FormatException('invalid generated care moment integer');
  }
  return value;
}
