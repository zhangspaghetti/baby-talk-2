import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';
import 'package:mobile/features/share/presentation/share_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareViewModel', () {
    test('分享进行中会暴露 isSharing 并保护重复点击', () async {
      final api = _FakeShareApiService();
      final launcher = _PendingShareSheetLauncher();
      final repository = ShareRepository(
        apiService: api,
        shareSheetLauncher: launcher,
        platformHintResolver: () => 'android',
      );
      final viewModel = ShareViewModel(repository: repository)
        ..updateSnapshots(
          growthSnapshot: _buildGrowthSnapshot(),
          continuitySnapshot: _buildContinuitySnapshot(),
        );
      addTearDown(viewModel.dispose);

      final firstFuture = viewModel.shareCurrent();
      final secondFuture = viewModel.shareCurrent();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isSharing, isTrue);
      expect(viewModel.canShare, isFalse);
      expect(api.callCount, 1);
      expect(launcher.callCount, 1);

      launcher.completeSuccess();
      final firstResult = await firstFuture;
      final secondResult = await secondFuture;

      expect(firstResult.status, ShareExecutionStatus.shared);
      expect(secondResult.status, ShareExecutionStatus.shared);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.canShare, isTrue);
      expect(viewModel.lastShareStatus, ShareViewStatus.success);
      expect(viewModel.message, contains('分享面板'));
    });

    test('用户取消分享后会恢复按钮状态并暴露 cancelled', () async {
      final repository = ShareRepository(
        apiService: _FakeShareApiService(),
        shareSheetLauncher: _StaticShareSheetLauncher(
          result: const ShareSheetLaunchResult(
            status: ShareSheetLaunchStatus.dismissed,
          ),
        ),
        platformHintResolver: () => 'android',
      );
      final viewModel = ShareViewModel(repository: repository)
        ..updateSnapshots(
          growthSnapshot: _buildGrowthSnapshot(),
          continuitySnapshot: _buildContinuitySnapshot(),
        );
      addTearDown(viewModel.dispose);

      final result = await viewModel.shareCurrent();

      expect(result.status, ShareExecutionStatus.cancelled);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.canShare, isTrue);
      expect(viewModel.lastShareStatus, ShareViewStatus.cancelled);
      expect(viewModel.lastSharePhase, 'share_sheet_dismissed');
      expect(viewModel.message, contains('取消'));
    });

    test('API timeout 会停在 error 状态并保留可重试 message', () async {
      final repository = ShareRepository(
        apiService: _FakeShareApiService(
          error: const ShareApiException.timeout(message: 'timeout'),
        ),
        shareSheetLauncher: _StaticShareSheetLauncher(),
        platformHintResolver: () => 'android',
      );
      final viewModel = ShareViewModel(repository: repository)
        ..updateSnapshots(
          growthSnapshot: _buildGrowthSnapshot(),
          continuitySnapshot: _buildContinuitySnapshot(),
        );
      addTearDown(viewModel.dispose);

      final result = await viewModel.shareCurrent();

      expect(result.status, ShareExecutionStatus.failed);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.canShare, isTrue);
      expect(viewModel.lastShareStatus, ShareViewStatus.error);
      expect(viewModel.lastSharePhase, 'create_timeout');
      expect(viewModel.message, contains('超时'));
    });
  });
}

class _FakeShareApiService extends ShareApiService {
  _FakeShareApiService({this.error})
    : super(baseUrl: 'http://localhost:8080');

  final ShareApiException? error;
  int callCount = 0;

  @override
  Future<ShareCreateLinkResponse> createShareLink({
    required ShareLinkDraft draft,
    String? platformHint,
  }) async {
    callCount += 1;
    if (error != null) {
      throw error!;
    }
    return ShareCreateLinkResponse(
      token: 'share_token',
      shareUrl: 'https://share.example.com/share/share_token',
      expiresAt: DateTime.utc(2026, 4, 16, 12),
    );
  }

  @override
  Future<void> close() async {}
}

class _PendingShareSheetLauncher implements ShareSheetLauncher {
  final Completer<ShareSheetLaunchResult> _completer =
      Completer<ShareSheetLaunchResult>();
  int callCount = 0;

  @override
  Future<ShareSheetLaunchResult> shareText(String text, {String? subject}) {
    callCount += 1;
    return _completer.future;
  }

  void completeSuccess() {
    if (!_completer.isCompleted) {
      _completer.complete(
        const ShareSheetLaunchResult(status: ShareSheetLaunchStatus.success),
      );
    }
  }
}

class _StaticShareSheetLauncher implements ShareSheetLauncher {
  _StaticShareSheetLauncher({this.result});

  final ShareSheetLaunchResult? result;

  @override
  Future<ShareSheetLaunchResult> shareText(
    String text, {
    String? subject,
  }) async {
    return result ??
        const ShareSheetLaunchResult(status: ShareSheetLaunchStatus.success);
  }
}

GardenGrowthSnapshot _buildGrowthSnapshot() {
  return GardenGrowthSnapshot(
    installationId: 'install_secret',
    spaces: const <GardenPatchSnapshot>[],
    diaryEntries: const <GrowthDiaryEntry>[],
    milestones: const <GrowthMilestoneSnapshot>[],
    latestImpact: LatestPracticeImpact(
      eventKey: 'event_secret',
      occurredAt: DateTime.utc(2026, 4, 16, 10),
      spaceId: 'daily_care',
      spaceTitle: '日常照护',
      activityId: 'bath_time',
      activityTitle: '洗澡时间',
      phraseId: 'bath_time_warm_water',
      phraseTitle: 'Warm water.',
      reactionType: BabyReactionType.imitated,
      previousPatchStage: GardenPatchStage.tended,
      currentPatchStage: GardenPatchStage.rooted,
      previousFlowerStage: GardenFlowerStage.sprout,
      currentFlowerStage: GardenFlowerStage.growing,
      headline: '今晚洗澡时，她第一次主动说 warm water。',
      detail: '宝宝笑着拍水回应，今天这一句已经和熟悉动作连起来了。',
    ),
    totalStoredEvents: 4,
    validEvents: 4,
    knownEvents: 4,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
}

PracticeContinuitySnapshot _buildContinuitySnapshot() {
  const activity = PracticeCatalogActivitySummary(
    spaceId: 'daily_care',
    spaceTitle: '日常照护',
    activityId: 'bath_time',
    title: '洗澡时间',
    summary: '把短句贴回熟悉动作里，继续保持今天的节奏。',
    sceneTag: 'Bath',
    coachTip: '先把动作放慢。',
    totalPhraseCount: 3,
    completedPhraseCount: 1,
    completedPhraseIds: <String>['bath_time_warm_water'],
    nextPhraseId: 'bath_time_warm_water',
    nextPhraseEnglish: 'Warm water.',
    totalEvents: 4,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );
  const catalog = PracticeActivityCatalog(
    installationId: 'install_secret',
    spaces: <PracticeCatalogSpaceSummary>[
      PracticeCatalogSpaceSummary(
        spaceId: 'daily_care',
        title: '日常照护',
        description: 'desc',
        activities: <PracticeCatalogActivitySummary>[activity],
        totalEvents: 4,
        startedActivityCount: 1,
        completedActivityCount: 0,
      ),
    ],
    activities: <PracticeCatalogActivitySummary>[activity],
    totalStoredEvents: 4,
    validEvents: 4,
    knownEvents: 4,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
  return const PracticeContinuitySnapshot(
    catalog: catalog,
    recommendedActivity: activity,
    recentActivity: activity,
    nextIncompleteActivity: activity,
    starterActivity: activity,
    recommendation: PracticeContinuityRecommendation(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      activityTitle: '洗澡时间',
      reason: PracticeContinuityReason.recentActivity,
      reasonLabel: '继续最近 activity',
    ),
    cadence: PracticeContinuityCadenceSummary(
      totalKnownEvents: 4,
      startedActivityCount: 1,
      lastEventTime: null,
      headline: '正在围绕单一 activity 形成节奏',
      detail: '最近一次练习已经回到洗澡时间。',
    ),
  );
}
