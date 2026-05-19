import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/mentor/data/local/mentor_fact_event_entity.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/practice/data/local/interaction_event_entity.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
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

        final entity = MentorFactEventEntity.fromPayload(payload);

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

        final entity = InteractionEventEntity.fromPayload(payload);

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
