import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_route_contract.dart';

// Import screens
import 'package:mobile/features/onboarding/presentation/screens/onboarding_name_screen.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_scene_screen.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_practice_screen.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_complete_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/auth/presentation/screens/auth_screen.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRouteNames.shell,
    routes: [
      GoRoute(
        path: AppRouteNames.shell,
        builder: (context, state) => const AppShellScreen(),
      ),
      GoRoute(
        path: AppRouteNames.onboardingName,
        builder: (context, state) => const OnboardingNameScreen(),
      ),
      GoRoute(
        path: AppRouteNames.onboardingScene,
        builder: (context, state) => const OnboardingSceneScreen(),
      ),
      GoRoute(
        path: AppRouteNames.onboardingPractice,
        builder: (context, state) => const OnboardingPracticeScreen(),
      ),
      GoRoute(
        path: AppRouteNames.onboardingComplete,
        builder: (context, state) => const OnboardingCompleteScreen(),
      ),
      GoRoute(
        path: AppRouteNames.practice,
        builder: (context, state) {
          final routeEntry = PracticeRouteEntry.fromObject(state.extra);
          return PracticeSessionScreen(routeEntry: routeEntry);
        },
      ),
      GoRoute(
        path: AppRouteNames.account,
        builder: (context, state) => const AuthScreen(),
      ),
    ],
    redirect: (context, state) {
      // Let the app handle redirect logic via boot state
      return null;
    },
  );
});
