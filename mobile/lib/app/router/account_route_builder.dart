import 'package:flutter/widgets.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/features/auth/presentation/screens/auth_screen.dart';

/// Builds the production account entry from the route's typed origin extra.
Widget buildAccountRoute(Object? routeExtra) {
  return AuthScreen(origin: AccountEntryOrigin.fromRouteExtra(routeExtra));
}
