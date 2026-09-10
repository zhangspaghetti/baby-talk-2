import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:path_provider/path_provider.dart';

typedef OnboardingConversationDirectoryResolver = Future<Directory> Function();

final class OnboardingConversationPersistenceException implements Exception {
  const OnboardingConversationPersistenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class FileOnboardingConversationRepository
    implements OnboardingConversationRepository {
  FileOnboardingConversationRepository({
    OnboardingConversationDirectoryResolver? directoryResolver,
    this.fileName = 'onboarding_conversation_v2.json',
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  final OnboardingConversationDirectoryResolver _directoryResolver;
  final String fileName;
  Future<void> _mutationTail = Future<void>.value();

  @override
  Future<OnboardingConversationSnapshot?> read() =>
      _enqueueMutation(_readInternal);

  @override
  Future<OnboardingConversationSnapshot> save(
    OnboardingConversationSnapshot checkpoint,
  ) {
    return _enqueueMutation(() async {
      _validatePersistable(checkpoint);
      final existing = await _readInternal();
      if (existing?.completionId != null) return existing!;
      var next = checkpoint;
      if (existing?.phraseSaidEventId != null &&
          next.phraseSaidEventId == null) {
        next = next.copyWith(
          phraseSaidEventId: existing!.phraseSaidEventId,
          phraseSaidAt: existing.phraseSaidAt,
        );
      }
      await _writeInternal(next);
      return next;
    });
  }

  @override
  Future<OnboardingConversationSnapshot?> saveNextSupport(
    OnboardingConversationSnapshot checkpoint, {
    required bool Function() commitIfCurrent,
  }) {
    return _enqueueMutation(() async {
      _validatePersistable(checkpoint);
      final existing = await _readInternal();
      if (existing?.completionId != null) return existing;
      final committed = await _writeInternal(
        checkpoint,
        commitIfCurrent: commitIfCurrent,
      );
      return committed ? checkpoint : _readInternal();
    });
  }

  @override
  Future<OnboardingConversationSnapshot> defer({
    required OnboardingConversationSnapshot checkpoint,
    required DateTime deferredAt,
  }) {
    return _enqueueMutation(() async {
      final existing = await _readInternal();
      if (existing?.status == OnboardingConversationStatus.completed) {
        return existing!;
      }
      var current = existing ?? checkpoint;
      if (checkpoint.phase == OnboardingCheckpointPhase.selection &&
          current.phraseSaidEventId == null &&
          current.currentUtterance == null) {
        current = checkpoint;
      }
      final next = current.copyWith(
        status: OnboardingConversationStatus.deferred,
        deferredAt: deferredAt.toUtc(),
      );
      await _writeInternal(next);
      return next;
    });
  }

  @override
  Future<OnboardingConversationSnapshot> recordPhraseSaid({
    required OnboardingConversationSnapshot checkpoint,
    required String eventId,
    required DateTime occurredAt,
  }) {
    return _enqueueMutation(() async {
      final normalizedEventId = _requiredString(eventId, 'eventId');
      final existing = await _readInternal();
      final current = existing ?? checkpoint;
      if (current.phraseSaidEventId != null) {
        if (current.activeEntryId != checkpoint.activeEntryId) {
          throw const OnboardingConversationPersistenceException(
            'PhraseSaid identity 与当前 Care Entry 冲突。',
          );
        }
        return current;
      }
      if (checkpoint.activeEntryId == null ||
          checkpoint.phase != OnboardingCheckpointPhase.firstUtterance) {
        throw const OnboardingConversationPersistenceException(
          '只有已开始的 first utterance 可以记录 PhraseSaid。',
        );
      }
      final next = checkpoint.copyWith(
        phase: OnboardingCheckpointPhase.reactionPrompt,
        phraseSaidEventId: normalizedEventId,
        phraseSaidAt: occurredAt.toUtc(),
      );
      await _writeInternal(next);
      return next;
    });
  }

  @override
  Future<OnboardingConversationSnapshot> complete({
    required OnboardingConversationSnapshot checkpoint,
    required String completionId,
    required DateTime completedAt,
  }) {
    return _enqueueMutation(() async {
      final existing = await _readInternal();
      final current = existing ?? checkpoint;
      if (current.completionId != null) return current;
      if (current.phraseSaidEventId == null) {
        throw const OnboardingConversationPersistenceException(
          'PhraseSaid 未持久化，不能完成 Care Turn。',
        );
      }
      final next = current.copyWith(
        status: OnboardingConversationStatus.completed,
        phase: OnboardingCheckpointPhase.completed,
        completionId: _requiredString(completionId, 'completionId'),
        gardenTraceId: current.phraseSaidEventId,
        completedAt: completedAt.toUtc(),
        deferredAt: null,
      );
      await _writeInternal(next);
      return next;
    });
  }

  Future<OnboardingConversationSnapshot?> _readInternal() async {
    final file = await _resolveFile();
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('onboarding conversation 顶层必须是对象。');
      }
      return _snapshotFromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw OnboardingConversationPersistenceException(
        '读取 onboarding conversation 失败：$error',
      );
    }
  }

  Future<bool> _writeInternal(
    OnboardingConversationSnapshot snapshot, {
    bool Function()? commitIfCurrent,
  }) async {
    _validatePersistable(snapshot);
    final file = await _resolveFile();
    final temporary = File('${file.path}.tmp');
    try {
      await file.parent.create(recursive: true);
      await _deleteIfExists(temporary);
      await temporary.writeAsString(
        jsonEncode(_snapshotToJson(snapshot)),
        flush: true,
      );
      // The callback is the single commit boundary. Callers may atomically
      // claim a race here; once it returns true no competing winner may take
      // over while the filesystem replacement finishes.
      if (commitIfCurrent != null && !commitIfCurrent()) {
        await _deleteIfExists(temporary);
        return false;
      }
      if (Platform.isWindows) await _deleteIfExists(file);
      await temporary.rename(file.path);
      return true;
    } catch (error) {
      await _deleteIfExistsBestEffort(temporary);
      throw OnboardingConversationPersistenceException(
        '写入 onboarding conversation 失败：$error',
      );
    }
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final running = _mutationTail.then((_) => mutation());
    _mutationTail = running.then<void>((_) {}, onError: (_, _) {});
    return running;
  }
}

Map<String, Object?> _snapshotToJson(OnboardingConversationSnapshot value) =>
    <String, Object?>{
      'schemaVersion': value.schemaVersion,
      'status': value.status.name,
      'registryRevision': value.registryRevision,
      'phase': _phaseToWire(value.phase),
      'selectedEntryId': value.selectedEntryId?.value,
      'activeEntryId': value.activeEntryId?.value,
      'conversationRequestEventId': value.conversationRequestEventId,
      'conversationId': value.conversationId,
      'conversationExpiresAt': value.conversationExpiresAt
          ?.toUtc()
          .toIso8601String(),
      'currentUtterance': _utteranceToJson(value.currentUtterance),
      'phraseSaidEventId': value.phraseSaidEventId,
      'phraseSaidAt': value.phraseSaidAt?.toUtc().toIso8601String(),
      'selectedReaction': value.selectedReaction?.wireValue,
      'nextSupportId': value.nextSupportId?.value,
      'nextSupportEnglish': value.nextSupportEnglish,
      'nextSupportChinese': value.nextSupportChinese,
      'nextSupportSource': value.nextSupportSource?.name,
      'completionId': value.completionId,
      'gardenTraceId': value.gardenTraceId,
      'completedAt': value.completedAt?.toUtc().toIso8601String(),
      'deferredAt': value.deferredAt?.toUtc().toIso8601String(),
    };

Map<String, Object?>? _utteranceToJson(OnboardingUtterance? value) =>
    value == null
    ? null
    : <String, Object?>{
        'utteranceId': value.utteranceId,
        'english': value.english,
        'chinese': value.chinese,
        'pronunciation': value.pronunciation,
        'source': value.source.name,
        'localAudioAsset': value.localAudioAsset,
      };

OnboardingConversationSnapshot _snapshotFromJson(Map<String, dynamic> json) {
  _requireSnapshotKeys(json, const <String>{
    'schemaVersion',
    'status',
    'registryRevision',
    'phase',
    'selectedEntryId',
    'activeEntryId',
    'conversationRequestEventId',
    'conversationId',
    'conversationExpiresAt',
    'currentUtterance',
    'phraseSaidEventId',
    'phraseSaidAt',
    'selectedReaction',
    'nextSupportId',
    'nextSupportEnglish',
    'nextSupportChinese',
    'nextSupportSource',
    'completionId',
    'gardenTraceId',
    'completedAt',
    'deferredAt',
  });
  if (json['schemaVersion'] != 2) {
    throw const FormatException('onboarding conversation schemaVersion 不受支持。');
  }
  final reaction = _optionalString(json, 'selectedReaction');
  final activeEntryId = _optionalString(json, 'activeEntryId');
  final nextSupportId = _optionalString(json, 'nextSupportId');
  final nextSupportSource = _optionalString(json, 'nextSupportSource');
  final selectedEntryId = _optionalString(json, 'selectedEntryId');
  final status = _optionalString(json, 'status');
  final snapshot = OnboardingConversationSnapshot(
    status: status == null
        ? (json['completionId'] == null
              ? OnboardingConversationStatus.active
              : OnboardingConversationStatus.completed)
        : OnboardingConversationStatus.values.firstWhere(
            (candidate) => candidate.name == status,
            orElse: () => throw const FormatException(
              'onboarding conversation status 不受支持。',
            ),
          ),
    registryRevision: _requiredString(
      json['registryRevision'],
      'registryRevision',
    ),
    phase: _parsePhase(_requiredString(json['phase'], 'phase')),
    selectedEntryId: selectedEntryId == null
        ? null
        : CareEntryId(selectedEntryId),
    activeEntryId: activeEntryId == null ? null : CareEntryId(activeEntryId),
    conversationRequestEventId: _optionalString(
      json,
      'conversationRequestEventId',
    ),
    conversationId: _optionalString(json, 'conversationId'),
    conversationExpiresAt: _optionalDateTime(json, 'conversationExpiresAt'),
    currentUtterance: _optionalUtterance(json['currentUtterance']),
    phraseSaidEventId: _optionalString(json, 'phraseSaidEventId'),
    phraseSaidAt: _optionalDateTime(json, 'phraseSaidAt'),
    selectedReaction: reaction == null ? null : parseCareReaction(reaction),
    nextSupportId: nextSupportId == null ? null : CareSupportId(nextSupportId),
    nextSupportEnglish: _optionalString(json, 'nextSupportEnglish'),
    nextSupportChinese: _optionalString(json, 'nextSupportChinese'),
    nextSupportSource: nextSupportSource == null
        ? null
        : OnboardingUtteranceSource.values.firstWhere(
            (source) => source.name == nextSupportSource,
            orElse: () =>
                throw const FormatException('nextSupportSource 不受支持。'),
          ),
    completionId: _optionalString(json, 'completionId'),
    gardenTraceId: _optionalString(json, 'gardenTraceId'),
    completedAt: _optionalDateTime(json, 'completedAt'),
    deferredAt: _optionalDateTime(json, 'deferredAt'),
  );
  _validatePersistable(snapshot);
  return snapshot;
}

void _validatePersistable(OnboardingConversationSnapshot value) {
  if (value.schemaVersion != 2) {
    throw const FormatException('onboarding conversation 必须使用 schema v2。');
  }
  _requiredString(value.registryRevision, 'registryRevision');
  final isLegacyCompletion =
      value.status == OnboardingConversationStatus.completed &&
      value.registryRevision == 'legacy.m1' &&
      value.selectedEntryId == null;
  if (!isLegacyCompletion) {
    _requiredString(value.selectedEntryId?.value, 'selectedEntryId');
  }
  if ((value.conversationId == null) != (value.conversationExpiresAt == null)) {
    throw const FormatException('conversation identity/expiry 必须同时存在。');
  }
  if ((value.phraseSaidEventId == null) != (value.phraseSaidAt == null)) {
    throw const FormatException('PhraseSaid identity/time 必须同时存在。');
  }
  if (!isLegacyCompletion &&
      value.phase.index >= OnboardingCheckpointPhase.reactionPrompt.index &&
      value.phraseSaidEventId == null) {
    throw const FormatException('reaction 之后必须存在 PhraseSaid。');
  }
  final completionFields = <Object?>[
    value.completionId,
    value.gardenTraceId,
    value.completedAt,
  ];
  final completionCount = completionFields.where((item) => item != null).length;
  if (!isLegacyCompletion &&
      completionCount != 0 &&
      completionCount != completionFields.length) {
    throw const FormatException('completion 与 Garden Trace 必须原子存在。');
  }
  if (!isLegacyCompletion &&
      value.phase == OnboardingCheckpointPhase.completed &&
      completionCount != completionFields.length) {
    throw const FormatException('completed phase 缺少 completion/Trace。');
  }
  if (value.gardenTraceId != null &&
      value.gardenTraceId != value.phraseSaidEventId) {
    throw const FormatException('Garden Trace 必须由同一个 PhraseSaid event 投影。');
  }
  if (value.status == OnboardingConversationStatus.deferred) {
    if (value.deferredAt == null ||
        value.phase == OnboardingCheckpointPhase.completed) {
      throw const FormatException('deferred status 缺少时间或 phase 非法。');
    }
  } else if (value.deferredAt != null) {
    throw const FormatException('只有 deferred status 可以包含 deferredAt。');
  }
  if (value.status == OnboardingConversationStatus.completed &&
      value.phase != OnboardingCheckpointPhase.completed) {
    throw const FormatException('completed status/phase 必须一致。');
  }
  if (value.phase == OnboardingCheckpointPhase.completed &&
      value.status != OnboardingConversationStatus.completed) {
    throw const FormatException('completed phase 缺少 completed status。');
  }
  final nextSupportFields = <Object?>[
    value.nextSupportEnglish,
    value.nextSupportChinese,
    value.nextSupportSource,
  ];
  final nextSupportFieldCount = nextSupportFields
      .where((item) => item != null)
      .length;
  if (nextSupportFieldCount != 0) {
    if (value.nextSupportId == null ||
        nextSupportFieldCount != nextSupportFields.length) {
      throw const FormatException(
        'next support identity/content/source 必须原子存在。',
      );
    }
    _requiredString(value.nextSupportEnglish, 'nextSupportEnglish');
    _requiredString(value.nextSupportChinese, 'nextSupportChinese');
  }
  if (value.phase == OnboardingCheckpointPhase.nextSupportReady &&
      value.nextSupportId == null) {
    throw const FormatException('next_support_ready 缺少 next support。');
  }
}

void _requireSnapshotKeys(Map<String, dynamic> json, Set<String> allowed) {
  const legacyRequired = <String>{
    'schemaVersion',
    'registryRevision',
    'phase',
    'selectedEntryId',
    'activeEntryId',
    'conversationRequestEventId',
    'phraseSaidEventId',
    'phraseSaidAt',
    'selectedReaction',
    'nextSupportId',
    'completionId',
    'gardenTraceId',
    'completedAt',
  };
  if (!json.keys.every(allowed.contains) ||
      !legacyRequired.every(json.containsKey)) {
    throw const FormatException('onboarding conversation 字段集合不合法。');
  }
}

OnboardingUtterance? _optionalUtterance(Object? value) {
  if (value == null) return null;
  if (value is! Map) {
    throw const FormatException('currentUtterance 必须是对象。');
  }
  final json = value.map<String, dynamic>((key, value) {
    if (key is! String) throw const FormatException('utterance key 非法。');
    return MapEntry(key, value);
  });
  const keys = <String>{
    'utteranceId',
    'english',
    'chinese',
    'pronunciation',
    'source',
    'localAudioAsset',
  };
  if (json.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(json.keys.toSet()).isNotEmpty) {
    throw const FormatException('currentUtterance 字段集合不合法。');
  }
  final sourceName = _requiredString(json['source'], 'currentUtterance.source');
  final source = OnboardingUtteranceSource.values.firstWhere(
    (candidate) => candidate.name == sourceName,
    orElse: () => throw const FormatException('currentUtterance source 非法。'),
  );
  final localAudioAsset = json['localAudioAsset'];
  if (localAudioAsset != null && localAudioAsset is! String) {
    throw const FormatException('currentUtterance localAudioAsset 非法。');
  }
  return OnboardingUtterance(
    utteranceId: _requiredString(json['utteranceId'], 'utteranceId'),
    english: _requiredString(json['english'], 'english'),
    chinese: _requiredString(json['chinese'], 'chinese'),
    pronunciation: _requiredString(json['pronunciation'], 'pronunciation'),
    source: source,
    localAudioAsset: localAudioAsset as String?,
  );
}

String _phaseToWire(OnboardingCheckpointPhase value) => switch (value) {
  OnboardingCheckpointPhase.selection => 'selection',
  OnboardingCheckpointPhase.firstUtterance => 'first_utterance',
  OnboardingCheckpointPhase.reactionPrompt => 'reaction_prompt',
  OnboardingCheckpointPhase.nextSupportReady => 'next_support_ready',
  OnboardingCheckpointPhase.completed => 'completed',
};

OnboardingCheckpointPhase _parsePhase(String value) => switch (value) {
  'selection' => OnboardingCheckpointPhase.selection,
  'first_utterance' => OnboardingCheckpointPhase.firstUtterance,
  'reaction_prompt' => OnboardingCheckpointPhase.reactionPrompt,
  'next_support_ready' => OnboardingCheckpointPhase.nextSupportReady,
  'completed' => OnboardingCheckpointPhase.completed,
  _ => throw FormatException('未知 onboarding conversation phase: $value'),
};

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw FormatException('$field 必须是非空且已规范化的字符串。');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value == null ? null : _requiredString(value, field);
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String field) {
  final raw = _optionalString(json, field);
  if (raw == null) return null;
  final value = DateTime.tryParse(raw);
  if (value == null || !value.isUtc) {
    throw FormatException('$field 必须是 UTC ISO 8601。');
  }
  return value;
}

Future<void> _deleteIfExists(File file) async {
  if (await file.exists()) await file.delete();
}

Future<void> _deleteIfExistsBestEffort(File file) async {
  try {
    await _deleteIfExists(file);
  } on Object {
    // Best-effort cleanup; original persistence error remains authoritative.
  }
}
