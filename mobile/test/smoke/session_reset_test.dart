import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

void main() {
  group('session-reset cascade — clearSession/deleteAccount/revokeConsent', () {
    // 构造一个预设为 ready 状态的 PracticeContinuityNotifier
    PracticeContinuityNotifier createReadyContinuityVM() {
      final seedSnapshot = PracticeContinuitySnapshot(
        catalog: PracticeActivityCatalog.empty(),
        recommendedActivity: PracticeCatalogActivitySummary(
          spaceId: 'daily_care',
          spaceTitle: '日常照护',
          activityId: 'bath_time',
          title: '洗澡时间',
          summary: 'summary',
          sceneTag: 'tag',
          coachTip: 'tip',
          totalPhraseCount: 1,
          completedPhraseCount: 0,
          completedPhraseIds: const [],
          nextPhraseId: 'p1',
          nextPhraseEnglish: 'hi',
          totalEvents: 0,
          skippedUnknownPhraseCount: 0,
          skippedMalformedEventCount: 0,
        ),
        recentActivity: null,
        nextIncompleteActivity: null,
        starterActivity: null,
        recommendation: PracticeContinuityRecommendation(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          activityTitle: '洗澡时间',
          reason: PracticeContinuityReason.starterFallback,
          reasonLabel: 'starter',
        ),
        cadence: PracticeContinuityCadenceSummary(
          totalKnownEvents: 0,
          startedActivityCount: 0,
          lastEventTime: null,
          headline: 'headline',
          detail: 'detail',
        ),
      );

      return PracticeContinuityNotifier(
        continuitySnapshotLoader:
            ({String? starterSpaceId, String? starterActivityId}) async =>
                seedSnapshot,
        activitySnapshotLoader:
            ({required String spaceId, required String activityId}) async {
              throw StateError('不应在 reset 测试中被调用');
            },
        seedState: PracticeContinuitySeedState(
          status: PracticeContinuityLoadStatus.ready,
          snapshot: seedSnapshot,
          recommendedArgs: const PracticeRouteArgs(
            spaceId: 'daily_care',
            activityId: 'bath_time',
          ),
          lastRefreshReason: 'test_seed',
        ),
      );
    }

    test('clearSession resets downstream VMs — continuity 回到 idle', () {
      final continuityVM = createReadyContinuityVM();

      // 验证初始状态是 ready（seedState 设置了 status 和 snapshot）
      expect(continuityVM.status, equals(PracticeContinuityLoadStatus.ready));
      expect(continuityVM.snapshot, isNotNull);
      expect(continuityVM.recommendedArgs, isNotNull);

      // 模拟 clearSession 级联中的 resetToSafeEmpty
      continuityVM.resetToSafeEmpty();

      expect(continuityVM.status, equals(PracticeContinuityLoadStatus.idle));
      expect(continuityVM.snapshot, isNull);
      expect(continuityVM.recommendedArgs, isNull);
    });

    test('clearSession resets downstream VMs — garden 回到 idle', () {
      final gardenVM = GardenGrowthNotifier(
        repository: _FakeGardenGrowthRepository(),
      );

      // resetToSafeEmpty 应该在任何状态下安全调用
      gardenVM.resetToSafeEmpty();

      expect(gardenVM.status, equals(GardenGrowthLoadStatus.idle));
    });

    test('clearSession resets downstream VMs — household 回到 unloaded', () {
      final householdVM = HouseholdNotifier(
        repository: _FakeHouseholdRepository(),
      );

      householdVM.resetToSafeEmpty();

      expect(householdVM.hasLoaded, isFalse);
    });

    test('deleteAccount resets all three VMs to safe empty simultaneously', () {
      final continuityVM = createReadyContinuityVM();
      final gardenVM = GardenGrowthNotifier(
        repository: _FakeGardenGrowthRepository(),
      );
      final householdVM = HouseholdNotifier(
        repository: _FakeHouseholdRepository(),
      );

      // 确认 continuity 的初始 ready 状态
      expect(continuityVM.status, equals(PracticeContinuityLoadStatus.ready));

      // 模拟 deleteAccount 级联——三个 VM 同时 resetToSafeEmpty
      continuityVM.resetToSafeEmpty();
      gardenVM.resetToSafeEmpty();
      householdVM.resetToSafeEmpty();

      expect(continuityVM.status, equals(PracticeContinuityLoadStatus.idle));
      expect(continuityVM.snapshot, isNull);
      expect(gardenVM.status, equals(GardenGrowthLoadStatus.idle));
      expect(householdVM.hasLoaded, isFalse);
    });

    test('revokeConsent resets all three VMs to safe empty', () {
      final continuityVM = createReadyContinuityVM();
      final gardenVM = GardenGrowthNotifier(
        repository: _FakeGardenGrowthRepository(),
      );
      final householdVM = HouseholdNotifier(
        repository: _FakeHouseholdRepository(),
      );

      // 模拟 revokeConsent 级联
      continuityVM.resetToSafeEmpty();
      gardenVM.resetToSafeEmpty();
      householdVM.resetToSafeEmpty();

      expect(continuityVM.status, equals(PracticeContinuityLoadStatus.idle));
      expect(continuityVM.snapshot, isNull);
      expect(gardenVM.status, equals(GardenGrowthLoadStatus.idle));
      expect(householdVM.hasLoaded, isFalse);
    });

    test('resetToSafeEmpty 后 VM 仍可被重新初始化（区别于 dispose）', () async {
      final continuityVM = createReadyContinuityVM();

      continuityVM.resetToSafeEmpty();
      expect(continuityVM.status, equals(PracticeContinuityLoadStatus.idle));

      // 重新刷新应该成功（不抛出异常），VM 仍然可用
      await continuityVM.refresh(reason: 'test_reuse_after_reset');
      expect(continuityVM.status, isNot(PracticeContinuityLoadStatus.idle));
    });

    test('continuity account epoch 丢弃切换前的在途结果', () async {
      final firstLoad = Completer<PracticeContinuitySnapshot>();
      final continuityVM = PracticeContinuityNotifier(
        continuitySnapshotLoader:
            ({String? starterSpaceId, String? starterActivityId}) =>
                firstLoad.future,
        activitySnapshotLoader:
            ({required String spaceId, required String activityId}) async =>
                throw StateError('stale activity loader must not run'),
        refreshTimeout: Duration.zero,
      );

      continuityVM.bindAccountContext('account-a');
      final pending = continuityVM.refresh(reason: 'account-a-refresh');
      continuityVM.bindAccountContext('account-b');
      firstLoad.completeError(StateError('stale account-a result'));
      await pending;

      expect(continuityVM.status, PracticeContinuityLoadStatus.idle);
      expect(continuityVM.snapshot, isNull);
      expect(continuityVM.lastRefreshReason, isNull);
    });

    test('Garden account epoch 丢弃切换前的在途结果', () async {
      final firstLoad = Completer<GardenGrowthSnapshot>();
      final gardenVM = GardenGrowthNotifier(
        repository: _DelayedGardenGrowthRepository(firstLoad.future),
        refreshTimeout: Duration.zero,
      );

      gardenVM.bindAccountContext('account-a');
      final pending = gardenVM.refresh();
      gardenVM.bindAccountContext('account-b');
      firstLoad.completeError(StateError('stale account-a result'));
      await pending;

      expect(gardenVM.status, GardenGrowthLoadStatus.idle);
      expect(gardenVM.snapshot, GardenGrowthSnapshot.empty());
    });
  });

  group('dev-text absence — 内部开发诊断文案不应出现', () {
    test('provider 缺失 不再作为用户可见文案出现', () {
      for (final status in PracticeContinuityLoadStatus.values) {
        expect(status.label, isNot(contains('provider')));
        expect(status.label, isNot(contains('缺失')));
      }
    });

    test('auth · anon 类 dev-text 不再出现在 enum labels 中', () {
      for (final status in PracticeContinuityLoadStatus.values) {
        expect(status.label, isNot(contains('auth ·')));
        expect(status.label, isNot(contains('anon')));
      }
    });

    test('GardenGrowthLoadStatus 不包含 dev-internal 名称', () {
      for (final status in GardenGrowthLoadStatus.values) {
        expect(status.name, isNot(contains('provider')));
        expect(status.name, isNot(contains('auth')));
        expect(status.name, isNot(contains('Guest')));
      }
    });
  });
}

/// Fake GardenGrowthRepository——noSuchMethod 处理所有调用
class _FakeGardenGrowthRepository implements GardenGrowthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    if (memberName.contains('buildSnapshot')) {
      return Future<GardenGrowthSnapshot>.value(GardenGrowthSnapshot.empty());
    }
    return null;
  }
}

class _DelayedGardenGrowthRepository implements GardenGrowthRepository {
  _DelayedGardenGrowthRepository(this.result);

  final Future<GardenGrowthSnapshot> result;

  @override
  Future<GardenGrowthSnapshot> buildSnapshot() => result;
}

/// Fake HouseholdRepository——noSuchMethod 处理所有调用
class _FakeHouseholdRepository implements HouseholdRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    if (memberName.contains('loadSnapshot')) {
      return Future<HouseholdLocalSnapshot>.value(HouseholdLocalSnapshot.empty);
    }
    if (memberName.contains('close')) {
      return Future<void>.value();
    }
    return null;
  }
}
