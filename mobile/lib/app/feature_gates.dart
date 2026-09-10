import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

/// FeatureGates 负责功能门控和启动目标路由。
///
/// 职责：
/// - 解析 continuity seed
/// - 提供 starter args
class FeatureGates {
  const FeatureGates({
    required this.starterArgs,
    required this.defaultPracticeArgs,
    required this.hasExistingCareActivity,
    this.continuitySeed,
  });

  final PracticeRouteArgs starterArgs;
  final PracticeRouteArgs defaultPracticeArgs;
  final bool hasExistingCareActivity;
  final PracticeContinuitySeedState? continuitySeed;

  /// 解析已有 Care activity 和可选的 continuity seed。
  static Future<FeatureGates> resolve({
    required PracticeRepository practiceRepository,
    required OnboardingSnapshot? completedSnapshot,
    required String primarySpaceId,
    required String primaryActivityId,
    Duration continuitySeedTimeout = const Duration(seconds: 4),
  }) async {
    final primaryArgs = PracticeRouteArgs(
      spaceId: primarySpaceId,
      activityId: primaryActivityId,
    );

    final starterArgs =
        PracticeRouteArgs.maybeCreate(
          spaceId: completedSnapshot?.starterSpaceId,
          activityId: completedSnapshot?.starterActivityId,
        ) ??
        primaryArgs;

    final defaultPracticeArgs = starterArgs;

    final activityCatalog = await practiceRepository
        .getActivityCatalog()
        .timeout(continuitySeedTimeout);
    final hasExistingCareActivity = activityCatalog.totalStoredEvents > 0;

    PracticeContinuitySeedState? continuitySeed;
    try {
      final continuitySnapshot = await practiceRepository
          .getContinuitySnapshot(
            starterSpaceId: starterArgs.spaceId,
            starterActivityId: starterArgs.activityId,
          )
          .timeout(continuitySeedTimeout);
      if (completedSnapshot != null || hasExistingCareActivity) {
        final generatedContentId =
            continuitySnapshot.recommendedActivity.generatedContentId;
        final recommendedArgs = generatedContentId == null
            ? PracticeRouteArgs.maybeCreate(
                spaceId: continuitySnapshot.recommendedActivity.spaceId,
                activityId: continuitySnapshot.recommendedActivity.activityId,
              )
            : null;
        final generatedRecommendedArgs = generatedContentId == null
            ? null
            : GeneratedCareTurnRouteArgs(
                generatedContentId: generatedContentId,
              );
        if (recommendedArgs != null || generatedRecommendedArgs != null) {
          final activitySnapshot = generatedRecommendedArgs == null
              ? await practiceRepository
                    .getActivitySnapshot(
                      spaceId: recommendedArgs!.spaceId,
                      activityId: recommendedArgs.activityId,
                    )
                    .timeout(continuitySeedTimeout)
              : await practiceRepository
                    .getGeneratedActivitySnapshot(
                      generatedContentId:
                          generatedRecommendedArgs.generatedContentId,
                    )
                    .timeout(continuitySeedTimeout);
          continuitySeed = PracticeContinuitySeedState(
            starterArgs: starterArgs,
            snapshot: continuitySnapshot,
            activitySnapshot: activitySnapshot,
            recommendedArgs: recommendedArgs,
            generatedRecommendedArgs: generatedRecommendedArgs,
            status: PracticeContinuityLoadStatus.ready,
            warningMessage: continuitySnapshot.warningMessage,
            lastRefreshReason:
                'boot_seed_${continuitySnapshot.recommendation.reason.wireValue}',
          );
        }
      }
    } catch (_) {
      // Continuity seed is optional - timeout or error is acceptable.
    }

    return FeatureGates(
      starterArgs: starterArgs,
      defaultPracticeArgs: defaultPracticeArgs,
      hasExistingCareActivity: hasExistingCareActivity,
      continuitySeed: continuitySeed,
    );
  }
}
