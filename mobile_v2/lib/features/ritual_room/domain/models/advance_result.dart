import 'product_snapshot.dart';

enum AdvanceStatus {
  applied('applied'),
  duplicateIgnored('duplicate_ignored'),
  rejected('rejected');

  const AdvanceStatus(this.wireName);

  final String wireName;
}

enum AdvanceErrorCode {
  interactionNotFound('interaction_not_found'),
  revisionConflict('revision_conflict'),
  eventIdConflict('event_id_conflict'),
  unsupportedSchemaVersion('unsupported_schema_version'),
  invalidInput('invalid_input'),
  pipelineFailed('pipeline_failed');

  const AdvanceErrorCode(this.wireName);

  final String wireName;
}

sealed class AdvanceResult {
  const AdvanceResult();

  AdvanceStatus get status;
  ProductSnapshot? get snapshot;
}

final class AdvanceApplied extends AdvanceResult {
  const AdvanceApplied(this.snapshot);

  @override
  final ProductSnapshot snapshot;

  @override
  AdvanceStatus get status => AdvanceStatus.applied;
}

final class AdvanceDuplicateIgnored extends AdvanceResult {
  const AdvanceDuplicateIgnored(this.snapshot);

  @override
  final ProductSnapshot snapshot;

  @override
  AdvanceStatus get status => AdvanceStatus.duplicateIgnored;
}

final class AdvanceRejected extends AdvanceResult {
  const AdvanceRejected({required this.code, this.latestSnapshot});

  final AdvanceErrorCode code;
  final ProductSnapshot? latestSnapshot;

  @override
  AdvanceStatus get status => AdvanceStatus.rejected;

  @override
  ProductSnapshot? get snapshot => latestSnapshot;
}
