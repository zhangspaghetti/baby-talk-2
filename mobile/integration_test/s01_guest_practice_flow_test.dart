import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest 离线练习在冷启动后仍能恢复最近一次本地结果', (WidgetTester tester) async {
    final bootState = await AppBootState.load(rootBundle);
    expect(bootState.isReady, isTrue);

    final tempDir = await Directory.systemTemp.createTemp(
      's01_guest_practice_integration_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const dbName = 's01_guest_practice';
    final firstRepository = await _openRepository(
      assetPhraseService: bootState.assetPhraseService!,
      directory: tempDir,
      dbName: dbName,
    );
    addTearDown(() async {
      await firstRepository.close();
    });

    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (_) async => firstRepository,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-restore-banner')));

    expect(find.byKey(const Key('home-restore-banner')), findsOneWidget);
    expect(find.textContaining('未找到本地记录'), findsOneWidget);
    expect(find.byKey(const Key('recent-result-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-start-practice')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
    );

    expect(
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      findsOneWidget,
    );
    final firstReaction = find.byKey(
      const Key('reaction-bath_time_warm_water-engaged'),
    );
    await _pumpUntilFound(tester, firstReaction);
    await tester.ensureVisible(firstReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(firstReaction);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
    );

    expect(
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
      findsOneWidget,
    );
    final secondReaction = find.byKey(
      const Key('reaction-bath_time_splash_splash-imitated'),
    );
    await _pumpUntilFound(tester, secondReaction);
    await tester.ensureVisible(secondReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(secondReaction);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
    );

    expect(
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
      findsOneWidget,
    );
    final thirdReaction = find.byKey(
      const Key('reaction-bath_time_all_clean-calm'),
    );
    await _pumpUntilFound(tester, thirdReaction);
    await tester.ensureVisible(thirdReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(thirdReaction);
    await _pumpUntilFound(tester, find.byKey(const Key('recent-result-summary')));

    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    await firstRepository.close();

    final secondRepository = await _openRepository(
      assetPhraseService: bootState.assetPhraseService!,
      directory: tempDir,
      dbName: dbName,
    );
    addTearDown(() async {
      await secondRepository.close();
    });

    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (_) async => secondRepository,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-restore-banner')));

    expect(find.byKey(const Key('home-restore-banner')), findsOneWidget);
    expect(find.textContaining('已从本地恢复最近一次练习结果'), findsOneWidget);
    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 8),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for expected widget.');
}

Future<PracticeRepository> _openRepository({
  required AssetPhraseService assetPhraseService,
  required Directory directory,
  required String dbName,
}) async {
  final localDataSource = await PracticeLocalDataSource.open(
    directory: directory.path,
    name: dbName,
  );
  return PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
      idGenerator: () => 'install_integration_test',
    ),
  );
}
