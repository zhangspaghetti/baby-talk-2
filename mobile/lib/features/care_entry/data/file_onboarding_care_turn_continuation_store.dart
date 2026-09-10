import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';

typedef OnboardingContinuationDirectoryResolver = Future<Directory> Function();

final class FileOnboardingCareTurnContinuationStore
    implements OnboardingCareTurnContinuationPort {
  FileOnboardingCareTurnContinuationStore({
    required OnboardingConversationRepository conversationRepository,
    required OnboardingContinuationDirectoryResolver directoryResolver,
    this.fileName = 'onboarding_care_turn_continuation_v1.json',
  }) : _conversationRepository = conversationRepository,
       _directoryResolver = directoryResolver;

  final OnboardingConversationRepository _conversationRepository;
  final OnboardingContinuationDirectoryResolver _directoryResolver;
  final String fileName;
  Future<void> _mutationTail = Future<void>.value();

  @override
  Future<OnboardingCareTurnHandoff> verify(
    OnboardingCareTurnHandoff handoff,
  ) async {
    final snapshot = await _conversationRepository.read();
    if (snapshot == null ||
        snapshot.status != OnboardingConversationStatus.completed ||
        snapshot.completionId != handoff.completionId ||
        snapshot.nextSupportId?.value != handoff.utteranceId ||
        snapshot.nextSupportEnglish != handoff.english ||
        snapshot.nextSupportChinese != handoff.chinese ||
        _source(snapshot.nextSupportSource) != handoff.source) {
      throw const FormatException('onboarding Care Turn handoff identity 不匹配。');
    }
    return handoff;
  }

  Future<void> clearForLifecycle() {
    return _enqueue(() async {
      final file = await _resolveFile();
      final temporary = File('${file.path}.tmp');
      if (await file.exists()) await file.delete();
      if (await temporary.exists()) await temporary.delete();
    });
  }

  @override
  Future<OnboardingContinuationReactionRecord> recordReaction({
    required OnboardingCareTurnHandoff handoff,
    required String reaction,
    required DateTime occurredAt,
  }) {
    return _enqueue(() async {
      final verified = await verify(handoff);
      final normalizedReaction = reaction.trim();
      if (normalizedReaction.isEmpty) {
        throw ArgumentError.value(reaction, 'reaction', '不能为空。');
      }
      final existing = await _readRecord();
      if (existing != null) {
        if (existing.completionId != verified.completionId ||
            existing.utteranceId != verified.utteranceId ||
            existing.reaction != normalizedReaction) {
          throw const FormatException(
            'onboarding continuation event identity 冲突。',
          );
        }
        return existing;
      }
      final record = OnboardingContinuationReactionRecord(
        eventId: 'onboarding_continuation_${verified.completionId}',
        completionId: verified.completionId,
        utteranceId: verified.utteranceId,
        reaction: normalizedReaction,
        occurredAt: occurredAt.toUtc(),
      );
      final file = await _resolveFile();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      try {
        await temporary.writeAsString(
          jsonEncode(<String, Object>{
            'schemaVersion': 1,
            'eventId': record.eventId,
            'completionId': record.completionId,
            'utteranceId': record.utteranceId,
            'reaction': record.reaction,
            'occurredAt': record.occurredAt.toIso8601String(),
          }),
          flush: true,
        );
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
      return record;
    });
  }

  Future<OnboardingContinuationReactionRecord?> _readRecord() async {
    final file = await _resolveFile();
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const FormatException('onboarding continuation record 无效。');
    }
    return OnboardingContinuationReactionRecord(
      eventId: _required(decoded, 'eventId'),
      completionId: _required(decoded, 'completionId'),
      utteranceId: _required(decoded, 'utteranceId'),
      reaction: _required(decoded, 'reaction'),
      occurredAt: DateTime.parse(_required(decoded, 'occurredAt')).toUtc(),
    );
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryResolver();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<T> _enqueue<T>(Future<T> Function() mutation) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        completer.complete(await mutation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _required(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key 不能为空。');
    }
    return value;
  }

  OnboardingCareTurnSource? _source(OnboardingUtteranceSource? source) =>
      switch (source) {
        OnboardingUtteranceSource.localFallback =>
          OnboardingCareTurnSource.localFallback,
        OnboardingUtteranceSource.remoteGenerated =>
          OnboardingCareTurnSource.remoteGenerated,
        null => null,
      };
}
