import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_version.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiVersion;
import 'package:mobile/features/care_entry/data/guest_onboarding_audio_api.dart'
    show defaultGuestOnboardingApiVersion;
import 'package:mobile/features/care_entry/data/guest_onboarding_conversation_api.dart'
    show defaultGuestOnboardingConversationApiVersion;
import 'package:mobile/features/household/data/services/household_api_service.dart'
    show defaultHouseholdApiVersion;
import 'package:mobile/features/share/data/services/share_api_service.dart'
    show defaultShareApiVersion;

void main() {
  test('all mobile API clients share the core 1.3.0 default', () {
    expect(defaultAppApiVersion, '1.3.0');
    expect(defaultAccountApiVersion, defaultAppApiVersion);
    expect(defaultHouseholdApiVersion, defaultAppApiVersion);
    expect(defaultShareApiVersion, defaultAppApiVersion);
    expect(defaultGuestOnboardingApiVersion, defaultAppApiVersion);
    expect(defaultGuestOnboardingConversationApiVersion, defaultAppApiVersion);
  });

  test('version clients do not retain a production 1.2.0 default', () {
    for (final path in <String>[
      'lib/features/account/data/services/account_api_service.dart',
      'lib/features/household/data/services/household_api_service.dart',
      'lib/features/share/data/services/share_api_service.dart',
      'lib/features/care_entry/data/guest_onboarding_audio_api.dart',
      'lib/features/care_entry/data/guest_onboarding_conversation_api.dart',
      'lib/core/network/api_version.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains("defaultValue: '1.2.0'")), reason: path);
      expect(source, isNot(contains('defaultValue: "1.2.0"')), reason: path);
    }
  });
}
