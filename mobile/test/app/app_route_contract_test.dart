import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_go_router.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/auth_screen.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  group('AppRouteNames', () {
    test('REFACTOR-008: canonical paths stay stable', () {
      expect(AppRouteNames.shell, '/');
      expect(AppRouteNames.home, AppRouteNames.shell);
      expect(AppRouteNames.onboarding, '/onboarding');
      expect(AppRouteNames.practice, '/practice');
      expect(AppRouteNames.customScene, '/custom-scene');
      expect(AppRouteNames.account, '/account');
      expect(AppRouteNames.meSettings, '/me/settings');
      expect(AppRouteNames.meGrowth, '/me/growth');
      expect(AppRouteNames.canonicalPaths, <String>{
        AppRouteNames.shell,
        AppRouteNames.onboarding,
        AppRouteNames.practice,
        AppRouteNames.customScene,
        AppRouteNames.account,
        AppRouteNames.meSettings,
        AppRouteNames.meGrowth,
      });
      expect(AppRouteNames.legacyOnboardingPaths, <String>{
        '/onboarding/name',
        '/onboarding/scene',
        '/onboarding/practice',
        '/onboarding/complete',
        '/onboarding/garden-welcome',
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

    testWidgets(
      'legacy onboarding paths redirect to the canonical onboarding flow',
      (tester) async {
        final legacyPaths = AppRouteNames.legacyOnboardingPaths.toList();
        final router = createAppRouter(
          initialLocation: legacyPaths.first,
          onboardingBuilder: (_) =>
              const SizedBox(key: Key('onboarding-flow-route')),
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        for (final path in legacyPaths) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            AppRouteNames.onboarding,
          );
          expect(
            find.byKey(const Key('onboarding-flow-route')),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      '/account uses improved auth screen, not legacy account entry',
      (tester) async {
        final notifier = AccountNotifier(repository: _RouteAccountRepository());
        final router = createAppRouter(initialLocation: AppRouteNames.account);
        addTearDown(router.dispose);
        addTearDown(notifier.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountNotifierProvider.overrideWith((ref) => notifier),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AuthScreen), findsOneWidget);
        expect(find.byKey(const Key('account-entry-surface')), findsNothing);
        expect(find.text('获取验证码'), findsOneWidget);
      },
    );
  });
}

class _RouteAccountRepository implements AccountRepositoryContract {
  @override
  Future<AccountLocalSnapshot> loadSnapshot() async =>
      AccountLocalSnapshot.signedOut;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => AccountLocalSnapshot.signedOut;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => seedSnapshot ?? AccountLocalSnapshot.signedOut;

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async => AccountLocalSnapshot.signedOut;

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async => AccountLocalSnapshot.signedOut;

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async => AccountLocalSnapshot.signedOut;

  @override
  Future<void> close() async {}
}
