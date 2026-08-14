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
        phase: OnboardingCheckpointPhase.completed,
        completionId: _requiredString(completionId, 'completionId'),
        gardenTraceId: current.phraseSaidEventId,
        completedAt: completedAt.toUtc(),
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
      'registryRevision': value.registryRevision,
      'phase': _phaseToWire(value.phase),
      'selectedEntryId': value.selectedEntryId.value,
      'activeEntryId': value.activeEntryId?.value,
      'conversationRequestEventId': value.conversationRequestEventId,
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
    };

OnboardingConversationSnapshot _snapshotFromJson(Map<String, dynamic> json) {
  _requireSnapshotKeys(json, const <String>{
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
    'nextSupportEnglish',
    'nextSupportChinese',
    'nextSupportSource',
    'completionId',
    'gardenTraceId',
    'completedAt',
  });
  if (json['schemaVersion'] != 2) {
    throw const FormatException('onboarding conversation schemaVersion 不受支持。');
  }
  final reaction = _optionalString(json, 'selectedReaction');
  final activeEntryId = _optionalString(json, 'activeEntryId');
  final nextSupportId = _optionalString(json, 'nextSupportId');
  final nextSupportSource = _optionalString(json, 'nextSupportSource');
  final snapshot = OnboardingConversationSnapshot(
    registryRevision: _requiredString(
      json['registryRevision'],
      'registryRevision',
    ),
    phase: _parsePhase(_requiredString(json['phase'], 'phase')),
    selectedEntryId: CareEntryId(
      _requiredString(json['selectedEntryId'], 'selectedEntryId'),
    ),
    activeEntryId: activeEntryId == null ? null : CareEntryId(activeEntryId),
    conversationRequestEventId: _optionalString(
      json,
      'conversationRequestEventId',
    ),
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
  );
  _validatePersistable(snapshot);
  return snapshot;
}

void _validatePersistable(OnboardingConversationSnapshot value) {
  if (value.schemaVersion != 2) {
    throw const FormatException('onboarding conversation 必须使用 schema v2。');
  }
  _requiredString(value.registryRevision, 'registryRevision');
  _requiredString(value.selectedEntryId.value, 'selectedEntryId');
  if ((value.phraseSaidEventId == null) != (value.phraseSaidAt == null)) {
    throw const FormatException('PhraseSaid identity/time 必须同时存在。');
  }
  if (value.phase.index >= OnboardingCheckpointPhase.reactionPrompt.index &&
      value.phraseSaidEventId == null) {
    throw const FormatException('reaction 之后必须存在 PhraseSaid。');
  }
  final completionFields = <Object?>[
    value.completionId,
    value.gardenTraceId,
    value.completedAt,
  ];
  final completionCount = completionFields.where((item) => item != null).length;
  if (completionCount != 0 && completionCount != completionFields.length) {
    throw const FormatException('completion 与 Garden Trace 必须原子存在。');
  }
  if (value.phase == OnboardingCheckpointPhase.completed &&
      completionCount != completionFields.length) {
    throw const FormatException('completed phase 缺少 completion/Trace。');
  }
  if (value.gardenTraceId != null &&
      value.gardenTraceId != value.phraseSaidEventId) {
    throw const FormatException('Garden Trace 必须由同一个 PhraseSaid event 投影。');
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
