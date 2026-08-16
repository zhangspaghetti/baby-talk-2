class AppRouteNames {
  const AppRouteNames._();

  static const shell = '/';
  static const home = shell;
  static const onboarding = '/onboarding';
  static const practice = '/practice';
  static const customScene = '/custom-scene';
  static const account = '/account';
  static const meSettings = '/me/settings';
  static const meGrowth = '/me/growth';

  static const canonicalPaths = <String>{
    shell,
    onboarding,
    practice,
    customScene,
    account,
    meSettings,
    meGrowth,
  };
}

enum AppShellDestination { today, discover, garden }
