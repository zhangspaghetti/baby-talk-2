import 'package:flutter/foundation.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

const _inviteReentryTokenPattern = r'^[A-Za-z0-9_-]{12,64}$';
const _inviteAllowedSources = <String>{
  'invite_link',
  'household_settings',
  'invite_banner',
};
const _inviteAllowedQueryKeys = <String>{'token', 'source', 'role'};

class InviteReentryAcceptCommand {
  const InviteReentryAcceptCommand({
    required this.token,
    required this.source,
    required this.roleHint,
  });

  final String token;
  final String source;
  final HouseholdRole roleHint;
}

class InviteReentryCoordinator extends ChangeNotifier {
  Uri? _lastHandledLink;
  String? _lastHandledScopeLabel;
  String? _lastErrorSurface;
  String? _displayMessage;
  Uri? _pendingUri;
  InviteReentryAcceptCommand? _pendingAcceptCommand;
  InviteReentryDispatchTarget _pendingTarget = InviteReentryDispatchTarget.none;
  int _handledRouteCount = 0;
  int _shellFallbackCount = 0;

  Uri? get lastHandledLink => _lastHandledLink;
  String? get lastHandledScopeLabel => _lastHandledScopeLabel;
  String? get lastErrorSurface => _lastErrorSurface;
  String? get displayMessage => _displayMessage;
  int get handledRouteCount => _handledRouteCount;
  int get shellFallbackCount => _shellFallbackCount;
  InviteReentryDispatchTarget get pendingTarget => _pendingTarget;

  InviteReentryDecision acceptUri(Uri uri) {
    final decision = InviteReentryParser.parse(uri);
    final normalizedUri = decision.normalizedUri;
    if (_isDuplicate(normalizedUri)) {
      return InviteReentryDecision.ignored(
        normalizedUri: normalizedUri,
        message: '重复照护邀请链接已忽略。',
      );
    }

    _pendingUri = normalizedUri;
    _displayMessage = null;

    if (decision.acceptCommand != null) {
      _pendingAcceptCommand = decision.acceptCommand;
      _pendingTarget = InviteReentryDispatchTarget.acceptInvite;
      _lastErrorSurface = null;
      notifyListeners();
      return decision;
    }

    _pendingAcceptCommand = null;
    _pendingTarget = InviteReentryDispatchTarget.shellFallback;
    _lastErrorSurface = decision.message;
    _displayMessage = decision.message;
    notifyListeners();
    return decision;
  }

  InviteReentryAcceptCommand? takePendingAcceptCommand() {
    if (_pendingTarget != InviteReentryDispatchTarget.acceptInvite) {
      return null;
    }
    final command = _pendingAcceptCommand;
    _pendingAcceptCommand = null;
    _pendingTarget = InviteReentryDispatchTarget.none;
    notifyListeners();
    return command;
  }

  /// Keeps a valid invite pending while sign-in is required. The command is
  /// deliberately not consumed, so post-authentication recovery can run once.
  void markAwaitingAuthentication() {
    if (_pendingTarget != InviteReentryDispatchTarget.acceptInvite) {
      return;
    }
    _displayMessage = '请先登录并完成同意，再继续接受照护邀请。';
    notifyListeners();
  }

  bool takePendingShellFallback() {
    if (_pendingTarget != InviteReentryDispatchTarget.shellFallback) {
      return false;
    }
    _pendingTarget = InviteReentryDispatchTarget.none;
    _pendingAcceptCommand = null;
    notifyListeners();
    return true;
  }

  void markHandled({required PracticeRouteArgs args}) {
    _lastHandledLink = _pendingUri;
    _lastHandledScopeLabel = args.scopeLabel;
    _lastErrorSurface = null;
    _displayMessage = null;
    _pendingUri = null;
    _pendingAcceptCommand = null;
    _pendingTarget = InviteReentryDispatchTarget.none;
    _handledRouteCount += 1;
    notifyListeners();
  }

  void markFallback({required String message}) {
    _pendingUri = null;
    _pendingAcceptCommand = null;
    _pendingTarget = InviteReentryDispatchTarget.none;
    _displayMessage = message;
    _lastErrorSurface = message;
    _shellFallbackCount += 1;
    notifyListeners();
  }

  void clearMessage() {
    if (_displayMessage == null) {
      return;
    }
    _displayMessage = null;
    notifyListeners();
  }

  bool _isDuplicate(Uri normalizedUri) {
    return normalizedUri == _pendingUri || normalizedUri == _lastHandledLink;
  }
}

enum InviteReentryDispatchTarget { none, acceptInvite, shellFallback }

class InviteReentryDecision {
  const InviteReentryDecision({
    required this.normalizedUri,
    required this.dispatchTarget,
    required this.message,
    this.acceptCommand,
  });

  final Uri normalizedUri;
  final InviteReentryDispatchTarget dispatchTarget;
  final String message;
  final InviteReentryAcceptCommand? acceptCommand;

  bool get shouldAcceptInvite =>
      dispatchTarget == InviteReentryDispatchTarget.acceptInvite &&
      acceptCommand != null;

  factory InviteReentryDecision.ignored({
    required Uri normalizedUri,
    required String message,
  }) {
    return InviteReentryDecision(
      normalizedUri: normalizedUri,
      dispatchTarget: InviteReentryDispatchTarget.none,
      message: message,
    );
  }
}

class InviteReentryParser {
  static final RegExp _tokenPattern = RegExp(_inviteReentryTokenPattern);

  static InviteReentryDecision parse(Uri uri) {
    final normalizedUri = uri.replace(fragment: '');
    final scheme = normalizedUri.scheme.toLowerCase();
    if (scheme != 'babytalk') {
      return _error(
        normalizedUri,
        '仅支持 babytalk://invite/open 邀请回流链接，已停留在首页安全入口。',
      );
    }

    final host = normalizedUri.host.toLowerCase();
    if (host != 'invite') {
      return _error(normalizedUri, '邀请链接入口不受支持，已停留在首页安全入口。');
    }

    final pathSegments = normalizedUri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (pathSegments.length != 1 || pathSegments.first != 'open') {
      return _error(normalizedUri, '邀请链接路径不受支持，已停留在首页安全入口。');
    }

    for (final entry in normalizedUri.queryParametersAll.entries) {
      if (!_inviteAllowedQueryKeys.contains(entry.key) ||
          entry.value.length != 1) {
        return _error(normalizedUri, '邀请链接包含不受支持的参数，已停留在首页安全入口。');
      }
    }

    final token = _trimToNull(normalizedUri.queryParameters['token']);
    if (token == null || !_tokenPattern.hasMatch(token)) {
      return _error(normalizedUri, '邀请链接缺少有效 token，已停留在首页安全入口。');
    }

    final source = _trimToNull(normalizedUri.queryParameters['source']);
    if (source == null || !_inviteAllowedSources.contains(source)) {
      return _error(normalizedUri, '邀请链接缺少受支持的 source，已停留在首页安全入口。');
    }

    final roleRaw = _trimToNull(normalizedUri.queryParameters['role']);
    final role = maybeParseHouseholdRole(roleRaw);
    if (role == null) {
      return _error(normalizedUri, '邀请链接缺少受支持的角色信息，已停留在首页安全入口。');
    }

    return InviteReentryDecision(
      normalizedUri: normalizedUri,
      dispatchTarget: InviteReentryDispatchTarget.acceptInvite,
      acceptCommand: InviteReentryAcceptCommand(
        token: token,
        source: source,
        roleHint: role,
      ),
      message: 'invite re-entry ready',
    );
  }

  static InviteReentryDecision _error(Uri normalizedUri, String message) {
    return InviteReentryDecision(
      normalizedUri: normalizedUri,
      dispatchTarget: InviteReentryDispatchTarget.shellFallback,
      message: message,
    );
  }

  static String? _trimToNull(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
