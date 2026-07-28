import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';

void main() {
  group('AccountEntryRouteContract', () {
    test('parses onboarding continuation route extra', () {
      expect(
        accountEntryOriginFromRouteExtra(
          AccountEntryOrigin.onboardingContinuation,
        ),
        AccountEntryOrigin.onboardingContinuation,
      );
    });

    test('parses custom-scene continuation route extra', () {
      expect(
        accountEntryOriginFromRouteExtra(
          AccountEntryOrigin.customSceneContinuation,
        ),
        AccountEntryOrigin.customSceneContinuation,
      );
    });

    test('defaults unknown route extras to settings', () {
      expect(
        accountEntryOriginFromRouteExtra(const <String, String>{'origin': 'x'}),
        AccountEntryOrigin.settings,
      );
      expect(
        accountEntryOriginFromRouteExtra(null),
        AccountEntryOrigin.settings,
      );
    });
  });
}
