import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/features/care_entry/data/guest_onboarding_audio_api.dart';
import 'package:mobile/features/care_entry/data/guest_onboarding_conversation_api.dart';
import 'package:mobile/features/care_entry/presentation/care_entry_providers.dart';

import 'support/full_chain_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'online HTTP, audio failure recovery, no reaction, and Continue preserve exact state',
    (tester) async {
      final harness = await FullChainTestHarness.create(
        practiceDbName: 'onboarding_v4_online',
      );
      final output = _RecordingGuestAudioOutput();
      harness.backend.failNextOnboardingAudio();
      addTearDown(() async {
        await harness.disposeMountedApp(tester);
        await harness.dispose();
      });

      await harness.pumpApp(
        tester,
        providerOverrides: _onboardingHttpOverrides(harness, output),
      );
      await _startSelectedEntry(tester);

      expect(find.text('Remote bedtime support.'), findsOneWidget);
      expect(harness.backend.onboardingConversationRequestCount, 1);

      await tester.tap(
        find.byKey(const Key('care-entry-first-utterance-audio')),
      );
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('care-entry-audio-message')),
        reason: 'safe audio failure fallback',
      );
      expect(output.playCount, 0);

      await tester.tap(
        find.byKey(const Key('care-entry-first-utterance-audio')),
      );
      await FullChainTestHarness.pumpUntil(
        tester,
        () => output.playCount == 1,
        reason: 'audio retry success',
      );
      expect(output.lastBytes, Uint8List.fromList(const <int>[1, 2, 3, 4]));
      expect(find.byKey(const Key('care-entry-audio-message')), findsNothing);

      await tester.tap(find.byKey(const Key('care-entry-said-action')));
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('care-entry-reaction-prompt')),
        reason: 'reaction prompt before no-reaction timer',
      );
      await tester.pump(const Duration(seconds: 4));
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('care-entry-next-support')),
        timeout: const Duration(seconds: 8),
        reason: 'remote no-reaction next support',
      );

      expect(harness.backend.lastOnboardingTurnReactionProvided, isFalse);
      expect(harness.backend.lastOnboardingTurnReaction, isNull);
      expect(find.text('Remote next support.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-entry-continue-action')));
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('care-turn-current-utterance')),
        timeout: const Duration(seconds: 12),
        reason: 'continued Care Turn',
      );
      expect(find.text('Remote next support.'), findsOneWidget);
    },
  );

  testWidgets('offline timeout stays local after late HTTP success', (
    tester,
  ) async {
    final harness = await FullChainTestHarness.create(
      practiceDbName: 'onboarding_v4_offline',
    );
    final output = _RecordingGuestAudioOutput();
    harness.backend.holdNextOnboardingConversation();
    addTearDown(() async {
      await harness.disposeMountedApp(tester);
      await harness.dispose();
    });

    await harness.pumpApp(
      tester,
      providerOverrides: _onboardingHttpOverrides(harness, output),
    );
    await _startSelectedEntry(tester);
    final localText = tester
        .widget<Text>(
          find.byKey(const Key('care-entry-first-utterance-english')),
        )
        .data;
    expect(localText, isNot('Remote bedtime support.'));

    harness.backend.releaseOnboardingConversation();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('care-entry-first-utterance-english')),
          )
          .data,
      localText,
    );
  });

  testWidgets('defer persists and explicit route re-entry resumes checkpoint', (
    tester,
  ) async {
    final harness = await FullChainTestHarness.create(
      practiceDbName: 'onboarding_v4_defer',
    );
    final output = _RecordingGuestAudioOutput();
    addTearDown(() async {
      await harness.disposeMountedApp(tester);
      await harness.dispose();
    });

    await harness.pumpApp(
      tester,
      providerOverrides: _onboardingHttpOverrides(harness, output),
    );
    await _startSelectedEntry(tester);
    await tester.tap(find.byKey(const Key('care-entry-said-action')));
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-reaction-prompt')),
      reason: 'reaction checkpoint before defer',
    );

    await tester.tap(find.byKey(const Key('care-entry-defer-action')));
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-exit-sheet')),
      reason: 'defer confirmation',
    );
    final confirmDefer = find.byKey(
      const Key('care-entry-exit-confirm-action'),
    );
    await tester.ensureVisible(confirmDefer);
    await tester.pumpAndSettle();
    await tester.tap(confirmDefer);
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('shell-ready')),
      timeout: const Duration(seconds: 12),
      reason: 'Today after defer',
    );

    final shellContext = tester.element(find.byKey(const Key('shell-ready')));
    GoRouter.of(shellContext).go(AppRouteNames.onboarding);
    await tester.pump();
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-reaction-prompt')),
      timeout: const Duration(seconds: 12),
      reason: 'explicit deferred checkpoint resume',
    );
    expect(find.text('Remote bedtime support.'), findsNothing);
    expect(harness.backend.onboardingConversationRequestCount, 1);
  });

  testWidgets('finish publishes trace and Garden handoff selects Garden', (
    tester,
  ) async {
    final harness = await FullChainTestHarness.create(
      practiceDbName: 'onboarding_v4_garden',
    );
    final output = _RecordingGuestAudioOutput();
    addTearDown(() async {
      await harness.disposeMountedApp(tester);
      await harness.dispose();
    });

    await harness.pumpApp(
      tester,
      providerOverrides: _onboardingHttpOverrides(harness, output),
    );
    await _startSelectedEntry(tester);
    await tester.tap(find.byKey(const Key('care-entry-said-action')));
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-reaction-prompt')),
      reason: 'reaction prompt before Garden handoff',
    );
    await tester.tap(find.byKey(const Key('care-entry-reaction-cooperating')));
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-next-support')),
      reason: 'next support before completion',
    );
    await FullChainTestHarness.scrollTo(
      tester,
      find.byKey(const Key('care-entry-finish-today-action')),
    );
    await tester.tap(find.byKey(const Key('care-entry-finish-today-action')));
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-garden-trace')),
      reason: 'durable Garden Trace',
    );
    await tester.tap(find.byKey(const Key('care-entry-open-garden-action')));
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('shell-tab-growth-combined')),
      timeout: const Duration(seconds: 12),
      reason: 'Garden shell destination',
    );
  });
}

Future<void> _startSelectedEntry(WidgetTester tester) async {
  try {
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-grid')),
      reason: 'V4 care-entry grid',
    );
  } on TestFailure {
    final visibleText = find
        .byType(Text)
        .evaluate()
        .map((element) => element.widget)
        .whereType<Text>()
        .map((widget) => widget.data)
        .whereType<String>()
        .take(12)
        .toList(growable: false);
    fail(
      'V4 grid missing: '
      'loading=${find.byKey(const Key('boot-loading')).evaluate().isNotEmpty}; '
      'onboarding=${find.byKey(const Key('boot-route-onboarding')).evaluate().isNotEmpty}; '
      'shell=${find.byKey(const Key('boot-route-shell')).evaluate().isNotEmpty}; '
      'failed=${find.byKey(const Key('boot-route-gate-failed')).evaluate().isNotEmpty}; '
      'text=$visibleText',
    );
  }
  await tester.tap(find.byKey(const Key('care-entry-primary-action')));
  await FullChainTestHarness.pumpUntilFound(
    tester,
    find.byKey(const Key('care-entry-first-utterance-english')),
    reason: 'remote first utterance',
  );
}

List<riverpod.Override> _onboardingHttpOverrides(
  FullChainTestHarness harness,
  GuestAudioOutput output,
) {
  final capabilities = GuestAudioCapabilityVault();
  return <riverpod.Override>[
    guestAudioCapabilityVaultProvider.overrideWithValue(capabilities),
    guestOnboardingConversationGatewayProvider.overrideWithValue(
      GuestOnboardingConversationApi(
        audioCapabilities: capabilities,
        baseUrl: harness.backend.baseUri.toString(),
      ),
    ),
    guestOnboardingAudioPlayerFactoryProvider.overrideWithValue(
      () => GuestOnboardingAudioApi(
        capabilities: capabilities,
        baseUrl: harness.backend.baseUri.toString(),
        output: output,
      ),
    ),
  ];
}

final class _RecordingGuestAudioOutput implements GuestAudioOutput {
  int playCount = 0;
  Uint8List? lastBytes;

  @override
  Future<void> playBytes(List<int> bytes, String mimeType) async {
    expect(mimeType, 'audio/mpeg');
    playCount += 1;
    lastBytes = Uint8List.fromList(bytes);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
