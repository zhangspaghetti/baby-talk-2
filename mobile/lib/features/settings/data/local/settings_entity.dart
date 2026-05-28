import 'package:isar/isar.dart';

part '../../../../generated/features/settings/data/local/settings_entity.g.dart';

/// Single-row Isar entity that holds the full application settings snapshot
/// as a JSON blob. This avoids schema migrations when new settings are added.
@collection
class SettingsEntity {
  SettingsEntity();

  SettingsEntity.fromSnapshot({
    required this.snapshotJson,
    required this.version,
  });

  Id id = Isar.autoIncrement;

  /// Version of the settings schema. Used to detect stale data and trigger
  /// migrations when the app is updated with new settings.
  late int version;

  /// JSON-serialised settings snapshot. The shape of this object is defined
  /// by [SettingsSnapshot] in the domain layer.
  late String snapshotJson;

  /// Timestamp of the last successful write.
  DateTime? lastModifiedAt;
}
