import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:provider/provider.dart';

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
