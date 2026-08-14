import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/data/file_onboarding_conversation_repository.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';

void main() {
  test(
    'snapshot v2 round-trips idempotent PhraseSaid completion and Garden Trace without private data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'onboarding_conversation_repository_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = FileOnboardingConversationRepository(
        directoryResolver: () async => directory,
      );
      const initial = OnboardingConversationSnapshot(
        registryRevision: 'test.1',
        phase: OnboardingCheckpointPhase.firstUtterance,
        selectedEntryId: CareEntryId('care.bedtime_soothing'),
        activeEntryId: CareEntryId('care.bedtime_soothing'),
        conversationRequestEventId: 'onboarding-request-1',
      );

      final saved = await repository.save(initial);
      final said = await repository.recordPhraseSaid(
        checkpoint: saved,
        eventId: 'event.phrase_said.1',
        occurredAt: DateTime.utc(2026, 8, 14, 12),
      );
      final duplicateSaid = await repository.recordPhraseSaid(
        checkpoint: saved,
        eventId: 'event.phrase_said.2',
        occurredAt: DateTime.utc(2026, 8, 14, 13),
      );
      expect(duplicateSaid.phraseSaidEventId, 'event.phrase_said.1');

      final supportReady = await repository.save(
        said.copyWith(
          phase: OnboardingCheckpointPhase.nextSupportReady,
          selectedReaction: CareReaction.other,
          nextSupportId: const CareSupportId('support.bedtime.other'),
          nextSupportEnglish: 'I am right here.',
          nextSupportChinese: '我就在这里。',
          nextSupportSource: OnboardingUtteranceSource.remoteGenerated,
        ),
      );
      final completed = await repository.complete(
        checkpoint: supportReady,
        completionId: 'completion.1',
        completedAt: DateTime.utc(2026, 8, 14, 12, 1),
      );
      final duplicateCompletion = await repository.complete(
        checkpoint: supportReady,
        completionId: 'completion.2',
        completedAt: DateTime.utc(2026, 8, 14, 13),
      );

      expect(completed.gardenTraceId, 'event.phrase_said.1');
      expect(duplicateCompletion.completionId, 'completion.1');
      expect(duplicateCompletion.gardenTraceId, 'event.phrase_said.1');

      final restored = await FileOnboardingConversationRepository(
        directoryResolver: () async => directory,
      ).read();
      expect(restored?.schemaVersion, 2);
      expect(restored?.phase, OnboardingCheckpointPhase.completed);
      expect(restored?.conversationRequestEventId, 'onboarding-request-1');
      expect(restored?.selectedReaction, CareReaction.other);
      expect(restored?.nextSupportEnglish, 'I am right here.');
      expect(
        restored?.nextSupportSource,
        OnboardingUtteranceSource.remoteGenerated,
      );
      expect(restored?.phraseSaidEventId, 'event.phrase_said.1');
      expect(restored?.gardenTraceId, 'event.phrase_said.1');
      expect(restored?.gardenTrace?.traceId, 'event.phrase_said.1');
      expect(restored?.gardenTrace?.careEntryId.value, 'care.bedtime_soothing');

      final raw = await File(
        '${directory.path}${Platform.pathSeparator}onboarding_conversation_v2.json',
      ).readAsString();
      expect(raw, contains('"schemaVersion":2'));
      expect(raw, isNot(contains('reactionText')));
      expect(raw, isNot(contains('audioCapability')));
      expect(raw, isNot(contains('刚才有点打喷嚏')));
      expect(
        await File(
          '${directory.path}${Platform.pathSeparator}onboarding_conversation_v2.json.tmp',
        ).exists(),
        isFalse,
      );
    },
  );
}
