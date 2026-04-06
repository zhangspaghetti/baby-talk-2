import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

abstract class ConnectivityMonitor {
  const ConnectivityMonitor();

  Future<bool> get hasConnection;

  Stream<bool> get onStatusChange;
}

class InternetConnectivityMonitor extends ConnectivityMonitor {
  InternetConnectivityMonitor({InternetConnection? internetConnection})
    : _internetConnection = internetConnection ?? InternetConnection();

  final InternetConnection _internetConnection;

  @override
  Future<bool> get hasConnection => _internetConnection.hasInternetAccess;

  @override
  Stream<bool> get onStatusChange => _internetConnection.onStatusChange
      .map((status) => status == InternetStatus.connected)
      .distinct();
}
