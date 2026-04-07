import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

export 'package:mobile/features/practice/data/services/asset_phrase_service.dart'
    show SeedActivity, SeedContentBundle, SeedPhrase, SeedSpace;

class AppBootState {
  const AppBootState._({
    required this.content,
    required this.assetPhraseService,
    required this.primarySpaceId,
    required this.primaryActivityId,
    this.errorMessage,
  });

  final SeedContentBundle? content;
  final AssetPhraseService? assetPhraseService;
  final String? primarySpaceId;
  final String? primaryActivityId;
  final String? errorMessage;

  bool get isReady {
    return content != null &&
        assetPhraseService != null &&
        primarySpaceId != null &&
        primaryActivityId != null &&
        errorMessage == null;
  }

  static Future<AppBootState> load(AssetBundle bundle) async {
    final assetPhraseService = AssetPhraseService(bundle: bundle);
    try {
      final content = await assetPhraseService.loadSeedContent();
      final primarySpace = content.spaces.first;
      final primaryActivity = primarySpace.activities.first;
      return AppBootState._(
        content: content,
        assetPhraseService: assetPhraseService,
        primarySpaceId: primarySpace.id,
        primaryActivityId: primaryActivity.id,
      );
    } catch (error) {
      return AppBootState._(
        content: null,
        assetPhraseService: null,
        primarySpaceId: null,
        primaryActivityId: null,
        errorMessage: 'Boot failed: $error',
      );
    }
  }
}

typedef PracticeRepositoryFactory =
    Future<PracticeRepository> Function(AssetPhraseService assetPhraseService);

class BabyTalkApp extends StatefulWidget {
  const BabyTalkApp({
    super.key,
    required this.bootState,
    this.repositoryFactory,
  });

  final AppBootState bootState;
  final PracticeRepositoryFactory? repositoryFactory;

  @override
  State<BabyTalkApp> createState() => _BabyTalkAppState();
}

class _BabyTalkAppState extends State<BabyTalkApp> {
  late final Future<PracticeRepository> _repositoryFuture = _loadRepository();

  @override
  Widget build(BuildContext context) {
    if (!widget.bootState.isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: BootFailureScreen(
          message: widget.bootState.errorMessage ?? '未知启动错误',
        ),
      );
    }

    return FutureBuilder<PracticeRepository>(
      future: _repositoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: const BootLoadingScreen(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: BootFailureScreen(message: '本地练习初始化失败：${snapshot.error}'),
          );
        }

        final repository = snapshot.requireData;
        return MultiProvider(
          providers: [
            Provider<PracticeRepository>.value(value: repository),
            ChangeNotifierProvider<PracticeSessionViewModel>(
              create: (_) => PracticeSessionViewModel(
                repository: repository,
                spaceId: widget.bootState.primarySpaceId!,
                activityId: widget.bootState.primaryActivityId!,
              )..initialize(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Baby Talk 2',
            theme: AppTheme.build(),
            onGenerateRoute: AppRouter.onGenerateRoute(
              homeBuilder: (_) => const HomeScreen(),
              practiceBuilder: (_) => const PracticeSessionScreen(),
            ),
          ),
        );
      },
    );
  }

  Future<PracticeRepository> _loadRepository() async {
    final factory = widget.repositoryFactory ?? _defaultRepositoryFactory;
    return factory(widget.bootState.assetPhraseService!);
  }

  Future<PracticeRepository> _defaultRepositoryFactory(
    AssetPhraseService assetPhraseService,
  ) async {
    final directory = await _resolvePracticeDirectory();
    final localDataSource = await PracticeLocalDataSource.open(
      directory: directory.path,
    );
    return PracticeRepository(
      assetPhraseService: assetPhraseService,
      localDataSource: localDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => directory,
      ),
    );
  }

  Future<Directory> _resolvePracticeDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } on MissingPluginException {
      final directory = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}baby_talk_2_support',
      );
      await directory.create(recursive: true);
      return directory;
    }
  }
}

class BootLoadingScreen extends StatelessWidget {
  const BootLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(key: Key('boot-loading')),
        ),
      ),
    );
  }
}

class BootFailureScreen extends StatelessWidget {
  const BootFailureScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              key: const Key('boot-status-failed'),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
