import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/mentor/data/local/mentor_fact_event_entity.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/interaction_event_entity.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';

void main() {
  group('generated code canary', () {
    test('AccountSession copyWith preserves validated session behavior', () {
      final session = AccountSession.validated(
        accountId: 'account_1',
        sessionId: 'session_1',
        maskedPhoneNumber: '138****0000',
        createdAt: DateTime.utc(2026, 5, 19, 8),
      );

      final updated = session.copyWith(
        accessToken: 'access_token',
        refreshToken: 'refresh_token',
        accessTokenExpiresAt: DateTime.utc(2026, 5, 19, 9),
        refreshTokenExpiresAt: DateTime.utc(2026, 5, 20, 8),
      );

      expect(updated.accountId, session.accountId);
      expect(updated.hasJwtTokens, isTrue);
      expect(updated.requireAccessToken, 'access_token');
      expect(session.hasJwtTokens, isFalse);
    });

    test('ShareLinkDraft copyWith keeps public payload behavior', () {
      const draft = ShareLinkDraft(
        source: ShareLinkSource.latestImpact,
        headline: '今天有一个新尝试',
        storyText: '宝宝跟着节奏模仿了一次。',
        phraseText: 'hello',
        spaceId: 'home',
        activityId: 'song_time',
      );

      final updated = draft.copyWith(phraseText: 'hello again');

      expect(updated.source, draft.source);
      expect(updated.hasPublicPayload, isTrue);
      expect(updated.toCreatePayload()['source'], 'latest_impact');
      expect(
        updated.buildShareMessage('https://share.example.com/a'),
        contains('hello again'),
      );
      expect(draft.phraseText, 'hello');
    });

    test('LocalMentorSuggestion copyWith keeps visible maps stable', () {
      final suggestion = LocalMentorSuggestion.validated(
        suggestionId: 'suggestion_1',
        origin: LocalMentorSuggestionOrigin.safeFallback,
        title: '先从一个简单互动开始',
        body: '宝宝今天可能需要更短的提示。',
        phraseEnglish: 'hello',
        reasonCode: 'offline',
        redactedContextSummary: 'recent practice available',
      );

      final updated = suggestion.copyWith(title: '换一个轻量建议');

      expect(updated.suggestionId, suggestion.suggestionId);
      expect(updated.isSafeFallback, isTrue);
      expect(updated.toVisibleMap()['origin'], 'safe_fallback');
      expect(
        updated.toRedactedContextMap()['redactedContextSummary'],
        'recent practice available',
      );
      expect(suggestion.title, '先从一个简单互动开始');
    });

    test('PracticePhrase copyWith keeps audio asset normalization stable', () {
      const phrase = PracticePhrase(
        spaceId: 'home',
        activityId: 'song_time',
        phraseId: 'hello_wave',
        step: 1,
        english: 'Hello',
        chinese: '你好',
        pronunciation: 'nee how',
        difficulty: 'easy',
        audioAsset: 'assets/audio/phrases/hello_wave.mp3',
      );

      final updated = phrase.copyWith(
        step: 2,
        audioAsset: 'audio/phrases/hello_wave.mp3',
      );

      expect(updated.spaceId, phrase.spaceId);
      expect(updated.step, 2);
      expect(updated.audioPlayerAsset, 'audio/phrases/hello_wave.mp3');
      expect(phrase.step, 1);
      expect(phrase.audioPlayerAsset, 'audio/phrases/hello_wave.mp3');
    });

    test('PracticeContinuitySnapshot copyWith keeps derived state stable', () {
      final activity = PracticeCatalogActivitySummary(
        spaceId: 'home',
        spaceTitle: '家里',
        activityId: 'song_time',
        title: '唱一首短歌',
        summary: '用节奏带出一个词。',
        sceneTag: 'song',
        coachTip: '放慢一点。',
        totalPhraseCount: 3,
        completedPhraseCount: 1,
        completedPhraseIds: const ['hello_wave'],
        nextPhraseId: 'clap_hands',
        nextPhraseEnglish: 'Clap hands',
        totalEvents: 2,
        skippedUnknownPhraseCount: 0,
        skippedMalformedEventCount: 0,
      );
      final catalog = PracticeActivityCatalog(
        installationId: 'install_canary',
        spaces: const <PracticeCatalogSpaceSummary>[],
        activities: [activity],
        totalStoredEvents: 2,
        validEvents: 2,
        knownEvents: 2,
        skippedMalformedEvents: 0,
        skippedUnknownContentEvents: 0,
      );
      final warnedActivity = activity.copyWith(
        warningMessage: 'partial projection',
      );
      final warnedCatalog = catalog.copyWith(
        activities: [warnedActivity],
        catalogWarning: 'catalog warning',
      );
      final recommendation = PracticeContinuityRecommendation(
        spaceId: activity.spaceId,
        activityId: activity.activityId,
        activityTitle: activity.title,
        reason: PracticeContinuityReason.nextIncomplete,
        reasonLabel: PracticeContinuityReason.nextIncomplete.label,
        fallbackReason: 'catalog gap',
      );
      final snapshot = PracticeContinuitySnapshot(
        catalog: catalog,
        recommendedActivity: activity,
        recentActivity: null,
        nextIncompleteActivity: activity,
        starterActivity: activity,
        recommendation: recommendation,
        cadence: const PracticeContinuityCadenceSummary(
          totalKnownEvents: 2,
          startedActivityCount: 1,
          lastEventTime: null,
          headline: '今天已经开始',
          detail: '继续刚才的节奏。',
        ),
        warningMessage: 'catalog recovered',
      );

      final updated = snapshot.copyWith(warningMessage: null);

      expect(
        catalog.findActivity(spaceId: 'home', activityId: 'song_time'),
        activity,
      );
      expect(catalog.startedActivityCount, 1);
      expect(warnedActivity.hasRecoverableIssue, isTrue);
      expect(warnedCatalog.hasIssues, isTrue);
      expect(snapshot.hasWarning, isTrue);
      expect(updated.hasWarning, isFalse);
      expect(updated.fallbackReason, 'catalog gap');
      expect(updated.cadence.isEmpty, isFalse);
      expect(updated.recommendation.reasonLabel, '接上未完成 activity');
    });

    test('GardenGrowthSnapshot copyWith keeps projection getters stable', () {
      final flower = GardenFlowerSnapshot(
        spaceId: 'home',
        activityId: 'song_time',
        title: '唱一小段',
        sceneTag: 'music',
        summary: '短歌互动',
        stage: GardenFlowerStage.sprout,
        totalEvents: 1,
        completedPhraseCount: 1,
        totalPhraseCount: 3,
        completedPhraseIds: const ['hello_wave'],
        careNote: '继续轻声重复',
        lastPracticedAt: DateTime.utc(2026, 5, 19, 8),
      );
      final patch = GardenPatchSnapshot(
        spaceId: 'home',
        title: '居家花圃',
        description: '日常互动',
        stage: GardenPatchStage.tended,
        totalKnownEvents: 1,
        startedActivityCount: 1,
        completedActivityCount: 0,
        totalActivityCount: 1,
        activities: [flower],
        careNote: '花圃刚被照料',
        lastPracticedAt: DateTime.utc(2026, 5, 19, 8),
      );
      const milestone = GrowthMilestoneSnapshot(
        id: 'first_phrase',
        title: '第一次开口',
        body: '宝宝跟读了一句。',
        sortOrder: 1,
      );
      final impact = LatestPracticeImpact(
        eventKey: 'install_canary:practice_evt_1',
        occurredAt: DateTime.utc(2026, 5, 19, 8),
        spaceId: 'home',
        spaceTitle: '居家花圃',
        activityId: 'song_time',
        activityTitle: '唱一小段',
        phraseId: 'hello_wave',
        phraseTitle: 'Hello',
        reactionType: BabyReactionType.imitated,
        previousPatchStage: GardenPatchStage.quiet,
        currentPatchStage: GardenPatchStage.tended,
        previousFlowerStage: GardenFlowerStage.seed,
        currentFlowerStage: GardenFlowerStage.sprout,
        headline: '花圃醒来了',
        detail: '第一句已经落下。',
      );
      final snapshot = GardenGrowthSnapshot(
        installationId: 'install_canary',
        spaces: [patch],
        diaryEntries: [
          GrowthDiaryEntry(
            entryId: 'entry_1',
            kind: GrowthDiaryEntryKind.practice,
            occurredAt: DateTime.utc(2026, 5, 19, 8),
            title: '完成一次互动',
            body: '唱了一小段。',
            spaceId: 'home',
            activityId: 'song_time',
          ),
        ],
        milestones: [milestone],
        latestImpact: impact,
        totalStoredEvents: 1,
        validEvents: 1,
        knownEvents: 1,
        skippedMalformedEvents: 0,
        skippedUnknownContentEvents: 0,
      );

      final updated = snapshot.copyWith(projectionWarning: 'partial garden');
      final achieved = milestone.copyWith(
        achievedAt: DateTime.utc(2026, 5, 19, 8),
      );

      expect(snapshot.primarySpace, patch);
      expect(snapshot.primaryActivity, flower);
      expect(snapshot.isEmpty, isFalse);
      expect(updated.hasIssues, isTrue);
      expect(flower.isStarted, isTrue);
      expect(flower.isCompleted, isFalse);
      expect(patch.isStarted, isTrue);
      expect(achieved.isAchieved, isTrue);
      expect(impact.changedAnyStage, isTrue);
    });

    test('OnboardingSnapshot copyWith keeps wire mapping stable', () {
      final completedAt = DateTime.utc(2026, 5, 19, 8);
      final birthDate = DateTime.utc(2025, 8, 19);
      final snapshot = OnboardingSnapshot(
        childDisplayName: '小雨',
        ageBucket: OnboardingAgeBucket.sixToTwelve,
        approxMonths: 9,
        currentStage: 'sound_turn_taking',
        starterSpaceId: 'home',
        starterActivityId: 'song_time',
        starterPhraseId: 'clap_hands',
        consentState: OnboardingConsentState.localOnly,
        birthDate: birthDate,
        completedAt: completedAt,
      );

      final updated = snapshot.copyWith(starterPhraseId: 'hello_wave');
      final json = updated.toJsonMap();
      final decoded = OnboardingSnapshot.fromJsonValidated(json);

      expect(snapshot.isCompleted, isTrue);
      expect(updated.isCompleted, isTrue);
      expect(snapshot.starterPhraseId, 'clap_hands');
      expect(updated.starterPhraseId, 'hello_wave');
      expect(updated.ageBucket.wireValue, '6-12');
      expect(json['ageBucket'], '6-12');
      expect(json['consentState'], 'local_only');
      expect(decoded, updated);
    });

    test('Freezed output under lib/generated keeps copyWith behavior', () {
      final invite = HouseholdInviteLink(
        householdId: 'household_1',
        token: 'invite_token_1234',
        inviteUrl: 'https://invite.example.com/invite/invite_token_1234',
        role: HouseholdRole.caregiver,
        source: 'household_settings',
        expiresAt: DateTime.utc(2126, 4, 19, 12),
      );

      final updated = invite.copyWith(role: HouseholdRole.primaryCaregiver);

      expect(updated.householdId, invite.householdId);
      expect(updated.role, HouseholdRole.primaryCaregiver);
      expect(invite.role, HouseholdRole.caregiver);
      expect(invite.isExpired, isFalse);
    });

    test(
      'Isar output under lib/generated keeps schema and entity behavior',
      () {
        final payload = MentorFactEvent.validated(
          localEventId: 'mentor_evt_1',
          installationId: 'install_canary',
          eventType: MentorFactType.suggestionServed,
          phase: 'local_suggestion_ready',
          createdAt: DateTime.utc(2026, 4, 9, 8),
          visibleStatus: 'offline',
          contextFallbackUsed: true,
        );
        final updated = payload.copyWith(visibleDetail: '短提示已准备');

        final entity = MentorFactEventEntity.fromPayload(payload);

        expect(updated.eventKey, payload.eventKey);
        expect(updated.toVisibleMetadataMap()['visibleDetail'], '短提示已准备');
        expect(payload.visibleDetail, isNull);
        expect(MentorFactEventEntitySchema.name, r'MentorFactEventEntity');
        expect(entity.eventKey, 'install_canary:mentor_evt_1');
        expect(entity.eventType, 'suggestion_served');
        expect(entity.contextFallbackUsed, isTrue);
        expect(entity.toPersistedDiagnosticsMap()['visibleStatus'], 'offline');
      },
    );

    test(
      'Practice Isar output keeps schema and interaction entity behavior',
      () {
        final payload = InteractionEventPayload.validated(
          localEventId: 'practice_evt_1',
          installationId: 'install_canary',
          spaceId: 'space_home',
          activityId: 'activity_song',
          phraseId: 'phrase_hello',
          reactionType: BabyReactionType.imitated,
          clientTimestamp: DateTime.utc(2026, 5, 19, 8),
          syncState: InteractionSyncState.failed,
          lastSyncPhase: 'upload_attempt',
          lastSyncError: 'timeout',
          lastSyncAt: DateTime.utc(2026, 5, 19, 8, 1),
        );
        final updated = payload.copyWith(
          syncState: InteractionSyncState.synced,
        );
        final uploadRecord = payload.uploadRecord.copyWith(
          reactionType: BabyReactionType.calm,
        );

        final entity = InteractionEventEntity.fromPayload(payload);

        expect(updated.eventKey, payload.eventKey);
        expect(updated.toSyncMetadataMap()['syncState'], 'synced');
        expect(payload.syncState, InteractionSyncState.failed);
        expect(uploadRecord.toJsonMap()['reactionType'], 'calm');
        expect(InteractionEventEntitySchema.name, r'InteractionEventEntity');
        expect(entity.eventKey, 'install_canary:practice_evt_1');
        expect(entity.reactionType, 'imitated');
        expect(entity.toPersistedFactMap()['phraseId'], 'phrase_hello');
        expect(
          entity.toPersistedSyncMetadataMap()['lastSyncPhase'],
          'upload_attempt',
        );
      },
    );
  });
}
