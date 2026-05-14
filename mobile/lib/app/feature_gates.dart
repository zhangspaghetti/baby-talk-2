import 'package:mobile/app/app_reentry_orchestrator.dart' show AppLaunchDestination;
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

/// FeatureGates 负责功能门控和启动目标路由。
///
/// 职责：
/// - 解析 continuity seed
/// - 决定启动目标（onboarding / shell）
/// - 提供 starter args
class FeatureGates {
  const FeatureGates({
    required this.destination,
    required this.starterArgs,
    required this.defaultPracticeArgs,
    this.continuitySeed,
  });

  final AppLaunchDestination destination;
  final PracticeRouteArgs starterArgs;
  final PracticeRouteArgs defaultPracticeArgs;
  final PracticeContinuitySeedState? continuitySeed;

  /// 解析启动目标和 continuity seed。
  static Future<FeatureGates> resolve({
    required PracticeRepository practiceRepository,
    required OnboardingSnapshot? completedSnapshot,
    required String primarySpaceId,
    required String primaryActivityId,
    Duration continuitySeedTimeout = const Duration(seconds: 4),
  }) async {
    final destination = completedSnapshot != null
        ? AppLaunchDestination.shell
        : AppLaunchDestination.onboarding;

    final primaryArgs = PracticeRouteArgs(
      spaceId: primarySpaceId,
      activityId: primaryActivityId,
    );

    final starterArgs = PracticeRouteArgs.maybeCreate(
          spaceId: completedSnapshot?.starterSpaceId,
          activityId: completedSnapshot?.starterActivityId,
        ) ??
        primaryArgs;

    final defaultPracticeArgs = starterArgs;

    PracticeContinuitySeedState? continuitySeed;
    if (completedSnapshot != null) {
      try {
        final continuitySnapshot = await practiceRepository
            .getContinuitySnapshot(
              starterSpaceId: starterArgs.spaceId,
              starterActivityId: starterArgs.activityId,
            )
            .timeout(continuitySeedTimeout);

        final recommendedArgs = PracticeRouteArgs.maybeCreate(
          spaceId: continuitySnapshot.recommendedActivity.spaceId,
          activityId: continuitySnapshot.recommendedActivity.activityId,
        );
        if (recommendedArgs != null) {
          final activitySnapshot = await practiceRepository
              .getActivitySnapshot(
                spaceId: recommendedArgs.spaceId,
                activityId: recommendedArgs.activityId,
              )
              .timeout(continuitySeedTimeout);
          continuitySeed = PracticeContinuitySeedState(
            starterArgs: starterArgs,
            snapshot: continuitySnapshot,
            activitySnapshot: activitySnapshot,
            recommendedArgs: recommendedArgs,
            status: PracticeContinuityLoadStatus.ready,
            warningMessage: continuitySnapshot.warningMessage,
            lastRefreshReason: 'boot_seed_${continuitySnapshot.recommendation.reason.wireValue}',
          );
        }
      } catch (_) {
        // Continuity seed is optional - timeout or error is acceptable
      }
    }

    return FeatureGates(
      destination: destination,
      starterArgs: starterArgs,
      defaultPracticeArgs: defaultPracticeArgs,
      continuitySeed: continuitySeed,
    );
  }
}
