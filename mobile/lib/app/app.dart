import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_view_model.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
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
typedef AppDirectoryResolver = Future<Directory> Function();
typedef PracticeAudioControllerFactory = PracticeAudioController Function();
typedef OnboardingCompletedSnapshotLoader =
    Future<OnboardingSnapshot?> Function();

enum AppLaunchDestination { onboarding, shell }

class _AppLaunchState {
  const _AppLaunchState({
    required this.practiceRepository,
    required this.onboardingRepository,
    required this.accountRepository,
    required this.destination,
    this.completedSnapshot,
  });

  final PracticeRepository practiceRepository;
  final OnboardingRepository onboardingRepository;
  final AccountRepository accountRepository;
  final AppLaunchDestination destination;
  final OnboardingSnapshot? completedSnapshot;

  String get initialRoute {
    switch (destination) {
      case AppLaunchDestination.onboarding:
        return AppRouteNames.onboarding;
      case AppLaunchDestination.shell:
        return AppRouteNames.shell;
    }
  }
}

class BabyTalkApp extends StatefulWidget {
  const BabyTalkApp({
    super.key,
    required this.bootState,
    this.repositoryFactory,
    this.appDirectoryResolver,
    this.audioControllerFactory,
    this.completedSnapshotLoader,
  });

  final AppBootState bootState;
  final PracticeRepositoryFactory? repositoryFactory;
  final AppDirectoryResolver? appDirectoryResolver;
  final PracticeAudioControllerFactory? audioControllerFactory;
  final OnboardingCompletedSnapshotLoader? completedSnapshotLoader;

  @override
  State<BabyTalkApp> createState() => _BabyTalkAppState();
}

class _BabyTalkAppState extends State<BabyTalkApp> {
  late Future<_AppLaunchState> _launchStateFuture;
  PracticeRepository? _repository;

  @override
  void initState() {
    super.initState();
    _launchStateFuture = _loadLaunchState();
  }

  @override
  void didUpdateWidget(covariant BabyTalkApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bootState != widget.bootState ||
        oldWidget.repositoryFactory != widget.repositoryFactory ||
        oldWidget.appDirectoryResolver != widget.appDirectoryResolver ||
        oldWidget.audioControllerFactory != widget.audioControllerFactory ||
        oldWidget.completedSnapshotLoader != widget.completedSnapshotLoader) {
      _launchStateFuture = _loadLaunchState();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.bootState.isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: BootFailureScreen(
          message: widget.bootState.errorMessage ?? '未知启动错误',
          statusKey: const Key('boot-status-failed'),
        ),
      );
    }

    return FutureBuilder<_AppLaunchState>(
      future: _launchStateFuture,
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
            home: BootFailureScreen(
              message: 'onboarding 本地档案读取失败：${snapshot.error}',
              statusKey: const Key('boot-route-gate-failed'),
              actionLabel: '重试',
              onAction: _retryLaunchState,
            ),
          );
        }

        final launchState = snapshot.requireData;
        final practiceRepository = launchState.practiceRepository;
        final onboardingRepository = launchState.onboardingRepository;
        final accountRepository = launchState.accountRepository;
        return MultiProvider(
          providers: [
            Provider<PracticeRepository>.value(value: practiceRepository),
            Provider<OnboardingRepository>.value(value: onboardingRepository),
            Provider<AccountRepository>.value(value: accountRepository),
            ChangeNotifierProvider<AccountViewModel>(
              create: (_) =>
                  AccountViewModel(repository: accountRepository)..initialize(),
            ),
            ChangeNotifierProvider<PracticeSessionViewModel>(
              create: (_) => PracticeSessionViewModel(
                repository: practiceRepository,
                spaceId: widget.bootState.primarySpaceId!,
                activityId: widget.bootState.primaryActivityId!,
                audioController: widget.audioControllerFactory?.call(),
              )..initialize(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Baby Talk 2',
            theme: AppTheme.build(),
            initialRoute: launchState.initialRoute,
            onGenerateRoute: AppRouter.onGenerateRoute(
              onboardingBuilder: (_) =>
                  ChangeNotifierProvider<OnboardingViewModel>(
                    create: (_) =>
                        OnboardingViewModel(repository: onboardingRepository)
                          ..initialize(),
                    child: const _BootRouteMarker(
                      routeKey: Key('boot-route-onboarding'),
                      child: OnboardingScreen(),
                    ),
                  ),
              shellBuilder: (context) {
                final routeArgs = ModalRoute.of(context)?.settings.arguments;
                final routedSnapshot = routeArgs is OnboardingSnapshot
                    ? routeArgs
                    : launchState.completedSnapshot;
                return _BootRouteMarker(
                  routeKey: const Key('boot-route-shell'),
                  child: AppShellScreen(onboardingSnapshot: routedSnapshot),
                );
              },
              practiceBuilder: (_) => const PracticeSessionScreen(),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    final repository = _repository;
    if (repository != null) {
      unawaited(repository.close());
    }
    super.dispose();
  }

  Future<void> _retryLaunchState() async {
    setState(() {
      _launchStateFuture = _loadLaunchState();
    });
  }

  Future<_AppLaunchState> _loadLaunchState() async {
    PracticeRepository? repository;
    try {
      final factory = widget.repositoryFactory ?? _defaultRepositoryFactory;
      final directory = await _resolveAppDirectory();
      repository = await factory(widget.bootState.assetPhraseService!);
      final onboardingRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => directory,
        ),
        practiceRepository: repository,
        starterSpaceId: widget.bootState.primarySpaceId!,
        starterActivityId: widget.bootState.primaryActivityId!,
      );
      final accountRepository = AccountRepository(
        localStore: AccountLocalStore(directoryResolver: () async => directory),
        practiceRepository: repository,
      );
      final completedSnapshotLoader = widget.completedSnapshotLoader;
      final completedSnapshot = completedSnapshotLoader == null
          ? await onboardingRepository.readCompletedSnapshot()
          : await completedSnapshotLoader();
      _repository = repository;
      return _AppLaunchState(
        practiceRepository: repository,
        onboardingRepository: onboardingRepository,
        accountRepository: accountRepository,
        destination: completedSnapshot == null
            ? AppLaunchDestination.onboarding
            : AppLaunchDestination.shell,
        completedSnapshot: completedSnapshot,
      );
    } catch (error) {
      if (repository != null && !identical(repository, _repository)) {
        await repository.close();
      }
      rethrow;
    }
  }

  Future<PracticeRepository> _defaultRepositoryFactory(
    AssetPhraseService assetPhraseService,
  ) async {
    final directory = await _resolveAppDirectory();
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

  Future<Directory> _resolveAppDirectory() async {
    final resolver = widget.appDirectoryResolver;
    if (resolver != null) {
      return resolver();
    }

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
  const BootFailureScreen({
    super.key,
    required this.message,
    required this.statusKey,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Key statusKey;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              key: statusKey,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: Theme.of(context).textTheme.bodyLarge),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('boot-route-gate-retry'),
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootRouteMarker extends StatelessWidget {
  const _BootRouteMarker({required this.routeKey, required this.child});

  final Key routeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('boot-route-gate-ready'),
      child: KeyedSubtree(key: routeKey, child: child),
    );
  }
}
