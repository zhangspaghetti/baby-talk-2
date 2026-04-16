import 'package:mobile/features/household/domain/models/household_role.dart';

class HouseholdInviteLink {
  const HouseholdInviteLink({
    required this.householdId,
    required this.token,
    required this.inviteUrl,
    required this.role,
    required this.source,
    required this.expiresAt,
  });

  final String householdId;
  final String token;
  final String inviteUrl;
  final HouseholdRole role;
  final String source;
  final DateTime expiresAt;

  bool get isExpired => expiresAt.isBefore(DateTime.now().toUtc());
}
