import 'package:flutter/services.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';

abstract interface class HouseholdInviteLinkActions {
  Future<void> copy(String inviteUrl);

  Future<void> share(String inviteUrl);
}

class PlatformHouseholdInviteLinkActions implements HouseholdInviteLinkActions {
  const PlatformHouseholdInviteLinkActions({
    ShareSheetLauncher shareSheetLauncher = const SharePlusSheetLauncher(),
  }) : _shareSheetLauncher = shareSheetLauncher;

  final ShareSheetLauncher _shareSheetLauncher;

  @override
  Future<void> copy(String inviteUrl) async {
    await Clipboard.setData(ClipboardData(text: _requireInviteUrl(inviteUrl)));
  }

  @override
  Future<void> share(String inviteUrl) {
    return _shareSheetLauncher.shareText(
      _requireInviteUrl(inviteUrl),
      subject: 'BabyTalk 照护邀请',
    );
  }

  String _requireInviteUrl(String rawUrl) {
    final inviteUrl = rawUrl.trim();
    if (inviteUrl.isEmpty) {
      throw const HouseholdInviteLinkActionException('邀请链接不可用。');
    }
    return inviteUrl;
  }
}

class HouseholdInviteLinkActionException implements Exception {
  const HouseholdInviteLinkActionException(this.message);

  final String message;
}
