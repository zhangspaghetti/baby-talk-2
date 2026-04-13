import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  group('LocalMentorSuggestionService', () {
    const service = LocalMentorSuggestionService();

    test('无上下文时返回稳定安全建议', () {
      final result = service.derive(
        const LocalMentorSuggestionContext(
          contextFallbackUsed: true,
          fallbackReasonCode: 'onboarding_missing',
        ),
      );

      expect(result.contextFallbackUsed, isTrue);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.safeFallback);
      expect(result.fallbackReasonCode, 'onboarding_missing');
      expect(result.suggestions, hasLength(2));
      expect(
        result.suggestions.every((suggestion) => suggestion.isSafeFallback),
        isTrue,
      );
    });

    test('recent result 存在时优先生成 recent-practice 建议', () {
      final result = service.derive(
        const LocalMentorSuggestionContext(
          stageId: 'sound_turn_taking',
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          activityTitle: '洗澡时间',
          coachTip: '先让水声和短句一起出现。',
          phrases: <LocalMentorPracticePhraseContext>[
            LocalMentorPracticePhraseContext(
              phraseId: 'bath_time_warm_water',
              english: 'Warm water.',
              chinese: '温温的水。',
              step: 1,
            ),
          ],
          recentPractice: LocalMentorRecentPracticeContext(
            activityId: 'bath_time',
            activityTitle: '洗澡时间',
            phraseId: 'bath_time_splash_splash',
            phraseEnglish: 'Splash, splash!',
            reactionType: BabyReactionType.imitated,
            totalEvents: 3,
          ),
        ),
      );

      expect(result.contextFallbackUsed, isFalse);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.recentPractice);
      expect(result.suggestions.first.title, '接住刚刚的回应');
      expect(result.suggestions.first.phraseEnglish, 'Splash, splash!');
      expect(result.suggestions.first.reasonCode, 'recent_result');
      expect(
        result.redactedContextSummary,
        contains('recent_result:bath_time/bath_time_splash_splash'),
      );
    });

    test('空 starterPhraseId 会走安全降级，不拼接损坏上下文', () {
      final result = service.derive(
        const LocalMentorSuggestionContext(
          stageId: 'warm_routines',
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: ' ',
          contextFallbackUsed: true,
          fallbackReasonCode: 'starter_seed_missing',
          phrases: <LocalMentorPracticePhraseContext>[
            LocalMentorPracticePhraseContext(
              phraseId: 'bath_time_warm_water',
              english: 'Warm water.',
              chinese: '温温的水。',
              step: 1,
            ),
          ],
        ),
      );

      expect(result.contextFallbackUsed, isTrue);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.safeFallback);
      expect(result.fallbackReasonCode, 'starter_seed_missing');
      expect(
        result.suggestions.any(
          (suggestion) => suggestion.phraseEnglish == 'Warm water.',
        ),
        isFalse,
      );
    });

    test('practice summary 为空时仍可退回 starter phrase 建议', () {
      final result = service.derive(
        const LocalMentorSuggestionContext(
          stageId: 'warm_routines',
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          activityTitle: '洗澡时间',
          activitySummary: ' ',
          coachTip: ' ',
          phrases: <LocalMentorPracticePhraseContext>[
            LocalMentorPracticePhraseContext(
              phraseId: 'bath_time_warm_water',
              english: 'Warm water.',
              chinese: '温温的水。',
              step: 1,
            ),
          ],
        ),
      );

      expect(result.contextFallbackUsed, isFalse);
      expect(result.primaryOrigin, LocalMentorSuggestionOrigin.starterPhrase);
      expect(result.suggestions.first.phraseEnglish, 'Warm water.');
      expect(result.suggestions.first.body, contains('先回到洗澡时间里最熟悉的一句'));
    });

    test('相同上下文多次派生保持 deterministic 顺序与内容', () {
      const context = LocalMentorSuggestionContext(
        stageId: 'warm_routines',
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
        starterPhraseId: 'bath_time_warm_water',
        activityTitle: '洗澡时间',
        coachTip: '先让动作和短句贴在一起。',
        phrases: <LocalMentorPracticePhraseContext>[
          LocalMentorPracticePhraseContext(
            phraseId: 'bath_time_warm_water',
            english: 'Warm water.',
            chinese: '温温的水。',
            step: 1,
          ),
        ],
      );

      final first = service.derive(context);
      final second = service.derive(context);

      expect(
        first.suggestions
            .map((suggestion) => suggestion.toVisibleMap())
            .toList(),
        second.suggestions
            .map((suggestion) => suggestion.toVisibleMap())
            .toList(),
      );
      expect(first.redactedContextSummary, second.redactedContextSummary);
    });
  });
}
