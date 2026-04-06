import 'package:baby_talk_mobile/data/app_api_client.dart';
import 'package:baby_talk_mobile/data/connectivity_monitor.dart';
import 'package:baby_talk_mobile/screens/app_shell.dart';
import 'package:baby_talk_mobile/screens/onboarding_flow.dart';
import 'package:baby_talk_mobile/state/app_state.dart';
import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:baby_talk_mobile/widgets/upgrade_required_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BabyTalkApp extends StatelessWidget {
  const BabyTalkApp({
    super.key,
    BabyTalkSyncApi? apiClient,
    ConnectivityMonitor? connectivityMonitor,
  }) : _apiClient = apiClient ?? const HttpBabyTalkApiClient(),
       _connectivityMonitor = connectivityMonitor;

  final BabyTalkSyncApi _apiClient;
  final ConnectivityMonitor? _connectivityMonitor;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BabyTalkAppState(
        apiClient: _apiClient,
        connectivityMonitor: _connectivityMonitor,
      )..initialize(),
      child: MaterialApp(
        title: 'Baby Talk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Consumer<BabyTalkAppState>(
      builder: (context, appState, _) {
        return Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: appState.needsOnboarding
                  ? const OnboardingFlow()
                  : const AppShell(),
            ),
            if (appState.requiresUpgrade)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: UpgradeRequiredBanner(
                      message: appState.upgradeRequiredMessage,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
