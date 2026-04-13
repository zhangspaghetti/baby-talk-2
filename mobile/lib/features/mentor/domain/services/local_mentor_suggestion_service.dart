import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

class LocalMentorPracticePhraseContext {
  const LocalMentorPracticePhraseContext({
    required this.phraseId,
    required this.english,
    required this.chinese,
    required this.step,
  });

  final String phraseId;
  final String english;
  final String chinese;
  final int step;
}

class LocalMentorRecentPracticeContext {
  const LocalMentorRecentPracticeContext({
    required this.activityId,
    required this.activityTitle,
    required this.phraseId,
    required this.phraseEnglish,
    required this.reactionType,
    required this.totalEvents,
  });

  final String activityId;
  final String activityTitle;
  final String phraseId;
  final String phraseEnglish;
  final BabyReactionType reactionType;
  final int totalEvents;
}

class LocalMentorSuggestionContext {
  const LocalMentorSuggestionContext({
    this.stageId,
    this.starterSpaceId,
    this.starterActivityId,
    this.starterPhraseId,
    this.activityTitle,
    this.activitySummary,
    this.coachTip,
    this.sceneTag,
    this.phrases = const <LocalMentorPracticePhraseContext>[],
    this.recentPractice,
    this.contextFallbackUsed = false,
    this.fallbackReasonCode,
  });

  final String? stageId;
  final String? starterSpaceId;
  final String? starterActivityId;
  final String? starterPhraseId;
  final String? activityTitle;
  final String? activitySummary;
  final String? coachTip;
  final String? sceneTag;
  final List<LocalMentorPracticePhraseContext> phrases;
  final LocalMentorRecentPracticeContext? recentPractice;
  final bool contextFallbackUsed;
  final String? fallbackReasonCode;
}

class LocalMentorSuggestionResult {
  const LocalMentorSuggestionResult({
    required this.suggestions,
    required this.primaryOrigin,
    required this.contextFallbackUsed,
    this.fallbackReasonCode,
    this.redactedContextSummary,
  });

  final List<LocalMentorSuggestion> suggestions;
  final LocalMentorSuggestionOrigin primaryOrigin;
  final bool contextFallbackUsed;
  final String? fallbackReasonCode;
  final String? redactedContextSummary;
}

class LocalMentorSuggestionService {
  const LocalMentorSuggestionService();

  LocalMentorSuggestionResult derive(LocalMentorSuggestionContext context) {
    if (context.contextFallbackUsed) {
      return _buildSafeFallback(
        reasonCode: context.fallbackReasonCode ?? 'context_fallback_used',
      );
    }

    final stageMatch = context.stageId == null
        ? null
        : StageMatchCatalog.maybeForStageId(context.stageId!);
    final starterPhrase = _findStarterPhrase(context);
    final recentPractice = context.recentPractice;

    if (recentPractice != null) {
      final suggestions = <LocalMentorSuggestion>[
        LocalMentorSuggestion(
          suggestionId: 'recent_${recentPractice.phraseId}',
          origin: LocalMentorSuggestionOrigin.recentPractice,
          title: '接住刚刚的回应',
          body:
              '宝宝刚刚对“${recentPractice.phraseEnglish}”有${_reactionLabel(recentPractice.reactionType)}，现在先在 ${recentPractice.activityTitle} 里轻轻重复一次，停两秒等回应就好。',
          phraseEnglish: recentPractice.phraseEnglish,
          stageId: stageMatch?.stageId,
          activityId: recentPractice.activityId,
          phraseId: recentPractice.phraseId,
          reasonCode: 'recent_result',
          redactedContextSummary:
              'recent_result:${recentPractice.activityId}/${recentPractice.phraseId}:${recentPractice.reactionType.wireValue}',
        ),
        if (stageMatch != null)
          LocalMentorSuggestion(
            suggestionId: 'stage_${stageMatch.stageId}',
            origin: LocalMentorSuggestionOrigin.stageGuide,
            title: '保持这个阶段的节奏',
            body: '${stageMatch.summary} 这次先只保留一句短句，不急着加新内容。',
            stageId: stageMatch.stageId,
            reasonCode: 'stage_reinforcement',
            redactedContextSummary: 'stage:${stageMatch.stageId}',
          ),
      ];
      return LocalMentorSuggestionResult(
        suggestions: List.unmodifiable(suggestions),
        primaryOrigin: LocalMentorSuggestionOrigin.recentPractice,
        contextFallbackUsed: false,
        redactedContextSummary:
            'recent_result:${recentPractice.activityId}/${recentPractice.phraseId}',
      );
    }

    if (starterPhrase != null) {
      final title = _normalize(context.activityTitle) ?? '熟悉场景';
      final bodySegments = <String>[
        '先回到$title里最熟悉的一句“${starterPhrase.english}”，边做动作边说一次就够。',
        if (_normalize(context.coachTip) != null) _normalize(context.coachTip)!,
      ];
      final suggestions = <LocalMentorSuggestion>[
        LocalMentorSuggestion(
          suggestionId: 'starter_${starterPhrase.phraseId}',
          origin: LocalMentorSuggestionOrigin.starterPhrase,
          title: '先回到熟悉短句',
          body: bodySegments.join(' '),
          phraseEnglish: starterPhrase.english,
          phraseChinese: starterPhrase.chinese,
          stageId: stageMatch?.stageId,
          spaceId: _normalize(context.starterSpaceId),
          activityId: _normalize(context.starterActivityId),
          phraseId: starterPhrase.phraseId,
          reasonCode: 'starter_phrase',
          redactedContextSummary:
              'starter_phrase:${context.starterActivityId}/${starterPhrase.phraseId}',
        ),
        if (stageMatch != null)
          LocalMentorSuggestion(
            suggestionId: 'stage_${stageMatch.stageId}',
            origin: LocalMentorSuggestionOrigin.stageGuide,
            title: '按当前阶段减轻压力',
            body: stageMatch.summary,
            stageId: stageMatch.stageId,
            reasonCode: 'stage_guide',
            redactedContextSummary: 'stage:${stageMatch.stageId}',
          ),
      ];
      return LocalMentorSuggestionResult(
        suggestions: List.unmodifiable(suggestions),
        primaryOrigin: LocalMentorSuggestionOrigin.starterPhrase,
        contextFallbackUsed: false,
        redactedContextSummary:
            'starter_phrase:${context.starterActivityId}/${starterPhrase.phraseId}',
      );
    }

    if (stageMatch != null) {
      final suggestions = <LocalMentorSuggestion>[
        LocalMentorSuggestion(
          suggestionId: 'stage_${stageMatch.stageId}',
          origin: LocalMentorSuggestionOrigin.stageGuide,
          title: '按阶段先做一小步',
          body: stageMatch.summary,
          stageId: stageMatch.stageId,
          reasonCode: 'stage_only',
          redactedContextSummary: 'stage:${stageMatch.stageId}',
        ),
      ];
      return LocalMentorSuggestionResult(
        suggestions: List.unmodifiable(suggestions),
        primaryOrigin: LocalMentorSuggestionOrigin.stageGuide,
        contextFallbackUsed: false,
        redactedContextSummary: 'stage:${stageMatch.stageId}',
      );
    }

    return _buildSafeFallback(reasonCode: 'no_local_context');
  }

  LocalMentorSuggestionResult _buildSafeFallback({required String reasonCode}) {
    final suggestions = <LocalMentorSuggestion>[
      LocalMentorSuggestion(
        suggestionId: 'safe_small_step',
        origin: LocalMentorSuggestionOrigin.safeFallback,
        title: '先把节奏放慢',
        body: '先选一个正在发生的照护动作，用平静语气说一句简短英文，然后停两秒等宝宝回应。一次只说一句就够了。',
        reasonCode: reasonCode,
        redactedContextSummary: 'fallback:$reasonCode',
      ),
      LocalMentorSuggestion(
        suggestionId: 'safe_repeat_once',
        origin: LocalMentorSuggestionOrigin.safeFallback,
        title: '重复比丰富更重要',
        body: '如果一时想不起具体句子，就重复同一个温柔语气，不需要追求完整对话。先稳住互动感最重要。',
        reasonCode: reasonCode,
        redactedContextSummary: 'fallback:$reasonCode',
      ),
    ];
    return LocalMentorSuggestionResult(
      suggestions: List.unmodifiable(suggestions),
      primaryOrigin: LocalMentorSuggestionOrigin.safeFallback,
      contextFallbackUsed: true,
      fallbackReasonCode: reasonCode,
      redactedContextSummary: 'fallback:$reasonCode',
    );
  }

  LocalMentorPracticePhraseContext? _findStarterPhrase(
    LocalMentorSuggestionContext context,
  ) {
    final starterPhraseId = _normalize(context.starterPhraseId);
    if (starterPhraseId == null) {
      return null;
    }
    for (final phrase in context.phrases) {
      if (phrase.phraseId == starterPhraseId) {
        return phrase;
      }
    }
    return null;
  }

  String _reactionLabel(BabyReactionType reactionType) {
    switch (reactionType) {
      case BabyReactionType.calm:
        return '平静回应';
      case BabyReactionType.engaged:
        return '专注回应';
      case BabyReactionType.imitated:
        return '模仿回应';
      case BabyReactionType.needsBreak:
        return '想先休息一下';
    }
  }

  String? _normalize(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
