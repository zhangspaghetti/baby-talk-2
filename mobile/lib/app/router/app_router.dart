import 'package:flutter/material.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class AppRouteNames {
  static const shell = '/';
  static const home = shell;
  static const onboarding = '/onboarding';
  static const practice = '/practice';
}

typedef AppScreenBuilder = Widget Function(BuildContext context);
typedef AppPracticeScreenBuilder =
    Widget Function(BuildContext context, RouteSettings settings);

class AppRouter {
  static RouteFactory onGenerateRoute({
    AppScreenBuilder? onboardingBuilder,
    AppScreenBuilder? shellBuilder,
    AppScreenBuilder? homeBuilder,
    required AppPracticeScreenBuilder practiceBuilder,
  }) {
    final resolvedShellBuilder = shellBuilder ?? homeBuilder;
    if (resolvedShellBuilder == null) {
      throw ArgumentError('shellBuilder 或 homeBuilder 至少要提供一个。');
    }
    final resolvedOnboardingBuilder = onboardingBuilder ?? resolvedShellBuilder;

    return (RouteSettings settings) {
      switch (settings.name) {
        case AppRouteNames.onboarding:
          return MaterialPageRoute<void>(
            builder: resolvedOnboardingBuilder,
            settings: settings,
          );
        case AppRouteNames.practice:
          return MaterialPageRoute<void>(
            builder: (context) => practiceBuilder(context, settings),
            settings: settings,
          );
        case AppRouteNames.shell:
        case null:
          return MaterialPageRoute<void>(
            builder: resolvedShellBuilder,
            settings: settings,
          );
        default:
          return MaterialPageRoute<void>(
            builder: resolvedShellBuilder,
            settings: const RouteSettings(name: AppRouteNames.shell),
          );
      }
    };
  }
}
