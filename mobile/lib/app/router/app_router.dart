import 'package:flutter/material.dart';

class AppRouteNames {
  static const home = '/';
  static const practice = '/practice';
}

typedef AppScreenBuilder = Widget Function(BuildContext context);

class AppRouter {
  static RouteFactory onGenerateRoute({
    required AppScreenBuilder homeBuilder,
    required AppScreenBuilder practiceBuilder,
  }) {
    return (RouteSettings settings) {
      switch (settings.name) {
        case AppRouteNames.practice:
          return MaterialPageRoute<void>(
            builder: practiceBuilder,
            settings: settings,
          );
        case AppRouteNames.home:
        case null:
          return MaterialPageRoute<void>(
            builder: homeBuilder,
            settings: settings,
          );
        default:
          return MaterialPageRoute<void>(
            builder: homeBuilder,
            settings: const RouteSettings(name: AppRouteNames.home),
          );
      }
    };
  }
}
