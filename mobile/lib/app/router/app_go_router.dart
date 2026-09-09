import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/account_route_builder.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/router/root_navigator_key.dart';
import 'package:mobile/app/router/onboarding_care_turn_handoff.dart';

import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_input_screen.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_route_args.dart';
import 'package:mobile/features/care_entry/presentation/screens/care_entry_onboarding_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:mobile/features/practice/presentation/preset_scene_generation_gate_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/settings/presentation/screens/about_screen.dart';
import 'package:mobile/features/settings/presentation/screens/baby_profile_screen.dart';
import 'package:mobile/features/settings/presentation/screens/caregiver_preferences_screen.dart';
import 'package:mobile/features/settings/presentation/screens/help_feedback_screen.dart';
import 'package:mobile/features/settings/presentation/screens/playback_preferences_screen.dart';
import 'package:mobile/features/settings/presentation/screens/reminder_settings_screen.dart';
import 'package:mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:mobile/features/shell/presentation/screens/garden_growth_combined_screen.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

GoRouter createAppRouter({
  String initialLocation = AppRouteNames.shell,
  WidgetBuilder? onboardingBuilder,
  WidgetBuilder? accountBuilder,
  WidgetBuilder? shellBuilder,
  PresetSceneDefinitionLoader? presetDefinitionLoader,
}) {
  final resolvedOnboardingBuilder =
      onboardingBuilder ??
      (context) => CareEntryOnboardingScreen(
        onDeferred: () {
          if (context.mounted) context.go(AppRouteNames.shell);
        },
        onContinueCareTurn: (handoff) {
          if (context.mounted) {
            context.go(
              AppRouteNames.practice,
              extra: onboardingCareTurnRouteArgs(handoff),
            );
          }
        },
        onToday: () {
          if (context.mounted) {
            context.go(AppRouteNames.shell, extra: AppShellDestination.today);
          }
        },
        onGarden: () {
          if (context.mounted) {
            context.go(AppRouteNames.shell, extra: AppShellDestination.garden);
          }
        },
      );

  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRouteNames.shell,
        builder: (context, state) =>
            shellBuilder?.call(context) ??
            AppShellScreen(
              initialDestination: state.extra is AppShellDestination
                  ? state.extra! as AppShellDestination
                  : AppShellDestination.today,
            ),
      ),
      GoRoute(
        path: AppRouteNames.onboarding,
        builder: (context, state) => resolvedOnboardingBuilder(context),
      ),
      GoRoute(
        path: AppRouteNames.practice,
        builder: (context, state) {
          final routeEntry = PracticeRouteEntry.fromObject(state.extra);
          return switch (routeEntry.kind) {
            PracticeEntryKind.preset => PresetSceneGenerationGateScreen(
              key: ValueKey('preset-gate:${routeEntry.scopeLabel}'),
              routeEntry: routeEntry,
              presetDefinitionLoader: presetDefinitionLoader,
            ),
            PracticeEntryKind.generated ||
            PracticeEntryKind.onboarding ||
            PracticeEntryKind.invalid => PracticeSessionScreen(
              routeEntry: routeEntry,
            ),
          };
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
          return Consumer(
            builder: (context, ref, _) {
              final controller = ref.watch(
                customSceneSubmissionControllerProvider,
              );
              final recoveryCoordinator = ref.watch(
                customSceneRecoveryCoordinatorProvider,
              );
              return CustomSceneInputScreen(
                routeArgs: args,
                controller: controller.valueOrNull,
                onPresetFallback: () async {
                  if (context.mounted) {
                    context.go(
                      AppRouteNames.shell,
                      extra: AppShellDestination.discover,
                    );
                  }
                },
                onOpenPreparedContent:
                    recoveryCoordinator.valueOrNull?.openPreparedContent,
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRouteNames.account,
        builder: (context, state) =>
            accountBuilder?.call(context) ?? buildAccountRoute(state.extra),
      ),
      GoRoute(
        path: AppRouteNames.meSettings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'reminder',
            builder: (context, state) => const ReminderSettingsScreen(),
          ),
          GoRoute(
            path: 'baby-profile',
            builder: (context, state) => const BabyProfileScreen(),
          ),
          GoRoute(
            path: 'caregiver',
            builder: (context, state) => const CaregiverPreferencesScreen(),
          ),
          GoRoute(
            path: 'playback',
            builder: (context, state) => const PlaybackPreferencesScreen(),
          ),
          GoRoute(
            path: 'help',
            builder: (context, state) => const HelpFeedbackScreen(),
          ),
          GoRoute(
            path: 'about',
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRouteNames.meGrowth,
        builder: (context, state) =>
            const GardenGrowthCombinedScreen(initialTab: GrowthTab.growth),
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
