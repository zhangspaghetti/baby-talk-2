import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareRepository', () {
    test('buildDraft 只使用 snapshot truth source 并剔除 internal 字段', () async {
      final api = _FakeShareApiService();
      final launcher = _FakeShareSheetLauncher();
      final repository = ShareRepository(
        apiService: api,
        shareSheetLauncher: launcher,
        platformHintResolver: () => 'android',
      );

      final draft = repository.buildDraft(
        growthSnapshot: _buildGrowthSnapshot(),
        continuitySnapshot: _buildContinuitySnapshot(),
      );

      expect(draft, isNotNull);
      expect(draft!.source, ShareLinkSource.pairedProgress);
      expect(draft.headline, contains('今晚洗澡时'));
      expect(draft.phraseText, 'Warm water.');
      expect(draft.recommendationTitle, '接下来继续 洗澡时间');

      final payload = draft.toCreatePayload(platformHint: 'android');
      expect(payload['source'], 'paired_progress');
      expect(payload['platformHint'], 'android');
      expect(payload.keys, isNot(contains('installationId')));
      expect(payload.keys, isNot(contains('eventKey')));
      expect(payload.keys, isNot(contains('fallbackReason')));
      expect(payload.keys, isNot(contains('warningMessage')));

      final message = draft.buildShareMessage(
        'https://share.example.com/share/share_token',
      );
      expect(message, isNotNull);
      expect(message, contains('Warm water.'));
      expect(message, contains('接下来继续 洗澡时间'));
      expect(message, isNot(contains('install_secret')));
      expect(message, isNot(contains('event_secret')));
      expect(message, isNot(contains('fallbackReason')));
      expect(message, isNot(contains('warningMessage')));
      expect(message, isNot(contains('内部 debug 文案')));
    });

    test('只有 continuity recommendation 时仍可生成分享', () async {
      final api = _FakeShareApiService();
      final launcher = _FakeShareSheetLauncher();
      final repository = ShareRepository(
        apiService: api,
        shareSheetLauncher: launcher,
        platformHintResolver: () => 'ios',
      );

      final result = await repository.shareSnapshots(
        continuitySnapshot: _buildContinuitySnapshot(),
      );

      expect(result.status, ShareExecutionStatus.shared);
      expect(result.phase, 'share_sheet_success');
      expect(api.callCount, 1);
      expect(api.lastDraft?.source, ShareLinkSource.continuityRecommendation);
      expect(launcher.callCount, 1);
      expect(launcher.lastText, contains('接下来继续 洗澡时间'));
      expect(launcher.lastText, contains('Warm water.'));
    });

    test('空 headline 且无 continuity 时不可分享', () async {
      final repository = ShareRepository(
        apiService: _FakeShareApiService(),
        shareSheetLauncher: _FakeShareSheetLauncher(),
        platformHintResolver: () => 'android',
      );

      final result = await repository.shareSnapshots(
        growthSnapshot: _buildGrowthSnapshot(headline: ' '),
      );

      expect(result.status, ShareExecutionStatus.failed);
      expect(result.phase, 'draft_unavailable');
      expect(result.message, contains('可分享'));
    });

    test('非法 response URL 会阻止打开 share sheet', () async {
      final api = _FakeShareApiService(
        response: ShareCreateLinkResponse(
          token: 'share_token',
          shareUrl: 'javascript:alert(1)',
          expiresAt: DateTime.utc(2026, 4, 16, 12),
        ),
      );
      final launcher = _FakeShareSheetLauncher();
      final repository = ShareRepository(
        apiService: api,
        shareSheetLauncher: launcher,
        platformHintResolver: () => 'android',
      );

      final result = await repository.shareSnapshots(
        growthSnapshot: _buildGrowthSnapshot(),
        continuitySnapshot: _buildContinuitySnapshot(),
      );

      expect(result.status, ShareExecutionStatus.failed);
      expect(result.phase, 'share_message_invalid');
      expect(result.message, contains('文案异常'));
      expect(launcher.callCount, 0);
    });

    test('API 5xx 与 timeout 会被映射为可重试失败', () async {
      final timeoutRepository = ShareRepository(
        apiService: _FakeShareApiService(
          error: const ShareApiException.timeout(message: 'timeout'),
        ),
        shareSheetLauncher: _FakeShareSheetLauncher(),
        platformHintResolver: () => 'android',
      );
      final timeoutResult = await timeoutRepository.shareSnapshots(
        growthSnapshot: _buildGrowthSnapshot(),
        continuitySnapshot: _buildContinuitySnapshot(),
      );
      expect(timeoutResult.status, ShareExecutionStatus.failed);
      expect(timeoutResult.phase, 'create_timeout');
      expect(timeoutResult.message, contains('超时'));

      final httpRepository = ShareRepository(
        apiService: _FakeShareApiService(
          error: const ShareApiException(
            kind: ShareApiFailureKind.http,
            message: 'server boom',
            statusCode: 500,
            code: 'share_storage_unavailable',
          ),
        ),
        shareSheetLauncher: _FakeShareSheetLauncher(),
        platformHintResolver: () => 'android',
      );
      final httpResult = await httpRepository.shareSnapshots(
        growthSnapshot: _buildGrowthSnapshot(),
        continuitySnapshot: _buildContinuitySnapshot(),
      );
      expect(httpResult.status, ShareExecutionStatus.failed);
      expect(httpResult.phase, 'create_http_500');
      expect(httpResult.message, contains('暂时不可用'));
    });

    test('share sheet unavailable 会停在可见失败态', () async {
      final repository = ShareRepository(
        apiService: _FakeShareApiService(),
        shareSheetLauncher: _FakeShareSheetLauncher(
          result: const ShareSheetLaunchResult(
            status: ShareSheetLaunchStatus.unavailable,
          ),
        ),
        platformHintResolver: () => 'android',
      );

      final result = await repository.shareSnapshots(
        growthSnapshot: _buildGrowthSnapshot(),
        continuitySnapshot: _buildContinuitySnapshot(),
      );

      expect(result.status, ShareExecutionStatus.failed);
      expect(result.phase, 'share_sheet_unavailable');
      expect(result.message, contains('分享面板'));
    });
  });
}

class _FakeShareApiService extends ShareApiService {
  _FakeShareApiService({this.response, this.error})
    : super(baseUri: Uri.parse('http://localhost:8080'));

  final ShareCreateLinkResponse? response;
  final ShareApiException? error;
  int callCount = 0;
  ShareLinkDraft? lastDraft;
  String? lastPlatformHint;

  @override
  Future<ShareCreateLinkResponse> createShareLink({
    required ShareLinkDraft draft,
    String? platformHint,
  }) async {
    callCount += 1;
    lastDraft = draft;
    lastPlatformHint = platformHint;
    if (error != null) {
      throw error!;
    }
    return response ??
        ShareCreateLinkResponse(
          token: 'share_token',
          shareUrl: 'https://share.example.com/share/share_token',
          expiresAt: DateTime.utc(2026, 4, 16, 12),
        );
  }

  @override
  Future<void> close() async {}
}

class _FakeShareSheetLauncher implements ShareSheetLauncher {
  _FakeShareSheetLauncher({this.result, this.error});

  final ShareSheetLaunchResult? result;
  final ShareSheetException? error;
  int callCount = 0;
  String? lastText;
  String? lastSubject;

  @override
  Future<ShareSheetLaunchResult> shareText(String text, {String? subject}) async {
    callCount += 1;
    lastText = text;
    lastSubject = subject;
    if (error != null) {
      throw error!;
    }
    return result ??
        const ShareSheetLaunchResult(status: ShareSheetLaunchStatus.success);
  }
}

GardenGrowthSnapshot _buildGrowthSnapshot({
  String headline = '今晚洗澡时，她第一次主动说 warm water。',
}) {
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
      headline: headline,
      detail: '宝宝笑着拍水回应，今天这一句已经和熟悉动作连起来了。',
    ),
    totalStoredEvents: 4,
    validEvents: 4,
    knownEvents: 4,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
    projectionWarning: 'warningMessage 内部 debug 文案',
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
    warningMessage: 'warningMessage should never leak',
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
      fallbackReason: 'fallbackReason should never leak',
    ),
    cadence: PracticeContinuityCadenceSummary(
      totalKnownEvents: 4,
      startedActivityCount: 1,
      lastEventTime: null,
      headline: '正在围绕单一 activity 形成节奏',
      detail: '最近一次练习已经回到洗澡时间。',
    ),
    warningMessage: 'warningMessage should never leak',
  );
}
