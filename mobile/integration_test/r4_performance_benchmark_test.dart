import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

import 'support/full_chain_test_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R4 performance baseline captures core local flows', (
    WidgetTester tester,
  ) async {
    final eventCounts = _configuredEventCounts();
    final measurements = <String, int>{};
    final activeHarnesses = <FullChainTestHarness>[];
    addTearDown(() async {
      for (final harness in activeHarnesses.reversed) {
        await harness.disposeMountedApp(tester);
        await harness.dispose();
      }
    });

    for (final eventCount in eventCounts) {
      final harness = await FullChainTestHarness.create(
        practiceDbName: 'r4_performance_$eventCount',
        installationId: 'install_r4_performance_$eventCount',
        simulatedSlowResponse: Duration.zero,
        mentorRateLimit: 10,
      );
      activeHarnesses.add(harness);

      await _measure(
        measurements,
        'seed_${eventCount}_events_ms',
        () => harness.seedPracticeEventsForBenchmark(count: eventCount),
      );
      final projectionMeasurements = await harness
          .measurePracticeProjectionForBenchmark();
      for (final entry in projectionMeasurements.entries) {
        measurements['repo_${eventCount}_${entry.key}'] = entry.value;
      }

      await _measure(
        measurements,
        'cold_start_shell_${eventCount}_events_ms',
        () async {
          await harness.pumpApp(
            tester,
            completedSnapshotLoader: () async => _completedSnapshot(),
          );
          await FullChainTestHarness.pumpUntilFound(
            tester,
            find.byKey(const Key('shell-ready')),
            timeout: const Duration(seconds: 30),
            reason: 'shell ready for $eventCount performance events',
          );
          await FullChainTestHarness.pumpUntilFound(
            tester,
            find.byKey(const Key('home-starter-seed')),
            timeout: const Duration(seconds: 45),
            reason: 'home starter seed for $eventCount performance events',
          );
        },
      );

      await _measure(
        measurements,
        'home_recent_scroll_${eventCount}_events_ms',
        () => FullChainTestHarness.scrollHomeTo(
          tester,
          eventCount == 0
              ? find.byKey(const Key('recent-result-empty'))
              : find.byKey(const Key('recent-result-summary')),
          reason: 'home recent result for $eventCount performance events',
        ),
      );

      if (eventCount == eventCounts.first) {
        await _measurePracticeFlow(tester, measurements, harness);
        await _measureGrowthFirstEnter(tester, measurements, harness);
        await _measureMentorPanelOpen(tester, measurements);
      }

      await harness.disposeMountedApp(tester);
      await harness.dispose();
      activeHarnesses.remove(harness);
    }

    binding.reportData = <String, Object?>{
      'r4_performance_profile': 'local_windows_integration_baseline',
      'event_counts': eventCounts,
      'measurements_ms': measurements,
      'full_profile_command':
          'flutter test integration_test/r4_performance_benchmark_test.dart '
          '--dart-define=R4_PERF_EVENT_COUNTS=0,100,1000,10000',
    };
    for (final entry in measurements.entries) {
      debugPrint('[R4_PERF_SUMMARY] ${entry.key}=${entry.value}');
    }
  });
}

Future<void> _measurePracticeFlow(
  WidgetTester tester,
  Map<String, int> measurements,
  FullChainTestHarness harness,
) async {
  await FullChainTestHarness.scrollHomeTo(
    tester,
    find.byKey(const Key('home-start-practice')),
    reason: 'home start practice',
  );
  await _measure(measurements, 'practice_open_ms', () async {
    await tester.tap(find.byKey(const Key('home-start-practice')));
    await tester.pump();
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      timeout: const Duration(seconds: 12),
      reason: 'first practice phrase',
    );
  });

  await _measure(measurements, 'practice_first_tap_to_next_ms', () async {
    final firstReaction = find.byKey(
      const Key('reaction-bath_time_warm_water-cooperating'),
    );
    await FullChainTestHarness.pumpUntilFound(
      tester,
      firstReaction,
      reason: 'first reaction button',
    );
    await tester.ensureVisible(firstReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(firstReaction);
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
      timeout: const Duration(seconds: 12),
      reason: 'second practice phrase',
    );
  });

  final secondReaction = find.byKey(
    const Key('reaction-bath_time_splash_splash-no_response'),
  );
  await FullChainTestHarness.pumpUntilFound(
    tester,
    secondReaction,
    reason: 'second reaction button',
  );
  await tester.ensureVisible(secondReaction);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(secondReaction);
  await FullChainTestHarness.pumpUntilFound(
    tester,
    find.byKey(const Key('phrase-card-bath_time_all_clean')),
    timeout: const Duration(seconds: 12),
    reason: 'third practice phrase',
  );

  await _measure(measurements, 'practice_final_tap_to_home_ms', () async {
    final thirdReaction = find.byKey(
      const Key('reaction-bath_time_all_clean-cooperating'),
    );
    await FullChainTestHarness.pumpUntilFound(
      tester,
      thirdReaction,
      reason: 'third reaction button',
    );
    await tester.ensureVisible(thirdReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(thirdReaction);
    await FullChainTestHarness.scrollHomeTo(
      tester,
      find.byKey(const Key('recent-result-summary')),
      reason: 'recent result after practice',
    );
  });

  final syncInspection = await harness.inspectSyncQueue();
  measurements['practice_flow_event_count'] =
      syncInspection.summary.pendingCount;
}

Future<void> _measureGrowthFirstEnter(
  WidgetTester tester,
  Map<String, int> measurements,
  FullChainTestHarness harness,
) {
  return _measure(measurements, 'growth_first_enter_ms', () async {
    await harness.switchShellTab(
      tester,
      label: '成长',
      readyKey: const Key('shell-tab-growth-combined'),
    );
    await FullChainTestHarness.waitForGardenProjectionReady(tester);
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('garden-hero-card')),
      timeout: const Duration(seconds: 12),
      reason: 'garden hero card',
    );
  });
}

Future<void> _measureMentorPanelOpen(
  WidgetTester tester,
  Map<String, int> measurements,
) {
  return _measure(measurements, 'mentor_panel_open_ms', () async {
    final mentorFab = find.byKey(const Key('shell-mentor-fab'));
    await FullChainTestHarness.pumpUntilFound(
      tester,
      mentorFab,
      timeout: const Duration(seconds: 8),
      reason: 'mentor fab',
    );
    final fabWidget = tester.widget<FloatingActionButton>(mentorFab);
    final openPanel = fabWidget.onPressed;
    if (openPanel == null) {
      fail('Shell mentor FAB is disabled during performance baseline.');
    }
    openPanel();
    await tester.pump();
    await FullChainTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('mentor-panel-sheet')),
      timeout: const Duration(seconds: 12),
      reason: 'mentor panel sheet',
    );
  });
}

Future<void> _measure(
  Map<String, int> measurements,
  String key,
  Future<void> Function() action,
) async {
  final stopwatch = Stopwatch()..start();
  await action();
  stopwatch.stop();
  measurements[key] = stopwatch.elapsedMilliseconds;
  debugPrint('[R4_PERF] $key=${stopwatch.elapsedMilliseconds}ms');
}

List<int> _configuredEventCounts() {
  const rawValue = String.fromEnvironment(
    'R4_PERF_EVENT_COUNTS',
    defaultValue: '0,100',
  );
  final counts =
      rawValue
          .split(',')
          .map((value) => int.tryParse(value.trim()))
          .whereType<int>()
          .where((value) => value >= 0)
          .toSet()
          .toList()
        ..sort();
  return counts.isEmpty ? const <int>[0, 100] : counts;
}

OnboardingSnapshot _completedSnapshot() {
  return OnboardingSnapshot(
    childDisplayName: '米米',
    ageBucket: OnboardingAgeBucket.oneToTwo,
    approxMonths: 15,
    currentStage: 'gesture_plus_words',
    starterSpaceId: 'daily_care',
    starterActivityId: 'bath_time',
    starterPhraseId: 'bath_time_warm_water',
    consentState: OnboardingConsentState.localOnly,
    completedAt: DateTime.utc(2026, 5, 20, 8),
  );
}
