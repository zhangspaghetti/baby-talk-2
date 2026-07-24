import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_flow_notifier.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../practice/practice_repository_characterization_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ensurePracticeRepositoryHarnessIsarInitialized);

  late _OnboardingFlowScreenHarness harness;

  setUp(() async {
    harness = await _OnboardingFlowScreenHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets(
    'selection cards do not advance until the bottom CTA is pressed',
    (tester) async {
      await harness.pumpAtStep(tester, OnboardingFlowStep.age);

      await tester.tap(find.byKey(const Key('onboarding-age-1-2')));
      await tester.pump();

      expect(harness.notifier.step, OnboardingFlowStep.age);

      await tester.tap(find.byKey(const Key('onboarding-primary-action')));
      await tester.pumpAndSettle();

      expect(harness.notifier.step, OnboardingFlowStep.scenePreferences);
    },
  );

  testWidgets('care turn uses formal reaction keys and reaches a real trace', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);

    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();
    await tester.pump();

    expect(harness.notifier.step, OnboardingFlowStep.trace);
    expect(harness.notifier.flowSnapshot.traceEventKey, isNotEmpty);
    expect(harness.notifier.flowSnapshot.pendingLocalEventId, isNull);
  });

  testWidgets('audio failure keeps the said action enabled', (tester) async {
    harness.audioController.failNextPlay = true;
    await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);

    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('care-turn-audio-error')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('care-turn-said-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'account save returns from typed account route and enters shell',
    (tester) async {
      await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);

      await tester.tap(find.byKey(const Key('onboarding-primary-action')));
      await tester.pumpAndSettle();

      expect(harness.accountRoutePushCount, 1);

      harness.completeAccountRoute(AccountEntryResult.signedIn);
      await tester.pumpAndSettle();

      expect(harness.shellNavigationCount, 1);
    },
  );

  testWidgets('temporary local choice completes without opening account', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);

    await tester.tap(find.byKey(const Key('onboarding-secondary-action')));
    await tester.pumpAndSettle();

    expect(harness.accountRoutePushCount, 0);
    expect(harness.shellNavigationCount, 1);
  });

  testWidgets('1.3 text scale remains scrollable at 390 by 844', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await harness.pumpAtStep(
      tester,
      OnboardingFlowStep.scenePreferences,
      textScaler: const TextScaler.linear(1.3),
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-primary-action')), findsOneWidget);
  });
}

abstract interface class _OnboardingFlowScreenTestHarness {
  OnboardingFlowNotifier get notifier;
  _ControllablePracticeAudioController get audioController;
  int get accountRoutePushCount;
  int get shellNavigationCount;

  Future<void> pumpAtStep(
    WidgetTester tester,
    OnboardingFlowStep step, {
    TextScaler textScaler = TextScaler.noScaling,
  });

  void completeAccountRoute(AccountEntryResult result);
}

class _OnboardingFlowScreenHarness implements _OnboardingFlowScreenTestHarness {
  _OnboardingFlowScreenHarness._({
    required this.tempDir,
    required this.practiceHarness,
    required this.carePathNotifier,
    required this.accountNotifier,
    required this.notifier,
  });

  final Directory tempDir;
  final PracticeRepositoryCharacterizationHarness practiceHarness;
  final CarePathNotifier carePathNotifier;
  final AccountNotifier accountNotifier;
  @override
  final OnboardingFlowNotifier notifier;
  @override
  final _ControllablePracticeAudioController audioController =
      _ControllablePracticeAudioController();

  Completer<AccountEntryResult>? _accountResult;
  var _providerScopeOwnsNotifiers = false;
  int _accountRoutePushCount = 0;
  int _shellNavigationCount = 0;

  @override
  int get accountRoutePushCount => _accountRoutePushCount;
  @override
  int get shellNavigationCount => _shellNavigationCount;

  static Future<_OnboardingFlowScreenHarness> create() async {
    final tempDir = await Directory.systemTemp.createTemp('onboarding_ui_');
    final practiceHarness =
        await PracticeRepositoryCharacterizationHarness.create();
    final carePathNotifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: practiceHarness.repository,
      ),
    );
    final accountNotifier = AccountNotifier(
      repository: _SignedInAccountRepository(),
    );
    await accountNotifier.initialize();
    final onboardingRepository = OnboardingRepository(
      snapshotStore: OnboardingSnapshotStore(
        directoryResolver: () async => tempDir,
      ),
      flowStore: OnboardingFlowStore(directoryResolver: () async => tempDir),
      practiceRepository: practiceHarness.repository,
      starterSpaceId: 'daily_care',
      starterActivityId: 'bath_time',
    );
    final notifier = OnboardingFlowNotifier(
      onboardingRepository: onboardingRepository,
      practiceRepository: practiceHarness.repository,
      carePathNotifier: carePathNotifier,
      accountNotifier: accountNotifier,
      authContinuationCoordinator: AuthContinuationCoordinator(
        store: AuthContinuationStore(directoryResolver: () async => tempDir),
      ),
      clock: () => DateTime.utc(2026, 7, 24, 12),
      localEventIdGenerator: () => 'evt_onboarding_screen',
    );
    return _OnboardingFlowScreenHarness._(
      tempDir: tempDir,
      practiceHarness: practiceHarness,
      carePathNotifier: carePathNotifier,
      accountNotifier: accountNotifier,
      notifier: notifier,
    );
  }

  @override
  Future<void> pumpAtStep(
    WidgetTester tester,
    OnboardingFlowStep step, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await notifier.initialize();
    await _advanceTo(step);
    final router = GoRouter(
      initialLocation: AppRouteNames.onboarding,
      routes: <RouteBase>[
        GoRoute(
          path: AppRouteNames.onboarding,
          builder: (context, state) => OnboardingFlowScreen(
            audioControllerFactory: () => audioController,
          ),
        ),
        GoRoute(
          path: AppRouteNames.account,
          builder: (context, state) {
            _accountRoutePushCount += 1;
            final result = Completer<AccountEntryResult>();
            _accountResult = result;
            return _AccountResultRoute(result: result.future);
          },
        ),
        GoRoute(
          path: AppRouteNames.shell,
          builder: (context, state) {
            _shellNavigationCount += 1;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    markNotifiersOwnedByProviderScope();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingFlowNotifierProvider.overrideWith((ref) => notifier),
          carePathNotifierProvider.overrideWith((ref) => carePathNotifier),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> _advanceTo(OnboardingFlowStep target) async {
    if (target == OnboardingFlowStep.welcome) {
      return;
    }
    await notifier.continueFromWelcome();
    if (target == OnboardingFlowStep.age) {
      return;
    }
    await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
    await notifier.continueFromAge();
    if (target == OnboardingFlowStep.scenePreferences) {
      return;
    }
    final moment = notifier.availableMoments.first;
    await notifier.toggleScenePreference(moment.activityId);
    await notifier.continueFromScenePreferences();
    if (target == OnboardingFlowStep.supportGoal) {
      return;
    }
    await notifier.selectSupportGoal(OnboardingSupportGoal.moreNatural);
    await notifier.continueFromSupportGoal();
    if (target == OnboardingFlowStep.currentMoment) {
      return;
    }
    await notifier.selectCurrentMoment(moment);
    if (target == OnboardingFlowStep.careTurn) {
      return;
    }
    notifier.markSaid();
    await notifier.selectReaction(BabyReactionType.hesitant);
    if (target == OnboardingFlowStep.trace) {
      return;
    }
    await notifier.continueFromTrace();
  }

  @override
  void completeAccountRoute(AccountEntryResult result) {
    _accountResult!.complete(result);
  }

  void markNotifiersOwnedByProviderScope() {
    _providerScopeOwnsNotifiers = true;
  }

  Future<void> dispose() async {
    if (!_providerScopeOwnsNotifiers) {
      notifier.dispose();
      carePathNotifier.dispose();
    }
    accountNotifier.dispose();
    await audioController.dispose();
    await practiceHarness.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _AccountResultRoute extends StatefulWidget {
  const _AccountResultRoute({required this.result});

  final Future<AccountEntryResult> result;

  @override
  State<_AccountResultRoute> createState() => _AccountResultRouteState();
}

class _AccountResultRouteState extends State<_AccountResultRoute> {
  @override
  void initState() {
    super.initState();
    unawaited(_returnResult());
  }

  Future<void> _returnResult() async {
    final result = await widget.result;
    if (mounted) {
      context.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('account route')));
}

class _ControllablePracticeAudioController implements PracticeAudioController {
  final StreamController<void> _completion = StreamController<void>.broadcast();
  bool failNextPlay = false;

  @override
  Stream<void> get completionStream => _completion.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    if (failNextPlay) {
      failNextPlay = false;
      throw StateError('audio unavailable');
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _completion.close();
}

class _SignedInAccountRepository implements AccountRepositoryContract {
  AccountLocalSnapshot _snapshot = _signedInSnapshot();

  @override
  Future<void> close() async {}

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    _snapshot = revertToLocalOnly
        ? AccountLocalSnapshot.localOnly
        : AccountLocalSnapshot.signedOut;
    return _snapshot;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => seedSnapshot ?? _snapshot;

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => _snapshot;
}

AccountLocalSnapshot _signedInSnapshot() => AccountLocalSnapshot(
  consentState: AccountConsentState.acceptedPendingSync,
  session: AccountSession(
    accountId: 'acct-onboarding-screen',
    sessionId: 'session-onboarding-screen',
    maskedPhoneNumber: '138****8000',
    createdAt: DateTime.utc(2026, 7, 24, 12),
  ),
  lastSyncPhase: 'synced',
);
