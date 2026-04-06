import 'package:baby_talk_mobile/data/app_api_client.dart';
import 'package:baby_talk_mobile/screens/app_shell.dart';
import 'package:baby_talk_mobile/screens/onboarding_flow.dart';
import 'package:baby_talk_mobile/state/app_state.dart';
import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BabyTalkApp extends StatelessWidget {
  const BabyTalkApp({super.key, BabyTalkSyncApi? apiClient})
    : _apiClient = apiClient ?? const HttpBabyTalkApiClient();

  final BabyTalkSyncApi _apiClient;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BabyTalkAppState(apiClient: _apiClient)..initialize(),
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
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: appState.needsOnboarding
              ? const OnboardingFlow()
              : const AppShell(),
        );
      },
    );
  }
}
