// E2E smoke test — Flutter app against a REAL Spring Boot backend.
//
// Requires:
//   1. Backend running at BABY_TALK_API_BASE_URL (default: http://127.0.0.1:8080)
//      with provider-mode=dev (fast deterministic responses, no real LLM/SMS).
//   2. Compiled with --dart-define=BABY_TALK_E2E=true to activate the guard.
//
// Run with:
//   cd mobile
//   flutter test integration_test/e2e_smoke_test.dart \
//     --dart-define=BABY_TALK_API_BASE_URL=http://localhost:8080 \
//     --dart-define=BABY_TALK_E2E=true
//
// Or via the repo helper script:
//   scripts/run-mobile-e2e.sh   (Unix/macOS)
//   scripts\run-mobile-e2e.cmd  (Windows)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_test_harness.dart';

// Compile-time guard: only run when explicitly compiled for E2E.
const _isE2e = bool.fromEnvironment('BABY_TALK_E2E', defaultValue: false);

void main() {
  group('E2E smoke', () {
    late E2eTestHarness harness;

    setUp(() async {
      harness = await E2eTestHarness.create();
    });

    tearDown(() async {
      await harness.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 1: onboarding → shell ready
    // Verifies: bootstrap + version-negotiation + stage-match API round-trip.
    // -------------------------------------------------------------------------
    testWidgets(
      'onboarding completes against real backend and shell is ready',
      (tester) async {
        if (!_isE2e) {
          markTestSkipped(
            'Skipped: compile with --dart-define=BABY_TALK_E2E=true to enable.',
          );
          return;
        }

        await harness.pumpApp(tester);
        await harness.completeOnboarding(tester);

        // Shell-ready key is set after the onboarding → shell transition.
        await E2eTestHarness.pumpUntilFound(
          tester,
          find.byKey(const Key('shell-ready')),
          timeout: const Duration(seconds: 20),
          reason: 'shell ready (onboarding → real backend)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Test 2: mentor chat → dev-mode response returned and shown in UI
    // Verifies: event sync + mentor chat API round-trip end-to-end.
    // -------------------------------------------------------------------------
    testWidgets('mentor chat returns dev-mode response from real backend', (
      tester,
    ) async {
      if (!_isE2e) {
        markTestSkipped(
          'Skipped: compile with --dart-define=BABY_TALK_E2E=true to enable.',
        );
        return;
      }

      await harness.pumpApp(tester);
      await harness.completeOnboarding(tester);
      await harness.completeStarterPractice(tester);

      final notifier = await harness.submitMentorPrompt(
        tester,
        prompt: '宝宝哭了怎么回应',
      );

      // Dev-mode backend always returns a non-empty response.
      expect(
        notifier.chatResponsePhase,
        equals('response_delivered'),
        reason: 'Backend should return phase=response_delivered',
      );
      expect(
        notifier.chatResponseText,
        isNotNull,
        reason: 'Dev-mode response text should be non-null',
      );
      expect(
        notifier.chatResponseText,
        isNotEmpty,
        reason: 'Dev-mode response text should be non-empty',
      );

      // Verify the response card is visible in the UI.
      await E2eTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('mentor-chat-response-card')),
        timeout: const Duration(seconds: 10),
        reason: 'mentor chat response card shown in UI',
      );
    });
  });
}
