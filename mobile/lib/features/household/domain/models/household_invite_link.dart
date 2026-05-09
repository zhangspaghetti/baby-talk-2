import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';

part 'household_invite_link.freezed.dart';

@freezed
class HouseholdInviteLink with _$HouseholdInviteLink {
  const HouseholdInviteLink._();

  const factory HouseholdInviteLink({
    required String householdId,
    required String token,
    required String inviteUrl,
    required HouseholdRole role,
    required String source,
    required DateTime expiresAt,
  }) = _HouseholdInviteLink;

  bool get isExpired => expiresAt.isBefore(DateTime.now().toUtc());
}
