import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/app/router/app_route_contract.dart';

import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_input_screen.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_route_args.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({
  String initialLocation = AppRouteNames.shell,
  WidgetBuilder? onboardingBuilder,
  WidgetBuilder? accountBuilder,
}) {
  final resolvedOnboardingBuilder =
      onboardingBuilder ?? (context) => const OnboardingFlowScreen();

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRouteNames.shell,
        builder: (context, state) => const AppShellScreen(),
      ),
      GoRoute(
        path: AppRouteNames.onboarding,
        builder: (context, state) => resolvedOnboardingBuilder(context),
      ),
      for (final path in AppRouteNames.legacyOnboardingPaths)
        GoRoute(
          path: path,
          redirect: (context, state) => AppRouteNames.onboarding,
        ),
      GoRoute(
        path: AppRouteNames.practice,
        builder: (context, state) {
          final routeEntry = PracticeRouteEntry.fromObject(state.extra);
          return PracticeSessionScreen(routeEntry: routeEntry);
        },
      ),
      GoRoute(
        path: AppRouteNames.customScene,
        builder: (context, state) {
          final args =
              CustomSceneRouteArgs.maybeFromObject(state.extra) ??
              const CustomSceneRouteArgs(
                entrySource: CustomSceneEntrySource.scene,
              );
          return CustomSceneInputScreen(routeArgs: args);
        },
      ),
      GoRoute(
        path: AppRouteNames.account,
        builder: (context, state) =>
            accountBuilder?.call(context) ??
            AccountEntryScreen(
              origin: accountEntryOriginFromRouteExtra(state.extra),
            ),
      ),
    ],
    redirect: (context, state) {
      // Let the app handle redirect logic via boot state
      return null;
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});
