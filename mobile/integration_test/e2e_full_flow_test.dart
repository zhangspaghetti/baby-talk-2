// E2E Full Flow Test — Flutter app against a REAL k8s backend.
//
// Covers ALL screens and user journeys:
//   1. Onboarding (welcome → name → age → stage-match → shell-ready)
//   2. Home screen (starter seed card, today scene card, hero card)
//   3. Practice session (3 phrases → complete → home recent result)
//   4. Shell tab navigation (Garden → Growth → Discover)
//   5. Account sign-in (phone + code → challenge/verify/consent/sync)
//   6. Home after sync (synced indicator)
//   7. Mentor FAB → mentor panel → chat response
//
// Requirements:
//   1. Real backend at BABY_TALK_API_BASE_URL (default http://localhost:8080)
//      provider-mode=dev, dev-code=246810
//   2. ADB reverse: adb -s emulator-5554 reverse tcp:8080 tcp:8080
//   3. Compiled with --dart-define=BABY_TALK_E2E=true
//
// Run via:
//   scripts\run-full-e2e.cmd   (Windows)
//   scripts/run-full-e2e.sh    (Unix/macOS)
//
// Or directly:
//   cd mobile
//   adb -s emulator-5554 reverse tcp:8080 tcp:8080
//   flutter test integration_test/e2e_full_flow_test.dart \
//     --dart-define=BABY_TALK_E2E=true \
//     --dart-define=BABY_TALK_API_BASE_URL=http://localhost:8080 \
//     -d emulator-5554 \
//     --timeout none

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:path_provider/path_provider.dart';

import 'support/e2e_test_harness.dart';

// Compile-time guard: only run when explicitly compiled for E2E.
const _isE2e = bool.fromEnvironment('BABY_TALK_E2E', defaultValue: false);

int _screenshotIndex = 0;
bool _surfaceConverted = false;

/// Captures a screenshot using [IntegrationTestWidgetsFlutterBinding.takeScreenshot]
/// and saves the PNG bytes to the app's external storage directory so it can
/// be retrieved with `adb pull` after the test run.
///
/// Path on device: `<external storage>/baby_talk_e2e/<index>_<label>.png`
Future<void> _shot(WidgetTester tester, String label) async {
  if (!_isE2e) return;
  // Let the frame settle before capturing.
  await tester.pump(const Duration(milliseconds: 300));
  try {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    // convertFlutterSurfaceToImage must be called once per test run before
    // the first takeScreenshot invocation.
    if (!_surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      _surfaceConverted = true;
      await tester.pump();
    }

    final idx = (_screenshotIndex++).toString().padLeft(3, '0');
    final name = '${idx}_$label';

    // Capture Flutter surface via the integration test binding.
    final List<int> bytes = await binding.takeScreenshot(name);

    // getApplicationDocumentsDirectory() → /data/user/0/com.babytalk.mobile/app_flutter/
    // Accessible via: adb exec-out run-as com.babytalk.mobile cat <path> > local.png
    // WHILE the app is still installed (before flutter test uninstalls it).
    final base = await getApplicationDocumentsDirectory();
    final screenshotDir = Directory('${base.path}/baby_talk_e2e');
    await screenshotDir.create(recursive: true);
    final file = File('${screenshotDir.path}/$name.png');
    await file.writeAsBytes(Uint8List.fromList(bytes));
    debugPrint('[e2e_screenshot] saved ${file.path}');
  } catch (e) {
    // Screenshot failure must never abort the test.
    debugPrint('[e2e_screenshot] failed for $label: $e');
  }
}

/// Taps a [NavigationDestination] in the bottom [NavigationBar] by index.
Future<void> _tapNavTab(WidgetTester tester, int index) async {
  final navBar = find.byType(NavigationBar);
  await E2eTestHarness.pumpUntilFound(tester, navBar, reason: 'navigation bar');
  final widget = tester.widget<NavigationBar>(navBar);
  final onDestinationSelected = widget.onDestinationSelected;
  if (onDestinationSelected == null) {
    fail('NavigationBar.onDestinationSelected is null');
  }
  onDestinationSelected(index);
  await tester.pump();
}

/// Sign in with the given phone / verification code using the on-screen fields.
///
/// Mirrors [FullChainTestHarness.signInAndSync] adapted for [E2eTestHarness].
/// Caller must already have the [account-entry-surface] visible.
Future<void> _signInOnAccountEntry(
  WidgetTester tester, {
  String phoneNumber = '13800138000',
  String verificationCode = '246810',
}) async {
  // Fill in credentials and submit.
  await tester.enterText(
    find.byKey(const Key('account-phone-field')),
    phoneNumber,
  );
  await tester.pump();
  await tester.enterText(
    find.byKey(const Key('account-code-field')),
    verificationCode,
  );
  await tester.pump();
  // Dismiss keyboard to avoid it covering the submit button.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.ensureVisible(find.byKey(const Key('account-submit-button')));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(
    find.byKey(const Key('account-submit-button')),
    warnIfMissed: false,
  );
  await tester.pump();

  // Wait for sync to complete — real backend may take a few seconds.
  await E2eTestHarness.pumpUntilFound(
    tester,
    find.byKey(const Key('account-status-signed-in-synced')),
    timeout: const Duration(seconds: 60),
    reason: 'account-status-signed-in-synced',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Full Flow (real k8s backend)', () {
    late E2eTestHarness harness;

    setUp(() async {
      harness = await E2eTestHarness.create(
        childDisplayName: '小明',
        practiceDbName: 'e2e_full_flow',
      );
    });

    tearDown(() async {
      await harness.dispose();
    });

    // -------------------------------------------------------------------------
    // Complete flow: onboarding → practice → tabs → sign-in → mentor
    // -------------------------------------------------------------------------
    testWidgets('完整流程：引导 → 练习 → 标签页 → 登录同步 → Mentor 对话', (tester) async {
      if (!_isE2e) {
        markTestSkipped(
          'Compile with --dart-define=BABY_TALK_E2E=true to enable.',
        );
        return;
      }

      // ── 1. Boot the app ──────────────────────────────────────────────────
      await harness.pumpApp(tester);
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('onboarding-start-button')),
        timeout: const Duration(seconds: 20),
        reason: 'onboarding start button visible on launch',
      );
      await _shot(tester, 'onboarding_welcome');

      // ── 2. Onboarding: enter child name ──────────────────────────────────
      await E2eTestHarness.scrollTo(
        tester,
        find.byKey(const Key('onboarding-start-button')),
      );
      await tester.tap(find.byKey(const Key('onboarding-start-button')));
      await tester.pumpAndSettle();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('onboarding-name-input')),
        reason: 'onboarding name input',
      );
      await _shot(tester, 'onboarding_name_entry');
      await E2eTestHarness.scrollTo(
        tester,
        find.byKey(const Key('onboarding-name-input')),
      );
      await tester.enterText(
        find.byKey(const Key('onboarding-name-input')),
        '小明',
      );
      await tester.pumpAndSettle();
      await E2eTestHarness.scrollTo(
        tester,
        find.byKey(const Key('onboarding-name-continue')),
      );
      await tester.tap(find.byKey(const Key('onboarding-name-continue')));
      await tester.pumpAndSettle();

      // ── 3. Onboarding: select age bucket ─────────────────────────────────
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('onboarding-age-grid')),
        reason: 'onboarding age grid',
      );
      await _shot(tester, 'onboarding_age_selection');
      final ageCard = find.byKey(const Key('onboarding-age-card-12-18'));
      await E2eTestHarness.scrollTo(tester, ageCard);
      await tester.tap(ageCard);
      await tester.pumpAndSettle();
      await E2eTestHarness.scrollTo(
        tester,
        find.byKey(const Key('onboarding-age-continue')),
      );
      await tester.tap(find.byKey(const Key('onboarding-age-continue')));
      await tester.pumpAndSettle();

      // ── 4. Onboarding: stage match (real API call) ────────────────────────
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('onboarding-stage-match-card')),
        timeout: const Duration(seconds: 30),
        reason: 'onboarding stage match card (real backend)',
      );
      await _shot(tester, 'onboarding_stage_match');
      await E2eTestHarness.scrollTo(
        tester,
        find.byKey(const Key('onboarding-first-phrase-said')),
      );
      await tester.tap(find.byKey(const Key('onboarding-first-phrase-said')));
      await tester.pumpAndSettle();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('onboarding-first-seed-recorded')),
        timeout: const Duration(seconds: 20),
        reason: 'first phrase recorded banner (real backend)',
      );
      await E2eTestHarness.scrollTo(
        tester,
        find.byKey(const Key('onboarding-submit-button')),
      );
      await tester.tap(find.byKey(const Key('onboarding-submit-button')));
      await tester.pumpAndSettle();

      // ── 5. Shell ready / Home screen ─────────────────────────────────────
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('shell-ready')),
        timeout: const Duration(seconds: 20),
        reason: 'shell ready after onboarding',
      );
      await _shot(tester, 'home_shell_ready');
      expect(
        find.byKey(const Key('shell-ready')),
        findsOneWidget,
        reason: 'shell-ready widget in tree',
      );

      // ── 6. Wait for starter seed on home screen ───────────────────────────
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('home-starter-seed')),
        timeout: const Duration(seconds: 45),
        step: const Duration(milliseconds: 300),
        reason: 'home starter seed',
      );
      await _shot(tester, 'home_starter_seed');
      expect(
        find.byKey(const Key('home-starter-seed')),
        findsOneWidget,
        reason: 'starter seed card shown',
      );

      // ── 7. Start practice session ─────────────────────────────────────────
      final homeScrollable = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('home-start-practice')),
        180,
        scrollable: homeScrollable,
      );
      await tester.tap(find.byKey(const Key('home-start-practice')));
      await tester.pumpAndSettle();

      // ── 8. Practice: phrase 1 ─────────────────────────────────────────────
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('phrase-card-bath_time_warm_water')),
        reason: 'phrase 1',
      );
      await _shot(tester, 'practice_phrase_1');
      final r1 = find.byKey(
        const Key('reaction-bath_time_warm_water-cooperating'),
      );
      await E2eTestHarness.scrollTo(tester, r1);
      await tester.tap(r1);

      // ── 9. Practice: phrase 2 ─────────────────────────────────────────────
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('phrase-card-bath_time_splash_splash')),
        reason: 'phrase 2',
      );
      await _shot(tester, 'practice_phrase_2');
      final r2 = find.byKey(
        const Key('reaction-bath_time_splash_splash-no_response'),
      );
      await E2eTestHarness.pumpUntilFound(tester, r2, reason: 'reaction 2');
      await tester.ensureVisible(r2);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(r2);

      // ── 10. Practice: phrase 3 ────────────────────────────────────────────
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('phrase-card-bath_time_all_clean')),
        reason: 'phrase 3',
      );
      await _shot(tester, 'practice_phrase_3');
      final r3 = find.byKey(
        const Key('reaction-bath_time_all_clean-cooperating'),
      );
      await E2eTestHarness.pumpUntilFound(tester, r3, reason: 'reaction 3');
      await tester.ensureVisible(r3);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(r3);

      // Wait for practice session to save and return to home.
      await tester.pump(const Duration(milliseconds: 3000));

      // Scroll home list back to top then reveal recent result.
      await tester.drag(homeScrollable, const Offset(0, 5000));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('home-local-only-banner')),
        -300,
        scrollable: homeScrollable,
      );
      await tester.pump();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('recent-result-summary')),
        timeout: const Duration(seconds: 60),
        reason: 'recent result summary',
      );
      await _shot(tester, 'home_after_practice');
      expect(
        find.byKey(const Key('recent-result-summary')),
        findsOneWidget,
        reason: 'recent result card visible',
      );

      // ── 11. Navigate to Growth tab ────────────────────────────────────────
      await _tapNavTab(tester, 1); // 成长 is the only secondary shell tab
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('shell-tab-growth-combined')),
        timeout: const Duration(seconds: 20),
        reason: 'growth combined tab loaded',
      );
      await _shot(tester, 'tab_growth_combined');
      expect(
        find.byKey(const Key('shell-tab-growth-combined')),
        findsOneWidget,
        reason: 'growth combined tab key present',
      );

      final growthToggle = find
          .descendant(
            of: find.byKey(const Key('growth-combined-segmented-control')),
            matching: find.byType(GestureDetector),
          )
          .at(1);
      await E2eTestHarness.pumpUntilFound(
        tester,
        growthToggle,
        reason: 'growth segment toggle',
      );
      await tester.tap(growthToggle);
      await tester.pumpAndSettle();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('growth-combined-latest-impact')),
        timeout: const Duration(seconds: 15),
        reason: 'growth combined content loaded',
      );
      await _shot(tester, 'tab_growth');
      expect(
        find.byKey(const Key('growth-combined-latest-impact')),
        findsOneWidget,
        reason: 'growth combined content key present',
      );

      // ── 12. Open Discover overlay from the shell action ───────────────────
      await tester.tap(find.byKey(const Key('shell-discover-action')));
      await tester.pumpAndSettle();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('shell-tab-discover')),
        timeout: const Duration(seconds: 15),
        reason: 'discover overlay loaded',
      );
      await _shot(tester, 'tab_discover');
      expect(
        find.byKey(const Key('shell-tab-discover')),
        findsOneWidget,
        reason: 'discover overlay key present',
      );

      final NavigatorState discoverNav = tester.state(
        find.byType(Navigator).last,
      );
      discoverNav.pop();
      await tester.pumpAndSettle();

      // ── 13. Navigate back to Home, then Mentor (before sign-in) ──────────
      await _tapNavTab(tester, 0); // 首页 is index 0
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('shell-ready')),
        timeout: const Duration(seconds: 10),
        reason: 'home tab active after nav',
      );
      await _shot(tester, 'home_before_mentor');

      // ── 15. Open Mentor panel (dev-mode — no sign-in required) ────────────
      final mentorFab = find.byKey(const Key('shell-mentor-fab'));
      await E2eTestHarness.pumpUntilFound(
        tester,
        mentorFab,
        timeout: const Duration(seconds: 8),
        reason: 'mentor FAB',
      );
      final fabWidget = tester.widget<FloatingActionButton>(mentorFab);
      final onPressed = fabWidget.onPressed;
      if (onPressed == null) {
        fail('Mentor FAB is disabled. Practice must be completed first.');
      }
      onPressed();
      await tester.pump();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('mentor-panel-sheet')),
        reason: 'mentor panel sheet',
      );
      await _shot(tester, 'mentor_panel_overview');

      // ── 16. Switch to chat tab ────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('mentor-tab-chat-button')));
      await tester.pumpAndSettle();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('mentor-chat-input')),
        timeout: const Duration(seconds: 15),
        reason: 'mentor chat input',
      );
      await _shot(tester, 'mentor_chat_input');

      // ── 17. Submit chat message ───────────────────────────────────────────
      await tester.enterText(
        find.byKey(const Key('mentor-chat-input')),
        '宝宝哭了怎么回应',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('mentor-chat-submit-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mentor-chat-submit-button')));
      await tester.pump();

      await E2eTestHarness.pumpUntil(
        tester,
        () {
          final hasResponse = find
              .byKey(const Key('mentor-chat-response-card'))
              .evaluate()
              .isNotEmpty;
          final hasBanner = find
              .byKey(const Key('mentor-chat-banner'))
              .evaluate()
              .isNotEmpty;
          final isLoading = find
              .byKey(const Key('mentor-chat-loading-bar'))
              .evaluate()
              .isNotEmpty;
          return hasResponse || hasBanner || !isLoading;
        },
        timeout: const Duration(seconds: 120),
        step: const Duration(milliseconds: 200),
        reason: 'mentor chat completion surface',
      );

      final hasMentorResponse = find
          .byKey(const Key('mentor-chat-response-card'))
          .evaluate()
          .isNotEmpty;
      if (hasMentorResponse) {
        await _shot(tester, 'mentor_chat_response');
        expect(
          find.byKey(const Key('mentor-chat-response-card')),
          findsOneWidget,
          reason: 'mentor response card shown in UI',
        );
      } else {
        await _shot(tester, 'mentor_chat_error_banner');
        expect(
          find.byKey(const Key('mentor-chat-banner')),
          findsOneWidget,
          reason: 'mentor failure banner shown in UI',
        );
      }

      // ── 18. Dismiss mentor panel → back to home ───────────────────────────
      final NavigatorState mentorNav = tester.state(
        find.byType(Navigator).last,
      );
      mentorNav.pop();
      await tester.pumpAndSettle();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('shell-ready')),
        timeout: const Duration(seconds: 8),
        reason: 'shell ready after mentor dismiss',
      );
      await _shot(tester, 'home_before_login');

      // ── 19. Open drawer ───────────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
      await tester.pumpAndSettle();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('shell-account-open-entry')),
        timeout: const Duration(seconds: 8),
        reason: 'drawer with account entry',
      );
      await _shot(tester, 'drawer_open');

      // ── 20. Open account entry screen ────────────────────────────────────
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(
        find.byKey(const Key('shell-account-open-entry')),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(
        find.byKey(const Key('shell-account-open-entry')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('account-entry-surface')),
        reason: 'account entry surface',
      );
      await _shot(tester, 'account_entry_screen');

      // ── 21. Sign in and sync ──────────────────────────────────────────────
      await _signInOnAccountEntry(tester);
      await _shot(tester, 'account_signed_in_synced');
      expect(
        find.byKey(const Key('account-status-signed-in-synced')),
        findsOneWidget,
        reason: 'account status shows signed-in-synced',
      );

      // ── Done ──────────────────────────────────────────────────────────────
      debugPrint(
        '[e2e_full_flow] All steps completed. '
        'Screenshots saved to internal storage (baby_talk_e2e/) on emulator.',
      );

      // Allow 30 seconds for the host to extract screenshots via run-as before
      // flutter test uninstalls the APK:
      //   adb exec-out run-as com.babytalk.mobile \
      //     cat /data/user/0/com.babytalk.mobile/app_flutter/baby_talk_e2e/<file>.png \
      //     > docs/screenshots/mobile/<file>.png
      if (_isE2e) {
        debugPrint(
          '[e2e_full_flow] Waiting 30s for screenshot extraction via run-as...',
        );
        await Future.delayed(const Duration(seconds: 30));
        debugPrint(
          '[e2e_full_flow] Extraction window closed. Resuming cleanup.',
        );
      }
    });
  });
}
