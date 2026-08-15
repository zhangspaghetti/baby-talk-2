import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_go_router.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/auth/presentation/screens/auth_screen.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
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

    test('onboarding Care Turn route preserves exact support identity', () {
      const args = OnboardingCareTurnRouteArgs(
        completionId: 'completion-1',
        spaceId: 'family_rhythm',
        activityId: 'bedtime',
        entryTitle: '哄睡中',
        utteranceId: 'support.bedtime.hesitant',
        english: 'Try when ready.',
        chinese: '准备好再试。',
        source: OnboardingCareTurnSource.localFallback,
      );

      final entry = PracticeRouteEntry.fromObject(args);

      expect(entry.onboardingArgs, same(args));
      expect(entry.scopeLabel, contains('support.bedtime.hesitant'));
      expect(entry.hasValidArgs, isTrue);
    });

    testWidgets('/account exposes account lifecycle controls', (tester) async {
      final notifier = AccountNotifier(repository: _RouteAccountRepository());
      final router = createAppRouter(initialLocation: AppRouteNames.account);
      addTearDown(router.dispose);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [accountNotifierProvider.overrideWith((ref) => notifier)],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AccountEntryScreen), findsOneWidget);
      expect(find.byKey(const Key('account-entry-surface')), findsOneWidget);
      expect(find.byKey(const Key('account-revoke-button')), findsOneWidget);
      expect(find.byKey(const Key('account-delete-button')), findsOneWidget);
    });

    testWidgets('direct /account logout returns to the signed-out shell', (
      tester,
    ) async {
      final repository = _RouteAccountRepository(
        snapshot: AccountLocalSnapshot(
          consentState: AccountConsentState.acceptedPendingSync,
          session: AccountSession(
            sessionId: 'synthetic_session',
            accountId: 'synthetic_account',
            maskedPhoneNumber: '***',
            createdAt: DateTime.utc(2026, 8, 12, 1),
          ),
        ),
      );
      final notifier = AccountNotifier(repository: repository);
      await notifier.initialize();
      final router = createAppRouter(
        initialLocation: AppRouteNames.account,
        accountBuilder: (_) => const AuthScreen(),
        shellBuilder: (_) => const SizedBox(key: Key('signed-out-shell')),
      );
      addTearDown(router.dispose);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [accountNotifierProvider.overrideWith((ref) => notifier)],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth-logout-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth-logout-confirm-button')));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        AppRouteNames.shell,
      );
      expect(find.byKey(const Key('signed-out-shell')), findsOneWidget);
    });
  });
}

class _RouteAccountRepository implements AccountRepositoryContract {
  _RouteAccountRepository({AccountLocalSnapshot? snapshot})
    : _snapshot = snapshot ?? AccountLocalSnapshot.signedOut;

  AccountLocalSnapshot _snapshot;

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => _snapshot;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => seedSnapshot ?? _snapshot;

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    _snapshot = AccountLocalSnapshot.signedOut;
    return _snapshot;
  }

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
