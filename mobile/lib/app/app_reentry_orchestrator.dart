import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';

/// 回调类型：获取 Navigator 状态
typedef NavigatorStateProvider = NavigatorState? Function();

/// 回调类型：检查宿主 widget 是否仍然 mounted
typedef MountedCheck = bool Function();

/// 回调类型：获取启动目标（是否已进入 shell）
typedef LaunchDestinationProvider = AppLaunchDestination? Function();

/// 回调类型：获取种子内容包（用于练习支持性检查）
typedef SeedContentProvider = SeedContentBundle? Function();

/// 回调类型：按需查找 ViewModel
typedef HouseholdViewModelLookup = HouseholdViewModel? Function();
typedef ContinuityViewModelLookup = PracticeContinuityViewModel? Function();
typedef GardenGrowthViewModelLookup = GardenGrowthViewModel? Function();

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
    required NavigatorStateProvider navigatorStateProvider,
    required MountedCheck mountedCheck,
    required LaunchDestinationProvider launchDestinationProvider,
    required SeedContentProvider seedContentProvider,
    required HouseholdViewModelLookup householdViewModelLookup,
    required ContinuityViewModelLookup continuityViewModelLookup,
    required GardenGrowthViewModelLookup gardenGrowthViewModelLookup,
  }) : _shareReentryCoordinator = shareReentryCoordinator,
       _inviteReentryCoordinator = inviteReentryCoordinator,
       _navigatorStateProvider = navigatorStateProvider,
       _mountedCheck = mountedCheck,
       _launchDestinationProvider = launchDestinationProvider,
       _seedContentProvider = seedContentProvider,
       _householdViewModelLookup = householdViewModelLookup,
       _continuityViewModelLookup = continuityViewModelLookup,
       _gardenGrowthViewModelLookup = gardenGrowthViewModelLookup;

  final ShareReentryCoordinator _shareReentryCoordinator;
  final InviteReentryCoordinator _inviteReentryCoordinator;
  final NavigatorStateProvider _navigatorStateProvider;
  final MountedCheck _mountedCheck;
  final LaunchDestinationProvider _launchDestinationProvider;
  final SeedContentProvider _seedContentProvider;
  final HouseholdViewModelLookup _householdViewModelLookup;
  final ContinuityViewModelLookup _continuityViewModelLookup;
  final GardenGrowthViewModelLookup _gardenGrowthViewModelLookup;

  StreamSubscription<Uri>? _shareUriSubscription;
  Future<void>? _inviteDrainFuture;
  bool _inviteDrainQueued = false;

  /// 配置 share URI 监听流。重新调用时会取消前一次订阅。
  Future<void> configureShareUriSubscription([Stream<Uri>? stream]) async {
    await _shareUriSubscription?.cancel();
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
    final navigator = _navigatorStateProvider();
    if (!_mountedCheck() || destination == null || navigator == null) {
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
      AppRouter.navigateToShellFallback(navigator: navigator);
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

    final content = _seedContentProvider();
    if (content == null || !practiceArgs.isSupportedBy(content)) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _shareReentryCoordinator.markFallback(
        message: '分享链接里的 activity 不受支持，已停留在首页安全入口。',
      );
      return;
    }

    AppRouter.navigateToPracticeSeam(navigator: navigator, args: practiceArgs);
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
    final destination = _launchDestinationProvider();
    final navigator = _navigatorStateProvider();
    if (!_mountedCheck() || destination == null || navigator == null) {
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
      AppRouter.navigateToShellFallback(navigator: navigator);
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

    final householdViewModel = _householdViewModelLookup();
    if (householdViewModel == null) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _inviteReentryCoordinator.markFallback(message: '共享练习暂时不可用，已停留在首页。');
      return;
    }

    final result = await householdViewModel.acceptInviteFromReentry(command);
    final practiceArgs = result.practiceArgs;
    if (!_mountedCheck()) {
      return;
    }
    if (practiceArgs == null) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _inviteReentryCoordinator.markFallback(message: result.message);
      return;
    }

    final content = _seedContentProvider();
    if (content == null || !practiceArgs.isSupportedBy(content)) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _inviteReentryCoordinator.markFallback(
        message: '邀请返回的 activity 不受支持，已停留在首页安全入口。',
      );
      return;
    }

    final continuityViewModel = _continuityViewModelLookup();
    if (continuityViewModel != null) {
      await continuityViewModel.configureStarterArgs(
        practiceArgs,
        reason: 'invite_accept',
      );
    }
    final gardenGrowthViewModel = _gardenGrowthViewModelLookup();
    if (gardenGrowthViewModel != null) {
      await gardenGrowthViewModel.refresh();
    }

    AppRouter.navigateToPracticeSeam(navigator: navigator, args: practiceArgs);
    _inviteReentryCoordinator.markHandled(args: practiceArgs);
  }

  /// 释放 URI 订阅资源。
  void dispose() {
    unawaited(_shareUriSubscription?.cancel() ?? Future<void>.value());
  }
}
