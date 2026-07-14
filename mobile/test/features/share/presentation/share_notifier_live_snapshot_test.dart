import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';
import 'package:mobile/features/share/presentation/share_notifier.dart';

void main() {
  group('ShareNotifier live snapshot binding', () {
    test(
      'currentDraft reflects latest loader snapshots without updateSnapshots',
      () {
        final repository = ShareRepository(
          apiService: _FakeShareApiService(),
          shareSheetLauncher: _StaticShareSheetLauncher(),
          platformHintResolver: () => 'android',
        );

        var growth = _buildGrowthSnapshot(headline: '第一版成长故事');
        final continuity = _buildContinuitySnapshot();

        final notifier = ShareNotifier(
          repository: repository,
          initialGrowthSnapshot: growth,
          initialContinuitySnapshot: continuity,
          growthSnapshotLoader: () => growth,
          continuitySnapshotLoader: () => continuity,
        );
        addTearDown(notifier.dispose);

        expect(notifier.currentDraft?.headline, '第一版成长故事');

        growth = _buildGrowthSnapshot(headline: '最新权威成长故事');

        expect(notifier.currentDraft?.headline, '最新权威成长故事');
      },
    );

    test('shareCurrent uses live snapshots at execution time', () async {
      final api = _FakeShareApiService();
      final repository = ShareRepository(
        apiService: api,
        shareSheetLauncher: _StaticShareSheetLauncher(),
        platformHintResolver: () => 'android',
      );

      var growth = _buildGrowthSnapshot(headline: '旧文案');
      final continuity = _buildContinuitySnapshot();

      final notifier = ShareNotifier(
        repository: repository,
        initialGrowthSnapshot: growth,
        initialContinuitySnapshot: continuity,
        growthSnapshotLoader: () => growth,
        continuitySnapshotLoader: () => continuity,
      );
      addTearDown(notifier.dispose);

      growth = _buildGrowthSnapshot(headline: '实时权威文案');

      final result = await notifier.shareCurrent();

      expect(result.status, ShareExecutionStatus.shared);
      expect(api.lastDraft?.headline, '实时权威文案');
    });
  });
}

class _FakeShareApiService extends ShareApiService {
  _FakeShareApiService() : super(baseUrl: 'http://localhost:8080');

  ShareLinkDraft? lastDraft;

  @override
  Future<ShareCreateLinkResponse> createShareLink({
    required ShareLinkDraft draft,
    String? platformHint,
  }) async {
    lastDraft = draft;
    return ShareCreateLinkResponse(
      token: 'share_token',
      shareUrl: 'https://share.example.com/share/share_token',
      expiresAt: DateTime.utc(2026, 4, 16, 12),
    );
  }

  @override
  Future<void> close() async {}
}

class _StaticShareSheetLauncher implements ShareSheetLauncher {
  @override
  Future<ShareSheetLaunchResult> shareText(
    String text, {
    String? subject,
  }) async {
    return const ShareSheetLaunchResult(status: ShareSheetLaunchStatus.success);
  }
}

GardenGrowthSnapshot _buildGrowthSnapshot({required String headline}) {
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
      reactionType: BabyReactionType.cooperating,
      previousPatchStage: GardenPatchStage.tended,
      currentPatchStage: GardenPatchStage.rooted,
      previousFlowerStage: GardenFlowerStage.sprout,
      currentFlowerStage: GardenFlowerStage.growing,
      headline: headline,
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
    warningMessage: null,
  );
}
