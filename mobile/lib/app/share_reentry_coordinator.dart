import 'package:flutter/foundation.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

const _shareReentryTokenPattern = r'^[A-Za-z0-9_-]{8,64}$';

class ShareReentryCoordinator extends ChangeNotifier {
  Uri? _lastHandledLink;
  String? _lastHandledScopeLabel;
  String? _lastErrorSurface;
  String? _displayMessage;
  PracticeRouteArgs? _pendingPracticeArgs;
  Uri? _pendingUri;
  ShareReentryDispatchTarget _pendingTarget = ShareReentryDispatchTarget.none;
  int _handledRouteCount = 0;
  int _shellFallbackCount = 0;

  Uri? get lastHandledLink => _lastHandledLink;
  String? get lastHandledScopeLabel => _lastHandledScopeLabel;
  String? get lastErrorSurface => _lastErrorSurface;
  String? get displayMessage => _displayMessage;
  int get handledRouteCount => _handledRouteCount;
  int get shellFallbackCount => _shellFallbackCount;
  ShareReentryDispatchTarget get pendingTarget => _pendingTarget;

  ShareReentryDecision acceptUri(Uri uri) {
    final decision = ShareReentryParser.parse(uri);
    final normalizedUri = decision.normalizedUri;
    if (_isDuplicate(normalizedUri)) {
      return ShareReentryDecision.ignored(
        normalizedUri: normalizedUri,
        message: '重复分享链接已忽略。',
      );
    }

    _pendingUri = normalizedUri;
    _displayMessage = null;

    if (decision.practiceArgs != null) {
      _pendingPracticeArgs = decision.practiceArgs;
      _pendingTarget = ShareReentryDispatchTarget.practice;
      _lastErrorSurface = null;
      notifyListeners();
      return decision;
    }

    _pendingPracticeArgs = null;
    _pendingTarget = ShareReentryDispatchTarget.shellFallback;
    _lastErrorSurface = decision.message;
    _displayMessage = decision.message;
    notifyListeners();
    return decision;
  }

  PracticeRouteArgs? takePendingPracticeArgs() {
    if (_pendingTarget != ShareReentryDispatchTarget.practice) {
      return null;
    }
    final args = _pendingPracticeArgs;
    _pendingPracticeArgs = null;
    _pendingTarget = ShareReentryDispatchTarget.none;
    notifyListeners();
    return args;
  }

  bool takePendingShellFallback() {
    if (_pendingTarget != ShareReentryDispatchTarget.shellFallback) {
      return false;
    }
    _pendingTarget = ShareReentryDispatchTarget.none;
    _pendingPracticeArgs = null;
    notifyListeners();
    return true;
  }

  void markHandled({required PracticeRouteArgs args}) {
    _lastHandledLink = _pendingUri;
    _lastHandledScopeLabel = args.scopeLabel;
    _lastErrorSurface = null;
    _displayMessage = null;
    _pendingUri = null;
    _pendingPracticeArgs = null;
    _pendingTarget = ShareReentryDispatchTarget.none;
    _handledRouteCount += 1;
    notifyListeners();
  }

  void markFallback({required String message}) {
    _pendingUri = null;
    _pendingPracticeArgs = null;
    _pendingTarget = ShareReentryDispatchTarget.none;
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

enum ShareReentryDispatchTarget { none, practice, shellFallback }

class ShareReentryDecision {
  const ShareReentryDecision({
    required this.normalizedUri,
    required this.dispatchTarget,
    required this.message,
    this.practiceArgs,
  });

  final Uri normalizedUri;
  final ShareReentryDispatchTarget dispatchTarget;
  final String message;
  final PracticeRouteArgs? practiceArgs;

  bool get shouldRouteToPractice =>
      dispatchTarget == ShareReentryDispatchTarget.practice &&
      practiceArgs != null;

  factory ShareReentryDecision.ignored({
    required Uri normalizedUri,
    required String message,
  }) {
    return ShareReentryDecision(
      normalizedUri: normalizedUri,
      dispatchTarget: ShareReentryDispatchTarget.none,
      message: message,
    );
  }
}

class ShareReentryParser {
  static final RegExp _tokenPattern = RegExp(_shareReentryTokenPattern);

  static ShareReentryDecision parse(Uri uri) {
    final normalizedUri = uri.replace(fragment: '');
    final scheme = normalizedUri.scheme.toLowerCase();
    if (scheme != 'babytalk') {
      return _error(
        normalizedUri,
        '仅支持 babytalk://share/open 分享回流链接，已停留在首页安全入口。',
      );
    }

    final host = normalizedUri.host.toLowerCase();
    if (host != 'share') {
      return _error(
        normalizedUri,
        '分享链接入口不受支持，已停留在首页安全入口。',
      );
    }

    final pathSegments = normalizedUri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (pathSegments.length != 1 || pathSegments.first != 'open') {
      return _error(
        normalizedUri,
        '分享链接路径不受支持，已停留在首页安全入口。',
      );
    }

    final token = _trimToNull(normalizedUri.queryParameters['token']);
    if (token == null || !_tokenPattern.hasMatch(token)) {
      return _error(
        normalizedUri,
        '分享链接缺少有效 token，已停留在首页安全入口。',
      );
    }

    final args = PracticeRouteArgs.maybeCreate(
      spaceId: normalizedUri.queryParameters['spaceId'],
      activityId: normalizedUri.queryParameters['activityId'],
      shareToken: token,
      entrySource: PracticeRouteEntrySource.shareReentry,
    );
    if (args == null) {
      return _error(
        normalizedUri,
        '分享链接缺少可识别的练习范围，已停留在首页安全入口。',
      );
    }

    return ShareReentryDecision(
      normalizedUri: normalizedUri,
      dispatchTarget: ShareReentryDispatchTarget.practice,
      practiceArgs: args,
      message: 'share re-entry ready',
    );
  }

  static ShareReentryDecision _error(Uri normalizedUri, String message) {
    return ShareReentryDecision(
      normalizedUri: normalizedUri,
      dispatchTarget: ShareReentryDispatchTarget.shellFallback,
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
