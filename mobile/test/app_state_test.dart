import 'dart:async';

import 'package:baby_talk_mobile/data/app_api_client.dart';
import 'package:baby_talk_mobile/data/connectivity_monitor.dart';
import 'package:baby_talk_mobile/data/seed_content.dart';
import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:baby_talk_mobile/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts offline without calling remote bootstrap', () async {
    final connectivityMonitor = _FakeConnectivityMonitor(initialValue: false);
    final api = _FakeSyncApi(snapshot: _seedSnapshot());
    final state = BabyTalkAppState(
      apiClient: api,
      connectivityMonitor: connectivityMonitor,
    );

    await state.initialize();

    expect(state.isOffline, isTrue);
    expect(state.isUsingLocalMode, isTrue);
    expect(api.fetchBootstrapCallCount, 0);
  });

  test('reconnect triggers bootstrap sync and clears offline mode', () async {
    final connectivityMonitor = _FakeConnectivityMonitor(initialValue: false);
    final api = _FakeSyncApi(snapshot: _seedSnapshot());
    final state = BabyTalkAppState(
      apiClient: api,
      connectivityMonitor: connectivityMonitor,
    );

    await state.initialize();
    await connectivityMonitor.emit(true);
    await _pumpEventQueue();

    expect(state.isOffline, isFalse);
    expect(state.isUsingLocalMode, isFalse);
    expect(api.fetchBootstrapCallCount, 1);
  });

  test('remote failure keeps local mode without marking offline', () async {
    final connectivityMonitor = _FakeConnectivityMonitor(initialValue: true);
    final api = _FakeSyncApi(snapshot: _seedSnapshot(), failBootstrap: true);
    final state = BabyTalkAppState(
      apiClient: api,
      connectivityMonitor: connectivityMonitor,
    );

    await state.initialize();

    expect(state.isOffline, isFalse);
    expect(state.isUsingLocalMode, isTrue);
    expect(api.fetchBootstrapCallCount, 1);
  });
}

Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AppSnapshot _seedSnapshot() {
  return AppSnapshot(
    caregiverName: '小明妈妈',
    childName: '小明',
    childAgeMonths: 8,
    difficulty: AppDifficulty.balanced,
    onboardingComplete: false,
    growthPoints: 42,
    weeklyPhraseCount: 23,
    streakDays: 5,
    earnedMilestoneIds: const {},
    spaces: List<SpaceItem>.from(SeedContent.spaces),
    diaryEntries: List<DiaryEntry>.from(SeedContent.diaryEntries),
    milestones: List<MilestoneEntry>.from(SeedContent.milestones),
    coachSuggestions: List<CoachSuggestion>.from(SeedContent.coachSuggestions),
  );
}

class _FakeConnectivityMonitor extends ConnectivityMonitor {
  _FakeConnectivityMonitor({required bool initialValue})
    : _currentValue = initialValue;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _currentValue;

  @override
  Future<bool> get hasConnection async => _currentValue;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> emit(bool value) async {
    _currentValue = value;
    _controller.add(value);
  }
}

class _FakeSyncApi extends BabyTalkSyncApi {
  _FakeSyncApi({required this.snapshot, this.failBootstrap = false});

  final AppSnapshot snapshot;
  final bool failBootstrap;
  int createSessionCallCount = 0;
  int fetchBootstrapCallCount = 0;

  @override
  Future<CoachChatReply> askCoach({
    required String sessionId,
    required String prompt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> createSession() async {
    createSessionCallCount += 1;
    return 'session-1';
  }

  @override
  Future<AppSnapshot> completeOnboarding({
    required String sessionId,
    required String caregiverName,
    required String childName,
    required int childAgeMonths,
    required AppDifficulty difficulty,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppSnapshot> fetchBootstrap({required String sessionId}) async {
    fetchBootstrapCallCount += 1;
    if (failBootstrap) {
      throw const BabyTalkApiException('远端同步暂时不可用。');
    }
    return snapshot;
  }

  @override
  Future<AppVersionStatus> fetchVersionStatus() async {
    return const AppVersionStatus(
      currentVersion: '1.0.0',
      minSupportedVersion: '1.0.0',
      upgradeRequired: false,
    );
  }

  @override
  Future<AppActionResult> submitPhraseReaction({
    required String sessionId,
    required String activityId,
    required String phraseId,
    required PhraseReaction reaction,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppActionResult> waterPatch({
    required String sessionId,
    required String spaceId,
  }) {
    throw UnimplementedError();
  }
}
