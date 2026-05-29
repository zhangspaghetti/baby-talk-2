import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_flower_stage.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';

void main() {
  group('resolveFertilizerStage', () {
    test('maps apply count to the correct stage at thresholds', () {
      expect(resolveFertilizerStage(0).stage, FertilizerFlowerStage.seed);
      expect(resolveFertilizerStage(2).stage, FertilizerFlowerStage.seed);
      expect(resolveFertilizerStage(3).stage, FertilizerFlowerStage.sprout);
      expect(resolveFertilizerStage(9).stage, FertilizerFlowerStage.sprout);
      expect(resolveFertilizerStage(10).stage, FertilizerFlowerStage.budding);
      expect(resolveFertilizerStage(24).stage, FertilizerFlowerStage.budding);
      expect(resolveFertilizerStage(25).stage, FertilizerFlowerStage.blooming);
      expect(resolveFertilizerStage(49).stage, FertilizerFlowerStage.blooming);
      expect(resolveFertilizerStage(50).stage, FertilizerFlowerStage.fruiting);
      expect(resolveFertilizerStage(99).stage, FertilizerFlowerStage.fruiting);
    });

    test('clamps negative counts to seed', () {
      expect(resolveFertilizerStage(-5).stage, FertilizerFlowerStage.seed);
      expect(resolveFertilizerStage(-5).appliedCount, 0);
    });

    test('reports next stage and applies remaining', () {
      final info = resolveFertilizerStage(1);
      expect(info.stage, FertilizerFlowerStage.seed);
      expect(info.nextStage, FertilizerFlowerStage.sprout);
      expect(info.nextThreshold, 3);
      expect(info.appliesToNext, 2);
      expect(info.isFinalStage, isFalse);
    });

    test('progress is fractional between thresholds', () {
      // sprout starts at 3, budding at 10 → span 7; applied 5 → 2/7.
      final info = resolveFertilizerStage(5);
      expect(info.stage, FertilizerFlowerStage.sprout);
      expect(info.currentThreshold, 3);
      expect(info.progressToNext, closeTo(2 / 7, 1e-9));
    });

    test('final stage reports full progress and no next', () {
      final info = resolveFertilizerStage(60);
      expect(info.stage, FertilizerFlowerStage.fruiting);
      expect(info.isFinalStage, isTrue);
      expect(info.nextStage, isNull);
      expect(info.nextThreshold, isNull);
      expect(info.appliesToNext, 0);
      expect(info.progressToNext, 1);
    });
  });

  group('FertilizerState.backpackCount', () {
    test('is claimed minus applied, clamped at zero', () {
      const state = FertilizerState(
        appliedCount: 2,
        claimedEventKeys: {'a', 'b', 'c'},
      );
      expect(state.backpackCount, 1);
    });

    test('never goes negative when applied exceeds claimed', () {
      const state = FertilizerState(
        appliedCount: 5,
        claimedEventKeys: {'a'},
      );
      expect(state.backpackCount, 0);
    });

    test('initial state is empty', () {
      const state = FertilizerState.initial();
      expect(state.appliedCount, 0);
      expect(state.claimedEventKeys, isEmpty);
      expect(state.backpackCount, 0);
    });
  });
}
