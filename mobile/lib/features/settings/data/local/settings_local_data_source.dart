import 'package:isar/isar.dart';
import 'package:mobile/features/settings/data/local/settings_entity.dart';

/// Typedef to allow injecting an Isar opener for tests.
typedef SettingsIsarOpener =
    Future<Isar> Function(
      List<CollectionSchema<dynamic>> schemas, {
      required String directory,
      String name,
    });

class SettingsPersistenceException implements Exception {
  SettingsPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'SettingsPersistenceException: $message'
        : 'SettingsPersistenceException: $message ($cause)';
  }
}

/// Isar-backed local data source for application settings.
///
/// Follows the same pattern as [PracticeLocalDataSource]: opens a dedicated
/// Isar instance, exposes typed read/write helpers.
class SettingsLocalDataSource {
  SettingsLocalDataSource({required Isar isar}) : _isar = isar;

  final Isar _isar;

  Isar get isar => _isar;

  static const int _singletonId = 0;

  static Future<SettingsLocalDataSource> open({
    required String directory,
    String name = 'settings_local',
    SettingsIsarOpener? isarOpener,
  }) async {
    final opener = isarOpener ?? Isar.open;
    try {
      final isar = await opener(
        [SettingsEntitySchema],
        directory: directory,
        name: name,
      );
      return SettingsLocalDataSource(isar: isar);
    } catch (error) {
      throw SettingsPersistenceException('打开设置本地存储失败。', error);
    }
  }

  /// Reads the persisted settings JSON string, or `null` if nothing has been
  /// written yet.
  Future<String?> readSnapshotJson() async {
    final collection = _isar.collection<SettingsEntity>();
    final entity = await _isar.txn(() async => collection.get(_singletonId));
    return entity?.snapshotJson;
  }

  /// Reads the persisted settings version, or `null` if nothing has been
  /// written yet.
  Future<int?> readVersion() async {
    final collection = _isar.collection<SettingsEntity>();
    final entity = await _isar.txn(() async => collection.get(_singletonId));
    return entity?.version;
  }

  /// Writes (upserts) the settings snapshot JSON blob.
  Future<void> writeSnapshotJson(String json, {required int version}) async {
    final collection = _isar.collection<SettingsEntity>();
    await _isar.writeTxn(() async {
      final existing = await collection.get(_singletonId);
      final entity = existing ?? SettingsEntity()
        ..id = _singletonId;
      entity.snapshotJson = json;
      entity.version = version;
      entity.lastModifiedAt = DateTime.now().toUtc();
      await collection.put(entity);
    });
  }

  /// Deletes the settings entry if it exists.
  Future<void> deleteSnapshotIfExists() async {
    final collection = _isar.collection<SettingsEntity>();
    await _isar.writeTxn(() async {
      await collection.delete(_singletonId);
    });
  }

  /// Clears settings owned only by this installation during an approved
  /// device-local erase. This intentionally does not touch account consent or
  /// any server-side account state.
  Future<void> clearForLifecycle() => deleteSnapshotIfExists();

  /// Closes the Isar instance. Call on app shutdown or in tests.
  Future<void> close({bool deleteFromDisk = false}) async {
    await _isar.close(deleteFromDisk: deleteFromDisk);
  }
}
