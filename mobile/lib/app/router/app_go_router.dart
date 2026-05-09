import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Import screens
import 'package:mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShellScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/practice',
        builder: (context, state) {
          final routeEntry = PracticeRouteEntry.fromObject(state.extra);
          return PracticeSessionScreen(routeEntry: routeEntry);
        },
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountEntryScreen(),
      ),
    ],
    redirect: (context, state) {
      // Let the app handle redirect logic via boot state
      return null;
    },
  );
});
