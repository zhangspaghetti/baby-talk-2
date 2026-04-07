import 'dart:math';

import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';

class PracticeActivitySnapshot {
  const PracticeActivitySnapshot({
    required this.spaceId,
    required this.activityId,
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.phrases,
  });

  final String spaceId;
  final String activityId;
  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final List<PracticePhrase> phrases;
}

class PracticeRecentResultSummary {
  const PracticeRecentResultSummary({
    required this.activityId,
    required this.activityTitle,
    required this.phraseId,
    required this.phraseEnglish,
    required this.reactionType,
    required this.eventTime,
    required this.totalEvents,
  });

  final String activityId;
  final String activityTitle;
  final String phraseId;
  final String phraseEnglish;
  final BabyReactionType reactionType;
  final DateTime eventTime;
  final int totalEvents;
}

class PracticeHomeSummary {
  const PracticeHomeSummary({
    required this.spaceId,
    required this.activityId,
    required this.activityTitle,
    required this.totalEvents,
    required this.lastEventTime,
    required this.recentResult,
  });

  final String spaceId;
  final String activityId;
  final String activityTitle;
  final int totalEvents;
  final DateTime? lastEventTime;
  final PracticeRecentResultSummary? recentResult;

  bool get isEmpty => totalEvents == 0;
}

class PracticeResumeInfo {
  const PracticeResumeInfo({
    required this.activityId,
    required this.totalPhrases,
    required this.completedPhraseIds,
    required this.nextPhraseId,
    required this.lastEventTime,
  });

  final String activityId;
  final int totalPhrases;
  final List<String> completedPhraseIds;
  final String? nextPhraseId;
  final DateTime? lastEventTime;

  int get completedCount => completedPhraseIds.length;
  bool get isEmpty => completedPhraseIds.isEmpty;
  bool get isComplete => completedCount >= totalPhrases && totalPhrases > 0;
}

class PracticeRepository {
  PracticeRepository({
    required AssetPhraseService assetPhraseService,
    required PracticeLocalDataSource localDataSource,
    required InstallationIdService installationIdService,
    Random? random,
  }) : _assetPhraseService = assetPhraseService,
       _localDataSource = localDataSource,
       _installationIdService = installationIdService,
       _random = random ?? Random();

  final AssetPhraseService _assetPhraseService;
  final PracticeLocalDataSource _localDataSource;
  final InstallationIdService _installationIdService;
  final Random _random;

  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    final activity = await _assetPhraseService.loadActivity(
      spaceId: spaceId,
      activityId: activityId,
    );
    final phrases = await _assetPhraseService.loadPracticePhrases(
      spaceId: spaceId,
      activityId: activityId,
    );
    return PracticeActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
      title: activity.title,
      summary: activity.summary,
      sceneTag: activity.sceneTag,
      coachTip: activity.coachTip,
      phrases: phrases,
    );
  }

  Future<InteractionEventPayload> recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    final snapshot = await getActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
    );
    final phraseExists = snapshot.phrases.any(
      (phrase) => phrase.phraseId == phraseId,
    );
    if (!phraseExists) {
      throw FormatException('未知 phraseId: $spaceId/$activityId/$phraseId');
    }

    final payload = InteractionEventPayload(
      localEventId: localEventId ?? _generateLocalEventId(),
      installationId: await _installationIdService.getOrCreate(),
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp ?? DateTime.now().toUtc(),
    );
    await _localDataSource.appendInteractionEvent(payload);
    return payload;
  }

  Future<PracticeHomeSummary> getHomeSummary({
    required String spaceId,
    required String activityId,
  }) async {
    final snapshot = await getActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
    );
    final events = await _localDataSource.listInteractionEvents(
      activityId: activityId,
    );
    if (events.isEmpty) {
      return PracticeHomeSummary(
        spaceId: spaceId,
        activityId: activityId,
        activityTitle: snapshot.title,
        totalEvents: 0,
        lastEventTime: null,
        recentResult: null,
      );
    }

    final latest = events.last;
    final phraseById = {
      for (final phrase in snapshot.phrases) phrase.phraseId: phrase,
    };
    final latestPhrase =
        phraseById[latest.phraseId] ??
        (throw StateError('事件引用了未知 phraseId: ${latest.phraseId}'));

    return PracticeHomeSummary(
      spaceId: spaceId,
      activityId: activityId,
      activityTitle: snapshot.title,
      totalEvents: events.length,
      lastEventTime: latest.clientTimestamp,
      recentResult: PracticeRecentResultSummary(
        activityId: activityId,
        activityTitle: snapshot.title,
        phraseId: latest.phraseId,
        phraseEnglish: latestPhrase.english,
        reactionType: latest.reactionType,
        eventTime: latest.clientTimestamp,
        totalEvents: events.length,
      ),
    );
  }

  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async {
    final snapshot = await getActivitySnapshot(
      spaceId: spaceId,
      activityId: activityId,
    );
    final events = await _localDataSource.listInteractionEvents(
      activityId: activityId,
    );

    final completedPhraseIds = <String>[];
    for (final event in events) {
      if (!completedPhraseIds.contains(event.phraseId)) {
        completedPhraseIds.add(event.phraseId);
      }
    }

    String? nextPhraseId;
    for (final phrase in snapshot.phrases) {
      if (!completedPhraseIds.contains(phrase.phraseId)) {
        nextPhraseId = phrase.phraseId;
        break;
      }
    }
    nextPhraseId ??= snapshot.phrases.isEmpty
        ? null
        : snapshot.phrases.last.phraseId;

    return PracticeResumeInfo(
      activityId: activityId,
      totalPhrases: snapshot.phrases.length,
      completedPhraseIds: List.unmodifiable(completedPhraseIds),
      nextPhraseId: nextPhraseId,
      lastEventTime: events.isEmpty ? null : events.last.clientTimestamp,
    );
  }

  Future<List<InteractionEventPayload>> listEventHistory({String? activityId}) {
    return _localDataSource.listInteractionEvents(activityId: activityId);
  }

  String _generateLocalEventId() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final entropy = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'evt_${timestamp}_$entropy';
  }
}
