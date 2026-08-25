import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/features/account/presentation/screens/account_settings_screen.dart';
import 'package:mobile/features/auth/presentation/screens/auth_screen.dart';

/// Builds account route from typed origin and current authentication state.
Widget buildAccountRoute(Object? routeExtra) {
  final origin = AccountEntryOrigin.fromRouteExtra(routeExtra);
  return Consumer(
    builder: (context, ref, _) {
      final isSignedIn = ref.watch(accountNotifierProvider).isSignedIn;
      if (origin == AccountEntryOrigin.settings && isSignedIn) {
        return const AccountSettingsScreen();
      }
      return AuthScreen(origin: origin);
    },
  );
}
