class AppRouteNames {
  const AppRouteNames._();

  static const shell = '/';
  static const home = shell;
  static const onboarding = '/onboarding';
  static const practice = '/practice';
  static const customScene = '/custom-scene';
  static const account = '/account';
  static const meSettings = '/me/settings';
  static const meReminder = '$meSettings/reminder';
  static const meBabyProfile = '$meSettings/baby-profile';
  static const meCaregiver = '$meSettings/caregiver';
  static const mePlayback = '$meSettings/playback';
  static const meHelp = '$meSettings/help';
  static const meAbout = '$meSettings/about';
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
