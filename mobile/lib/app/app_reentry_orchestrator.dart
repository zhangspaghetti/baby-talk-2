import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';

/// 回调类型：获取 GoRouter 实例
typedef GoRouterProvider = GoRouter? Function();

/// 回调类型：检查宿主 widget 是否仍然 mounted
typedef MountedCheck = bool Function();

/// 回调类型：获取启动目标（是否已进入 shell）
typedef LaunchDestinationProvider = AppLaunchDestination? Function();

/// 回调类型：按需查找 Notifier
typedef HouseholdNotifierLookup = HouseholdNotifier? Function();
typedef ContinuityNotifierLookup = PracticeContinuityNotifier? Function();
typedef GardenGrowthNotifierLookup = GardenGrowthNotifier? Function();
typedef InitialUriLoader = Future<Uri?> Function();
typedef InviteAuthenticationReady = bool Function();
typedef InviteAuthenticationNotifierLookup = Listenable? Function();

/// 重入状态机所用的启动目标枚举（与 app.dart 中 AppLaunchDestination 对齐）
enum AppLaunchDestination { onboarding, shell }

/// 从 app.dart 提取的 reentry drain 编排逻辑。
///
/// 管理 share URI 监听、share drain、invite drain 和 navigator 查找，
/// 通过回调注入与 widget 生命周期的依赖，使逻辑可独立测试。
class AppReentryOrchestrator {
  AppReentryOrchestrator({
    required ShareReentryCoordinator shareReentryCoordinator,
    required InviteReentryCoordinator inviteReentryCoordinator,
    required GoRouterProvider goRouterProvider,
    required MountedCheck mountedCheck,
    required LaunchDestinationProvider launchDestinationProvider,
    required HouseholdNotifierLookup householdNotifierLookup,
    required ContinuityNotifierLookup continuityNotifierLookup,
    required GardenGrowthNotifierLookup gardenGrowthNotifierLookup,
    InitialUriLoader? initialUriLoader,
    InviteAuthenticationReady? isInviteAuthenticationReady,
    InviteAuthenticationNotifierLookup? inviteAuthenticationNotifierLookup,
  }) : _shareReentryCoordinator = shareReentryCoordinator,
       _inviteReentryCoordinator = inviteReentryCoordinator,
       _goRouterProvider = goRouterProvider,
       _mountedCheck = mountedCheck,
       _launchDestinationProvider = launchDestinationProvider,
       _householdNotifierLookup = householdNotifierLookup,
       _continuityNotifierLookup = continuityNotifierLookup,
       _gardenGrowthNotifierLookup = gardenGrowthNotifierLookup,
       _initialUriLoader = initialUriLoader,
       _isInviteAuthenticationReady =
           isInviteAuthenticationReady ?? _alwaysInviteAuthenticationReady,
       _inviteAuthenticationNotifierLookup = inviteAuthenticationNotifierLookup;

  final ShareReentryCoordinator _shareReentryCoordinator;
  final InviteReentryCoordinator _inviteReentryCoordinator;
  final GoRouterProvider _goRouterProvider;
  final MountedCheck _mountedCheck;
  final LaunchDestinationProvider _launchDestinationProvider;
  final HouseholdNotifierLookup _householdNotifierLookup;
  final ContinuityNotifierLookup _continuityNotifierLookup;
  final GardenGrowthNotifierLookup _gardenGrowthNotifierLookup;
  final InitialUriLoader? _initialUriLoader;
  final InviteAuthenticationReady _isInviteAuthenticationReady;
  final InviteAuthenticationNotifierLookup? _inviteAuthenticationNotifierLookup;

  StreamSubscription<Uri>? _shareUriSubscription;
  int _shareUriConfigurationGeneration = 0;
  bool _disposed = false;
  Future<void>? _inviteDrainFuture;
  bool _inviteDrainQueued = false;
  Listenable? _inviteAuthenticationNotifier;

  static bool _alwaysInviteAuthenticationReady() => true;

  /// 配置 share URI 监听流。重新调用时会取消前一次订阅。
  Future<void> configureShareUriSubscription([Stream<Uri>? stream]) async {
    final configurationGeneration = ++_shareUriConfigurationGeneration;
    final previousSubscription = _shareUriSubscription;
    _shareUriSubscription = null;
    await previousSubscription?.cancel();
    if (_disposed ||
        configurationGeneration != _shareUriConfigurationGeneration) {
      return;
    }
    if (stream == null || _initialUriLoader != null) {
      try {
        final initialUri =
            await (_initialUriLoader ?? AppLinks().getInitialLink)();
        if (_disposed ||
            configurationGeneration != _shareUriConfigurationGeneration) {
          return;
        }
        if (initialUri != null) {
          handleIncomingUri(initialUri);
        }
      } on Object {
        if (_disposed ||
            configurationGeneration != _shareUriConfigurationGeneration) {
          return;
        }
        _inviteReentryCoordinator.markFallback(message: '邀请回流启动异常，已停留在首页安全入口。');
      }
    }
    if (_disposed ||
        configurationGeneration != _shareUriConfigurationGeneration) {
      return;
    }
    final effectiveStream = stream ?? AppLinks().uriLinkStream;
    _shareUriSubscription = effectiveStream.listen(
      handleIncomingUri,
      onError: (Object error, StackTrace stackTrace) {
        _shareReentryCoordinator.markFallback(message: '分享回流监听异常，已停留在首页安全入口。');
        _inviteReentryCoordinator.markFallback(message: '邀请回流监听异常，已停留在首页安全入口。');
      },
    );
  }

  /// 处理到达的深链接 URI，按 host 分流到 share 或 invite 路径。
  void handleIncomingUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'share') {
      final decision = _shareReentryCoordinator.acceptUri(uri);
      if (decision.dispatchTarget == ShareReentryDispatchTarget.none) {
        return;
      }
      drainPendingShareReentry();
      return;
    }

    if (host == 'invite') {
      final decision = _inviteReentryCoordinator.acceptUri(uri);
      if (decision.dispatchTarget == InviteReentryDispatchTarget.none) {
        return;
      }
      unawaited(drainPendingInviteReentry());
    }
  }

  /// 消费 share coordinator 中挂起的 reentry 请求，执行导航。
  void drainPendingShareReentry() {
    final destination = _launchDestinationProvider();
    final router = _goRouterProvider();
    if (!_mountedCheck() || destination == null || router == null) {
      return;
    }

    if (destination != AppLaunchDestination.shell) {
      final hadPendingPractice =
          _shareReentryCoordinator.takePendingPracticeArgs() != null;
      final hadPendingFallback = _shareReentryCoordinator
          .takePendingShellFallback();
      if (hadPendingPractice || hadPendingFallback) {
        _shareReentryCoordinator.markFallback(
          message: '分享回流已收到，但当前 app 还不能安全进入练习；已停留在安全入口。',
        );
      }
      return;
    }

    if (_shareReentryCoordinator.takePendingShellFallback()) {
      router.go(AppRouteNames.shell);
      _shareReentryCoordinator.markFallback(
        message:
            _shareReentryCoordinator.lastErrorSurface ?? '分享链接不可用，已停留在首页安全入口。',
      );
      return;
    }

    final practiceArgs = _shareReentryCoordinator.takePendingPracticeArgs();
    if (practiceArgs == null) {
      return;
    }

    // A valid route identity may refer to a newly published remote-only
    // preset. The central practice route owns catalog/generation validation;
    // bundled seed membership must not reject it before that gate runs.
    router.push(AppRouteNames.practice, extra: practiceArgs.normalized());
    _shareReentryCoordinator.markHandled(args: practiceArgs);
  }

  /// 消费 invite coordinator 中挂起的 reentry 请求，带串行化保护。
  Future<void> drainPendingInviteReentry() {
    final inFlight = _inviteDrainFuture;
    if (inFlight != null) {
      _inviteDrainQueued = true;
      return inFlight;
    }
    final future = _drainPendingInviteReentryInternal();
    _inviteDrainFuture = future;
    return future.whenComplete(() {
      if (identical(_inviteDrainFuture, future)) {
        _inviteDrainFuture = null;
      }
      final shouldDrainAgain = _inviteDrainQueued;
      _inviteDrainQueued = false;
      if (shouldDrainAgain && _mountedCheck()) {
        unawaited(drainPendingInviteReentry());
      }
    });
  }

  Future<void> _drainPendingInviteReentryInternal() async {
    _observeInviteAuthentication();
    if (_inviteReentryCoordinator.pendingTarget ==
            InviteReentryDispatchTarget.acceptInvite &&
        !_isInviteAuthenticationReady()) {
      _inviteReentryCoordinator.markAwaitingAuthentication();
      return;
    }
    final destination = _launchDestinationProvider();
    final router = _goRouterProvider();
    if (!_mountedCheck() || destination == null || router == null) {
      return;
    }

    if (destination != AppLaunchDestination.shell) {
      final hadPendingAccept =
          _inviteReentryCoordinator.takePendingAcceptCommand() != null;
      final hadPendingFallback = _inviteReentryCoordinator
          .takePendingShellFallback();
      if (hadPendingAccept || hadPendingFallback) {
        _inviteReentryCoordinator.markFallback(
          message: '邀请回流已收到，但当前 app 还不能安全进入共享练习；已停留在安全入口。',
        );
      }
      return;
    }

    if (_inviteReentryCoordinator.takePendingShellFallback()) {
      router.go(AppRouteNames.shell);
      _inviteReentryCoordinator.markFallback(
        message:
            _inviteReentryCoordinator.lastErrorSurface ?? '邀请链接不可用，已停留在首页安全入口。',
      );
      return;
    }

    final command = _inviteReentryCoordinator.takePendingAcceptCommand();
    if (command == null) {
      return;
    }

    final householdNotifier = _householdNotifierLookup();
    if (householdNotifier == null) {
      router.go(AppRouteNames.shell);
      _inviteReentryCoordinator.markFallback(message: '共享练习暂时不可用，已停留在首页。');
      return;
    }

    final result = await householdNotifier.acceptInviteFromReentry(command);
    final practiceArgs = result.practiceArgs;
    if (!_mountedCheck()) {
      return;
    }
    if (practiceArgs == null) {
      router.go(AppRouteNames.shell);
      _inviteReentryCoordinator.markFallback(message: result.message);
      return;
    }

    // Household responses can point at a published scene absent from the
    // bundled seed. Let central practice routing decide whether generation or
    // a local fallback is possible.
    final continuityNotifier = _continuityNotifierLookup();
    if (continuityNotifier != null) {
      await continuityNotifier.configureStarterArgs(
        practiceArgs,
        reason: 'invite_accept',
      );
    }
    final gardenGrowthNotifier = _gardenGrowthNotifierLookup();
    if (gardenGrowthNotifier != null) {
      await gardenGrowthNotifier.refresh();
    }

    router.push(AppRouteNames.practice, extra: practiceArgs.normalized());
    _inviteReentryCoordinator.markHandled(args: practiceArgs);
  }

  void _observeInviteAuthentication() {
    final next = _inviteAuthenticationNotifierLookup?.call();
    if (identical(next, _inviteAuthenticationNotifier)) {
      return;
    }
    _inviteAuthenticationNotifier?.removeListener(
      _onInviteAuthenticationChanged,
    );
    _inviteAuthenticationNotifier = next;
    next?.addListener(_onInviteAuthenticationChanged);
  }

  void _onInviteAuthenticationChanged() {
    if (_isInviteAuthenticationReady() &&
        _inviteReentryCoordinator.pendingTarget ==
            InviteReentryDispatchTarget.acceptInvite) {
      unawaited(drainPendingInviteReentry());
    }
  }

  /// 释放 URI 订阅资源。
  void dispose() {
    _disposed = true;
    _shareUriConfigurationGeneration++;
    unawaited(_shareUriSubscription?.cancel() ?? Future<void>.value());
    _shareUriSubscription = null;
    _inviteAuthenticationNotifier?.removeListener(
      _onInviteAuthenticationChanged,
    );
    _inviteAuthenticationNotifier = null;
  }
}
