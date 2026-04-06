import 'package:shared_preferences/shared_preferences.dart';

abstract class AppLocalStore {
  const AppLocalStore();

  Future<String?> readSessionId();

  Future<void> writeSessionId(String sessionId);

  Future<void> clearSessionId();
}

class MemoryAppLocalStore extends AppLocalStore {
  MemoryAppLocalStore({String? sessionId}) : _sessionId = sessionId;

  String? _sessionId;

  @override
  Future<String?> readSessionId() async => _sessionId;

  @override
  Future<void> writeSessionId(String sessionId) async {
    _sessionId = sessionId;
  }

  @override
  Future<void> clearSessionId() async {
    _sessionId = null;
  }
}

class SharedPreferencesAppLocalStore extends AppLocalStore {
  const SharedPreferencesAppLocalStore();

  static const String _sessionIdKey = 'baby_talk.session_id';

  @override
  Future<String?> readSessionId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_sessionIdKey);
  }

  @override
  Future<void> writeSessionId(String sessionId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionIdKey, sessionId);
  }

  @override
  Future<void> clearSessionId() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionIdKey);
  }
}
