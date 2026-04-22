import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/shell/presentation/screens/discover_screen.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('缺失 route args 时只显示安全 fallback，不会白屏或回退默认 activity', (
    WidgetTester tester,
  ) async {
    final harness = await tester.runAsync<_RepositoryHarness>(
      _createRepositoryHarness,
    );
    addTearDown(harness!.dispose);

    await tester.pumpWidget(
      Provider<PracticeRepository>.value(
        value: harness.repository,
        child: MaterialApp(
          theme: AppTheme.build(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PracticeSessionScreen(
            routeEntry: PracticeRouteEntry.fromObject(null),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('practice-safe-fallback')), findsOneWidget);
    expect(find.textContaining('缺少或损坏 practice route 参数'), findsOneWidget);
    expect(find.byKey(const Key('activation-frame')), findsNothing);
  });

  testWidgets(
    '从 Discover activity 视图进入 feeding_time 时，practice 标题和 route scope 都对应被点击 activity',
    (tester) async {
      _setTallViewport(tester);
      final harness = await tester.runAsync<_RepositoryHarness>(
        _createRepositoryHarness,
      );
      addTearDown(harness!.dispose);

      await tester.runAsync(() async {
        await harness.repository.recordReaction(
          spaceId: 'family_rhythm',
          activityId: 'feeding_time',
          phraseId: 'feeding_time_open_wide',
          reactionType: BabyReactionType.engaged,
          clientTimestamp: DateTime.utc(2026, 4, 10, 8, 0),
          localEventId: 'evt_feeding_time_1',
        );
      });

      await tester.pumpWidget(
        _buildDiscoverPracticeApp(
          harness.repository,
          catalogLoader: () async => _discoverNavigationCatalog(),
          practiceOpener: _pushPracticeScreen,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(
          const Key('discover-route-target-family_rhythm-feeding_time'),
        ),
      );

      await _scrollDiscoverUntilVisible(
        tester,
        find.byKey(
          const Key('discover-route-target-family_rhythm-feeding_time'),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('discover-route-target-family_rhythm-feeding_time'),
        ),
      );
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.byKey(
          const Key('practice-route-scope-family_rhythm-feeding_time'),
        ),
      );

      expect(
        find.byKey(
          const Key('practice-route-scope-family_rhythm-feeding_time'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('吃饭时间')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('practice-restore-banner')), findsOneWidget);
      expect(find.textContaining('共 1 条记录'), findsOneWidget);
      expect(
        find.byKey(const Key('practice-route-scope-daily_care-bath_time')),
        findsNothing,
      );
    },
  );

  testWidgets(
    '从 Discover space 视图连续打开 bedtime 和 diaper_change 时不会回落到 bath_time',
    (tester) async {
      _setTallViewport(tester);
      final harness = await tester.runAsync<_RepositoryHarness>(
        _createRepositoryHarness,
      );
      addTearDown(harness!.dispose);

      await tester.runAsync(() async {
        await harness.repository.recordReaction(
          spaceId: 'family_rhythm',
          activityId: 'bedtime',
          phraseId: 'bedtime_dim_the_lights',
          reactionType: BabyReactionType.calm,
          clientTimestamp: DateTime.utc(2026, 4, 10, 21, 0),
          localEventId: 'evt_bedtime_1',
        );
        await harness.repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'diaper_change',
          phraseId: 'diaper_change_clean_bottom',
          reactionType: BabyReactionType.imitated,
          clientTimestamp: DateTime.utc(2026, 4, 10, 22, 0),
          localEventId: 'evt_diaper_change_1',
        );
      });

      await tester.pumpWidget(
        _buildDiscoverPracticeApp(
          harness.repository,
          catalogLoader: () async => _discoverNavigationCatalog(),
          practiceOpener: _pushPracticeScreen,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('discover-route-target-family_rhythm-bedtime')),
      );

      await tester.tap(find.byKey(const Key('discover-tab-space')));
      await tester.pump();
      await _pumpUntilFound(tester, find.byKey(const Key('discover-view-space')));

      await _scrollDiscoverUntilVisible(
        tester,
        find.byKey(const Key('discover-route-target-family_rhythm-bedtime')),
      );

      await tester.tap(
        find.byKey(const Key('discover-route-target-family_rhythm-bedtime')),
      );
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('practice-route-scope-family_rhythm-bedtime')),
      );

      expect(
        find.byKey(const Key('practice-route-scope-family_rhythm-bedtime')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('睡前时间')),
        findsOneWidget,
      );
      expect(find.textContaining('共 1 条记录'), findsOneWidget);

      Navigator.of(tester.element(find.byType(PracticeSessionScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await _pumpUntilFound(tester, find.byKey(const Key('discover-view-space')));

      expect(find.byKey(const Key('discover-view-space')), findsOneWidget);

      await _scrollDiscoverUntilVisible(
        tester,
        find.byKey(const Key('discover-route-target-daily_care-diaper_change')),
      );

      tester
          .widget<InkWell>(
            find.byKey(const Key('discover-route-target-daily_care-diaper_change')),
          )
          .onTap!
          .call();
      await tester.pump();
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('practice-route-scope-daily_care-diaper_change')),
      );

      expect(
        find.byKey(const Key('practice-route-scope-daily_care-diaper_change')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('换尿布')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('practice-route-scope-daily_care-bath_time')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Discover 遇到未知 activity 卡片时会进入 practice fallback，而不是静默回退默认 activity',
    (tester) async {
      final harness = await tester.runAsync<_RepositoryHarness>(
        _createRepositoryHarness,
      );
      addTearDown(harness!.dispose);

      await tester.pumpWidget(
        Provider<PracticeRepository>.value(
          value: harness.repository,
          child: MaterialApp(
            theme: AppTheme.build(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: AppRouter.onGenerateRoute(
              shellBuilder: (_) => Scaffold(
                body: DiscoverScreen(
                  catalogLoader: () async => _unknownActivityCatalog(),
                ),
              ),
              practiceBuilder: (context, settings) {
                final routeEntry = PracticeRouteEntry.fromObject(
                  settings.arguments,
                );
                return PracticeSessionScreen(routeEntry: routeEntry);
              },
            ),
          ),
        ),
      );

      await _pumpUntilFound(
        tester,
        find.byKey(
          const Key('discover-route-target-daily_care-unknown_activity'),
        ),
      );

      await _scrollDiscoverUntilVisible(
        tester,
        find.byKey(
          const Key('discover-route-target-daily_care-unknown_activity'),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('discover-route-target-daily_care-unknown_activity'),
        ),
      );
      await tester.pump();
      await _pumpUntilFound(tester, find.byKey(const Key('practice-safe-fallback')));

      expect(find.byKey(const Key('practice-safe-fallback')), findsOneWidget);
      expect(find.textContaining('未知 activityId'), findsOneWidget);
      expect(
        find.byKey(const Key('practice-route-scope-daily_care-bath_time')),
        findsNothing,
      );
    },
  );
}

Future<_RepositoryHarness> _createRepositoryHarness() async {
  final tempDir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}practice_session_screen_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'practice_${DateTime.now().microsecondsSinceEpoch}',
  );
  final assetPhraseService = AssetPhraseService(bundle: rootBundle);
  final installationIdService = InstallationIdService(
    directoryResolver: () async => tempDir,
    idGenerator: () => 'install_widget_test',
  );

  final repository = PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    installationIdService: installationIdService,
  );

  return _RepositoryHarness(
    tempDir: tempDir,
    localDataSource: localDataSource,
    repository: repository,
  );
}

class _RepositoryHarness {
  const _RepositoryHarness({
    required this.tempDir,
    required this.localDataSource,
    required this.repository,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository repository;

  Future<void> dispose() async {
    await localDataSource.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _SilentPracticeAudioController implements PracticeAudioController {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _controller.stream;

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

void _setTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 4000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _buildDiscoverPracticeApp(
  PracticeRepository repository, {
  DiscoverCatalogLoader? catalogLoader,
  DiscoverPracticeOpener? practiceOpener,
}) {
  return Provider<PracticeRepository>.value(
    value: repository,
    child: MaterialApp(
      theme: AppTheme.build(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: AppRouter.onGenerateRoute(
        shellBuilder: (_) => Scaffold(
          body: DiscoverScreen(
            catalogLoader: catalogLoader,
            practiceOpener: practiceOpener,
          ),
        ),
        practiceBuilder: (context, settings) {
          final routeEntry = PracticeRouteEntry.fromObject(settings.arguments);
          return PracticeSessionScreen(
            routeEntry: routeEntry,
            audioControllerFactory: _SilentPracticeAudioController.new,
          );
        },
      ),
    ),
  );
}

Future<void> _pushPracticeScreen(
  BuildContext context,
  PracticeRouteArgs args,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PracticeSessionScreen(
        routeEntry: PracticeRouteEntry.fromObject(args),
        audioControllerFactory: _SilentPracticeAudioController.new,
      ),
    ),
  );
}

PracticeActivityCatalog _unknownActivityCatalog() {
  const activity = PracticeCatalogActivitySummary(
    spaceId: 'daily_care',
    spaceTitle: '日常照护',
    activityId: 'unknown_activity',
    title: '未知活动',
    summary: '这张卡故意指向不存在的 activity，用来验证 fallback。',
    sceneTag: 'Broken card',
    coachTip: 'tip',
    totalPhraseCount: 1,
    completedPhraseCount: 0,
    completedPhraseIds: <String>[],
    nextPhraseId: 'unknown_phrase',
    nextPhraseEnglish: 'Unknown phrase.',
    totalEvents: 0,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );

  return const PracticeActivityCatalog(
    installationId: 'install_test',
    spaces: [
      PracticeCatalogSpaceSummary(
        spaceId: 'daily_care',
        title: '日常照护',
        description: 'broken',
        activities: [activity],
        totalEvents: 0,
        startedActivityCount: 0,
        completedActivityCount: 0,
      ),
    ],
    activities: [activity],
    totalStoredEvents: 0,
    validEvents: 0,
    knownEvents: 0,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
}

PracticeActivityCatalog _discoverNavigationCatalog() {
  const feedingTime = PracticeCatalogActivitySummary(
    spaceId: 'family_rhythm',
    spaceTitle: '家庭节律',
    activityId: 'feeding_time',
    title: '吃饭时间',
    summary: '喂饭时的真实短句。',
    sceneTag: 'Feeding time',
    coachTip: 'tip',
    totalPhraseCount: 3,
    completedPhraseCount: 1,
    completedPhraseIds: <String>['feeding_time_open_wide'],
    nextPhraseId: 'feeding_time_yummy_bite',
    nextPhraseEnglish: 'Yummy bite.',
    totalEvents: 1,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );
  const bedtime = PracticeCatalogActivitySummary(
    spaceId: 'family_rhythm',
    spaceTitle: '家庭节律',
    activityId: 'bedtime',
    title: '睡前时间',
    summary: '睡前安抚短句。',
    sceneTag: 'Bedtime',
    coachTip: 'tip',
    totalPhraseCount: 3,
    completedPhraseCount: 1,
    completedPhraseIds: <String>['bedtime_dim_the_lights'],
    nextPhraseId: 'bedtime_story_time',
    nextPhraseEnglish: 'Story time.',
    totalEvents: 1,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );
  const diaperChange = PracticeCatalogActivitySummary(
    spaceId: 'daily_care',
    spaceTitle: '日常照护',
    activityId: 'diaper_change',
    title: '换尿布',
    summary: '换尿布时的安抚短句。',
    sceneTag: 'Diaper change',
    coachTip: 'tip',
    totalPhraseCount: 3,
    completedPhraseCount: 1,
    completedPhraseIds: <String>['diaper_change_clean_bottom'],
    nextPhraseId: 'diaper_change_all_clean',
    nextPhraseEnglish: 'All clean.',
    totalEvents: 1,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );

  return const PracticeActivityCatalog(
    installationId: 'install_test',
    spaces: [
      PracticeCatalogSpaceSummary(
        spaceId: 'family_rhythm',
        title: '家庭节律',
        description: 'family rhythm',
        activities: [feedingTime, bedtime],
        totalEvents: 2,
        startedActivityCount: 2,
        completedActivityCount: 0,
      ),
      PracticeCatalogSpaceSummary(
        spaceId: 'daily_care',
        title: '日常照护',
        description: 'daily care',
        activities: [diaperChange],
        totalEvents: 1,
        startedActivityCount: 1,
        completedActivityCount: 0,
      ),
    ],
    activities: [feedingTime, bedtime, diaperChange],
    totalStoredEvents: 3,
    validEvents: 3,
    knownEvents: 3,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 12),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for expected widget.');
}

Future<void> _scrollDiscoverUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.descendant(
      of: find.byKey(const Key('shell-tab-discover')),
      matching: find.byType(Scrollable),
    ).first,
  );
  await tester.pump();
}

String _resolveBundledIsarLibraryPath() {
  final pubCacheRoot = Platform.environment['PUB_CACHE'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final candidateRoots = <Directory>[
    if (pubCacheRoot != null) Directory(pubCacheRoot),
    if (localAppData != null) Directory('$localAppData\\Pub\\Cache'),
  ];

  for (final root in candidateRoots) {
    final hostedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}hosted',
    );
    if (!hostedDirectory.existsSync()) {
      continue;
    }

    for (final host in hostedDirectory.listSync().whereType<Directory>()) {
      for (final packageDir in host.listSync().whereType<Directory>()) {
        final packageName = packageDir.path.split(RegExp(r'[\\/]')).last;
        if (!packageName.startsWith('isar_flutter_libs-')) {
          continue;
        }

        final dll = File(
          '${packageDir.path}${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll',
        );
        if (dll.existsSync()) {
          return dll.path;
        }
      }
    }
  }

  throw StateError('未在 pub cache 中找到 isar_flutter_libs/windows/isar.dll');
}
