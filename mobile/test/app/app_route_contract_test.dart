import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

void main() {
  group('AppRouteNames', () {
    test('REFACTOR-008: canonical paths stay stable', () {
      expect(AppRouteNames.shell, '/');
      expect(AppRouteNames.home, AppRouteNames.shell);
      expect(AppRouteNames.onboarding, '/onboarding');
      expect(AppRouteNames.practice, '/practice');
      expect(AppRouteNames.account, '/account');
      expect(AppRouteNames.meSettings, '/me/settings');
      expect(AppRouteNames.meGrowth, '/me/growth');
      expect(AppRouteNames.canonicalPaths, <String>{
        AppRouteNames.shell,
        AppRouteNames.onboarding,
        AppRouteNames.practice,
        AppRouteNames.account,
        AppRouteNames.meSettings,
        AppRouteNames.meGrowth,
        AppRouteNames.onboardingName,
        AppRouteNames.onboardingScene,
        AppRouteNames.onboardingPractice,
        AppRouteNames.onboardingComplete,
        AppRouteNames.onboardingGardenWelcome,
      });
    });

    test(
      'REFACTOR-008: legacy named route factory uses canonical contract',
      () {
        const routeArgs = PracticeRouteArgs(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );
        final factory = AppRouter.onGenerateRoute(
          shellBuilder: (_) => const SizedBox(key: Key('shell-route')),
          onboardingBuilder: (_) =>
              const SizedBox(key: Key('onboarding-route')),
          practiceBuilder: (context, settings) {
            final routeEntry = PracticeRouteEntry.fromObject(
              settings.arguments,
            );
            expect(routeEntry.args?.scopeLabel, 'daily_care/bath_time');
            return const SizedBox(key: Key('practice-route'));
          },
        );

        final practiceRoute = factory(
          const RouteSettings(
            name: AppRouteNames.practice,
            arguments: routeArgs,
          ),
        );
        expect(practiceRoute?.settings.name, AppRouteNames.practice);
        expect(practiceRoute?.settings.arguments, routeArgs);

        final unknownRoute = factory(
          const RouteSettings(name: '/unknown-route'),
        );
        expect(unknownRoute?.settings.name, AppRouteNames.shell);
      },
    );
  });
}
