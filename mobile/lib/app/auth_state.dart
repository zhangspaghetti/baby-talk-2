import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';

/// AuthState 负责管理认证状态和 onboarding 快照。
///
/// 职责：
/// - 读取 onboarding completed snapshot
/// - 判断用户是否已完成 onboarding
/// - 提供 account session 状态
class AuthState {
  const AuthState({
    required this.completedSnapshot,
    required this.isOnboarded,
  });

  final OnboardingSnapshot? completedSnapshot;
  final bool isOnboarded;

  /// 从 repositories 加载认证状态。
  static Future<AuthState> load({
    required OnboardingRepository onboardingRepository,
    OnboardingCompletedSnapshotLoader? completedSnapshotLoader,
  }) async {
    final completedSnapshot = completedSnapshotLoader == null
        ? await onboardingRepository.readCompletedSnapshot()
        : await completedSnapshotLoader();

    return AuthState(
      completedSnapshot: completedSnapshot,
      isOnboarded: completedSnapshot != null,
    );
  }
}

typedef OnboardingCompletedSnapshotLoader = Future<OnboardingSnapshot?> Function();
