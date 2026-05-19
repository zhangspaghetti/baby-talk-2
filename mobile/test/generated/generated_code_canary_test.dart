import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/mentor/data/local/mentor_fact_event_entity.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';

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
  });
}
