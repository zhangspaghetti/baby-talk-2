import 'package:isar/isar.dart';
import 'package:mobile/features/garden/data/local/fertilizer_state_entity.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';

typedef FertilizerIsarOpener =
    Future<Isar> Function(
      List<CollectionSchema<dynamic>> schemas, {
      required String directory,
      String name,
    });

class FertilizerPersistenceException implements Exception {
  FertilizerPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'FertilizerPersistenceException: $message'
        : 'FertilizerPersistenceException: $message ($cause)';
  }
}

/// Isar-backed single-row store for Garden V2 fertilizer state.
class GardenFertilizerLocalDataSource {
  GardenFertilizerLocalDataSource({required Isar isar}) : _isar = isar;

  final Isar _isar;

  Isar get isar => _isar;

  static const int _rowId = 0;

  static Future<GardenFertilizerLocalDataSource> open({
    required String directory,
    String name = 'garden_fertilizer_local',
    FertilizerIsarOpener? isarOpener,
  }) async {
    final opener = isarOpener ?? Isar.open;
    try {
      final isar = await opener(
        [FertilizerStateEntitySchema],
        directory: directory,
        name: name,
      );
      return GardenFertilizerLocalDataSource(isar: isar);
    } catch (error) {
      throw FertilizerPersistenceException('打开肥料本地库失败。', error);
    }
  }

  Future<FertilizerState> readState() async {
    try {
      final entity = await _isar.fertilizerStateEntitys.get(_rowId);
      if (entity == null) {
        return const FertilizerState.initial();
      }
      return FertilizerState(
        appliedCount: entity.appliedCount,
        claimedEventKeys: entity.claimedEventKeys.toSet(),
        lastClaimedAt: entity.lastClaimedAt,
        lastAppliedAt: entity.lastAppliedAt,
      );
    } catch (error) {
      throw FertilizerPersistenceException('读取肥料状态失败。', error);
    }
  }

  Future<FertilizerState> writeState(FertilizerState state) async {
    try {
      final entity = FertilizerStateEntity()
        ..id = _rowId
        ..appliedCount = state.appliedCount
        ..claimedEventKeys = state.claimedEventKeys.toList(growable: false)
        ..lastClaimedAt = state.lastClaimedAt
        ..lastAppliedAt = state.lastAppliedAt;
      await _isar.writeTxn(() async {
        await _isar.fertilizerStateEntitys.put(entity);
      });
      return state;
    } catch (error) {
      throw FertilizerPersistenceException('写入肥料状态失败。', error);
    }
  }
}
