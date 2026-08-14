import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/full_chain_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh install proves V4 onboarding and a durable Today Care Turn',
    (tester) async {
      final harness = await FullChainTestHarness.create();
      addTearDown(() async {
        await harness.disposeMountedApp(tester);
        await harness.dispose();
      });

      await harness.pumpApp(tester);
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('care-entry-grid')),
        reason: 'fresh install V4 care-entry grid',
      );
      expect(find.byKey(const Key('boot-route-onboarding')), findsOneWidget);

      await harness.completeOnboarding(tester);
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('home-today-care-node-card')),
        reason: 'V4 Today Care Path',
      );

      await harness.completeStarterPractice(tester);
      final pending = await harness.inspectSyncQueue();
      expect(pending.summary.pendingCount, 1);
      expect(pending.pendingUploads, hasLength(1));

      expect(
        find.byKey(const Key('home-today-care-node-card')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'malformed completed snapshot stays on the boot failure surface',
    (tester) async {
      final harness = await FullChainTestHarness.create();
      addTearDown(() async {
        await harness.disposeMountedApp(tester);
        await harness.dispose();
      });

      await harness.pumpApp(
        tester,
        completedSnapshotLoader: () async {
          throw const FormatException('malformed onboarding snapshot');
        },
      );
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('boot-route-gate-failed')),
        timeout: const Duration(seconds: 12),
        reason: 'boot route gate failure',
      );

      expect(find.byKey(const Key('boot-route-gate-failed')), findsOneWidget);
      expect(find.byKey(const Key('boot-route-shell')), findsNothing);
      expect(find.textContaining('本地档案读取失败'), findsOneWidget);
    },
  );
}
