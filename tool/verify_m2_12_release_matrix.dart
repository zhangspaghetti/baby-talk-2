import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'verify_m2_13_closure_candidate.dart' as closure_candidate;

const m212ReleaseMatrixSuccessMarker =
    'M2-12 UAT release matrix is closure-ready.';

const m212UatRecordsRelativePath = 'docs/uat/m2/records';

const m212ReleaseMatrixUsage =
    'Usage: dart tool/verify_m2_12_release_matrix.dart --manifest <path> [--records <directory>] [--help]';

const _requiredCaseIds = <String>{
  'android_generated_flow',
  'response_loss_reconciliation',
  'force_stop_recovery',
  'all_reaction_audio_branches',
  'talkback_human_accessibility',
};

const _canonicalScenes = <String>{'shoes', 'bath', 'water', 'teeth', 'tidying'};

const _candidateKeys = <String>{
  'mobile_source_sha',
  'mobile_apk_sha256',
  'backend_source_sha',
  'backend_artifact_identity',
  'environment_identity',
  'provider_mode',
  'provider_profile',
  'provider_model_identity',
  'configuration_fingerprint',
};

const _requiredRecordKeys = <String>{
  'schema_version',
  'record_id',
  'case_id',
  'canonical_scene',
  'executor',
  'executed_at',
  'timezone',
  'candidate_manifest',
  'candidate',
  'device',
  'authenticity',
  'prerequisites',
  'steps',
  'status',
  'verdict',
  'evidence_location',
  'defects',
  'retest_outcome',
  'privacy',
  'branch_reviews',
};

const _allowedRecordKeys = <String>{..._requiredRecordKeys, 'accessibility'};

const _requiredBranches = <String>{
  'starter',
  'cooperating',
  'hesitant',
  'resisting',
  'no_response',
  'other',
};

class M212ReleaseMatrixViolation {
  const M212ReleaseMatrixViolation({
    required this.code,
    required this.recordLocation,
    required this.detail,
  });

  final String code;
  final String recordLocation;
  final String detail;

  @override
  String toString() => '$code $recordLocation | $detail';
}

class M212ReleaseMatrixReport {
  const M212ReleaseMatrixReport({
    required this.violations,
    required this.parsedRecords,
  });

  final List<M212ReleaseMatrixViolation> violations;
  final int parsedRecords;

  bool get passes => violations.isEmpty;
}

M212ReleaseMatrixReport scanM212ReleaseMatrix({
  String? projectRoot,
  String? uatRecordsPath,
  String? candidateManifestPath,
}) {
  final root = _normalize(projectRoot ?? Directory.current.path);
  final configuredRecordsPath =
      uatRecordsPath ?? '$root/$m212UatRecordsRelativePath';
  final recordsPath = Directory(configuredRecordsPath).isAbsolute
      ? configuredRecordsPath
      : '$root/$configuredRecordsPath';
  final recordsDirectory = Directory(recordsPath);
  final violations = <M212ReleaseMatrixViolation>[];
  final parsedRecords = <_ParsedRecord>[];
  final frozenCandidate = _loadFrozenCandidate(
    root: root,
    candidateManifestPath: candidateManifestPath,
    violations: violations,
  );

  if (!recordsDirectory.existsSync()) {
    _add(
      violations,
      'records_directory_missing',
      'records',
      'UAT records directory is missing',
    );
  } else {
    final recordFiles =
        recordsDirectory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));
    if (recordFiles.isEmpty) {
      _add(
        violations,
        'records_missing',
        'records',
        'no machine-readable UAT records were supplied',
      );
    }
    for (final file in recordFiles) {
      _parseRecordFile(file, violations, parsedRecords);
    }
  }

  _validateCaseCompleteness(parsedRecords, violations);
  _validateCandidateIdentity(parsedRecords, violations);
  if (frozenCandidate != null) {
    _validateFrozenCandidate(parsedRecords, frozenCandidate, violations);
  }
  violations.sort((left, right) {
    final location = left.recordLocation.compareTo(right.recordLocation);
    if (location != 0) return location;
    final code = left.code.compareTo(right.code);
    if (code != 0) return code;
    return left.detail.compareTo(right.detail);
  });

  return M212ReleaseMatrixReport(
    violations: List.unmodifiable(violations),
    parsedRecords: parsedRecords.length,
  );
}

String renderM212ReleaseMatrixReport(M212ReleaseMatrixReport report) {
  final buffer = StringBuffer()
    ..writeln(
      'm2_12_uat_release_matrix_status=${report.passes ? 'pass' : 'fail'}',
    )
    ..writeln('parsed_records=${report.parsedRecords}')
    ..writeln('violations=${report.violations.length}');
  for (final violation in report.violations) {
    buffer.writeln('  $violation');
  }
  return buffer.toString();
}

void _parseRecordFile(
  File file,
  List<M212ReleaseMatrixViolation> violations,
  List<_ParsedRecord> parsedRecords,
) {
  final source = _safeFileLabel(file);
  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException {
    _add(violations, 'invalid_json', source, 'record JSON is malformed');
    return;
  } on FileSystemException {
    _add(violations, 'unreadable_record', source, 'record JSON cannot be read');
    return;
  }

  final records = decoded is List<Object?> ? decoded : <Object?>[decoded];
  if (records.isEmpty) {
    _add(
      violations,
      'empty_record_file',
      source,
      'record JSON contains no records',
    );
    return;
  }
  for (var index = 0; index < records.length; index += 1) {
    final location = '$source[$index]';
    final record = _object(records[index]);
    if (record == null) {
      _add(violations, 'invalid_record', location, 'record must be an object');
      continue;
    }
    final parsed = _validateRecord(record, location, violations);
    if (parsed != null) parsedRecords.add(parsed);
  }
}

_ParsedRecord? _validateRecord(
  Map<String, Object?> record,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  _validateKeys(
    record,
    _requiredRecordKeys,
    _allowedRecordKeys,
    location,
    violations,
  );
  final schemaVersion = _requiredString(
    record,
    'schema_version',
    location,
    violations,
  );
  if (schemaVersion != null && schemaVersion != 'm2_android_uat_v1') {
    _add(
      violations,
      'invalid_schema',
      location,
      'unsupported UAT record schema',
    );
  }
  final recordId = _requiredString(record, 'record_id', location, violations);
  if (recordId != null && !_opaqueId.hasMatch(recordId)) {
    _add(
      violations,
      'invalid_record_id',
      location,
      'record_id is not an opaque identifier',
    );
  }
  final caseId = _requiredString(record, 'case_id', location, violations);
  if (caseId != null && !_requiredCaseIds.contains(caseId)) {
    _add(violations, 'unknown_case', location, 'unknown UAT case');
  }
  final canonicalScene = _requiredString(
    record,
    'canonical_scene',
    location,
    violations,
  );
  if (canonicalScene != null && !_canonicalScenes.contains(canonicalScene)) {
    _add(
      violations,
      'invalid_scene',
      location,
      'scene must be an approved canonical label',
    );
  }
  final executor = _requiredString(record, 'executor', location, violations);
  if (executor != null && !_executor.hasMatch(executor)) {
    _add(
      violations,
      'privacy_violation',
      location,
      'executor must be an opaque role reference',
    );
  }
  final executedAt = _requiredString(
    record,
    'executed_at',
    location,
    violations,
  );
  if (executedAt != null &&
      (!_rfc3339.hasMatch(executedAt) ||
          DateTime.tryParse(executedAt) == null)) {
    _add(
      violations,
      'invalid_timestamp',
      location,
      'timestamp must be RFC 3339 with an offset',
    );
  }
  final timezone = _requiredString(record, 'timezone', location, violations);
  if (timezone != null && !_timezone.hasMatch(timezone)) {
    _add(
      violations,
      'invalid_timezone',
      location,
      'timezone must be an IANA timezone',
    );
  }

  final candidateManifest = _requiredObject(
    record,
    'candidate_manifest',
    location,
    violations,
  );
  final candidateManifestReference = candidateManifest == null
      ? null
      : _validateCandidateManifestReference(
          candidateManifest,
          location,
          violations,
        );
  final candidate = _requiredObject(record, 'candidate', location, violations);
  final candidateTuple = candidate == null
      ? null
      : _validateCandidate(candidate, location, violations);
  final device = _requiredObject(record, 'device', location, violations);
  if (device != null) _validateDevice(device, location, caseId, violations);
  final authenticity = _requiredObject(
    record,
    'authenticity',
    location,
    violations,
  );
  if (authenticity != null) {
    _validateAuthenticity(authenticity, location, violations);
  }
  _validatePrerequisites(record['prerequisites'], location, violations);
  _validateSteps(record['steps'], location, violations);

  final status = _requiredString(record, 'status', location, violations);
  if (status != null && status != 'FINAL') {
    _add(
      violations,
      'non_final_status',
      location,
      'record status must be FINAL',
    );
  }
  final verdict = _requiredString(record, 'verdict', location, violations);
  if (verdict != null && verdict != 'PASS') {
    _add(
      violations,
      'non_passing_verdict',
      location,
      'record verdict must be PASS',
    );
  }
  final evidenceLocation = _requiredString(
    record,
    'evidence_location',
    location,
    violations,
  );
  if (evidenceLocation != null &&
      !_evidenceLocation.hasMatch(evidenceLocation)) {
    _add(
      violations,
      'privacy_violation',
      location,
      'evidence location is not sanitized',
    );
  }
  _validateDefects(record, location, violations);
  _validatePrivacy(record['privacy'], location, violations);
  _validateBranchReviews(
    record['branch_reviews'],
    location,
    caseId,
    violations,
  );
  _validateAccessibility(record, location, caseId, violations);

  if (recordId == null ||
      caseId == null ||
      !_requiredCaseIds.contains(caseId) ||
      candidateManifestReference == null ||
      candidateTuple == null) {
    return null;
  }
  return _ParsedRecord(
    recordId: recordId,
    caseId: caseId,
    candidateManifestReference: candidateManifestReference,
    candidateTuple: candidateTuple,
    location: location,
  );
}

_CandidateManifestReference? _validateCandidateManifestReference(
  Map<String, Object?> reference,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  const keys = <String>{'candidate_id', 'sha256', 'bytes'};
  _validateKeys(reference, keys, keys, location, violations);
  final candidateId = _requiredString(
    reference,
    'candidate_id',
    location,
    violations,
  );
  final manifestSha256 = _requiredString(
    reference,
    'sha256',
    location,
    violations,
  );
  final manifestBytes = reference['bytes'];
  if (candidateId != null && !_candidateId.hasMatch(candidateId)) {
    _add(
      violations,
      'invalid_candidate_manifest_reference',
      location,
      'candidate manifest identifier is invalid',
    );
  }
  if (manifestSha256 != null && !_sha256.hasMatch(manifestSha256)) {
    _add(
      violations,
      'invalid_candidate_manifest_reference',
      location,
      'candidate manifest SHA-256 is invalid',
    );
  }
  if (manifestBytes is! int || manifestBytes < 1) {
    _add(
      violations,
      'invalid_candidate_manifest_reference',
      location,
      'candidate manifest byte count is invalid',
    );
  }
  if (candidateId == null ||
      !_candidateId.hasMatch(candidateId) ||
      manifestSha256 == null ||
      !_sha256.hasMatch(manifestSha256) ||
      manifestBytes is! int ||
      manifestBytes < 1) {
    return null;
  }
  return _CandidateManifestReference(
    candidateId: candidateId,
    sha256: manifestSha256,
    bytes: manifestBytes,
  );
}

Map<String, String>? _validateCandidate(
  Map<String, Object?> candidate,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  _validateKeys(
    candidate,
    _candidateKeys,
    _candidateKeys,
    location,
    violations,
  );
  final values = <String, String>{};
  for (final key in _candidateKeys) {
    final value = _requiredString(candidate, key, location, violations);
    if (value != null) values[key] = value;
  }
  if (values.length != _candidateKeys.length) return null;

  if (!_gitSha.hasMatch(values['mobile_source_sha']!) ||
      !_gitSha.hasMatch(values['backend_source_sha']!)) {
    _add(
      violations,
      'invalid_candidate_identity',
      location,
      'source SHA is invalid',
    );
  }
  if (!_sha256.hasMatch(values['mobile_apk_sha256']!)) {
    _add(
      violations,
      'invalid_candidate_identity',
      location,
      'APK SHA-256 is invalid',
    );
  }
  if (!_artifactIdentity.hasMatch(values['backend_artifact_identity']!)) {
    _add(
      violations,
      'invalid_candidate_identity',
      location,
      'backend artifact identity is invalid',
    );
  }
  if (!_environmentIdentity.hasMatch(values['environment_identity']!)) {
    _add(
      violations,
      'privacy_violation',
      location,
      'environment identity is not sanitized',
    );
  }
  if (values['provider_mode'] != 'REAL') {
    _add(
      violations,
      'inauthentic_provider',
      location,
      'provider mode must be REAL',
    );
  }
  if (!_providerProfile.hasMatch(values['provider_profile']!) ||
      _forbiddenProviderTerm.hasMatch(values['provider_profile']!)) {
    _add(
      violations,
      'invalid_provider_profile',
      location,
      'provider profile is not sanitized',
    );
  }
  if (!_modelIdentity.hasMatch(values['provider_model_identity']!)) {
    _add(
      violations,
      'invalid_provider_profile',
      location,
      'provider model identity is not sanitized',
    );
  }
  if (!_configurationFingerprint.hasMatch(
    values['configuration_fingerprint']!,
  )) {
    _add(
      violations,
      'invalid_candidate_identity',
      location,
      'configuration fingerprint is invalid',
    );
  }
  return values;
}

void _validateDevice(
  Map<String, Object?> device,
  String location,
  String? caseId,
  List<M212ReleaseMatrixViolation> violations,
) {
  const expected = <String>{
    'device_class',
    'android_version',
    'talkback_version',
  };
  _validateKeys(device, expected, expected, location, violations);
  final deviceClass = _requiredString(
    device,
    'device_class',
    location,
    violations,
  );
  final androidVersion = _requiredString(
    device,
    'android_version',
    location,
    violations,
  );
  final talkbackVersion = _requiredString(
    device,
    'talkback_version',
    location,
    violations,
  );
  if (deviceClass != null && !_safeDescriptor.hasMatch(deviceClass)) {
    _add(
      violations,
      'privacy_violation',
      location,
      'device identity is not sanitized',
    );
  }
  if (androidVersion != null && !_version.hasMatch(androidVersion)) {
    _add(violations, 'invalid_device', location, 'Android version is invalid');
  }
  if (caseId == 'talkback_human_accessibility') {
    if (talkbackVersion == null || !_version.hasMatch(talkbackVersion)) {
      _add(
        violations,
        'accessibility_human_evidence',
        location,
        'TalkBack version is required',
      );
    }
  } else if (talkbackVersion != null &&
      talkbackVersion != 'NOT_APPLICABLE' &&
      !_version.hasMatch(talkbackVersion)) {
    _add(violations, 'invalid_device', location, 'TalkBack version is invalid');
  }
}

void _validateAuthenticity(
  Map<String, Object?> authenticity,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  const expected = <String>{
    'execution',
    'provider_path',
    'llm_provider',
    'tts_provider',
  };
  _validateKeys(authenticity, expected, expected, location, violations);
  final expectedValues = <String, String>{
    'execution': 'HUMAN_ANDROID',
    'provider_path': 'FORMAL_PRODUCTION',
    'llm_provider': 'REAL',
    'tts_provider': 'REAL',
  };
  expectedValues.forEach((key, expectedValue) {
    final value = _requiredString(authenticity, key, location, violations);
    if (value != null && value != expectedValue) {
      _add(
        violations,
        'inauthentic_execution',
        location,
        '$key must be $expectedValue',
      );
    }
  });
}

void _validatePrerequisites(
  Object? value,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  final prerequisites = _list(value);
  if (prerequisites == null || prerequisites.isEmpty) {
    _add(
      violations,
      'incomplete_record',
      location,
      'prerequisites are required',
    );
    return;
  }
  final ids = <String>{};
  for (final prerequisite in prerequisites) {
    final item = _object(prerequisite);
    if (item == null) {
      _add(
        violations,
        'invalid_prerequisite',
        location,
        'prerequisite must be an object',
      );
      continue;
    }
    const expected = <String>{'id', 'status'};
    _validateKeys(item, expected, expected, location, violations);
    final id = _requiredString(item, 'id', location, violations);
    final status = _requiredString(item, 'status', location, violations);
    if (id != null && (!_safeLabel.hasMatch(id) || !ids.add(id))) {
      _add(
        violations,
        'invalid_prerequisite',
        location,
        'prerequisite identifier is invalid',
      );
    }
    if (status != null && status != 'PASS') {
      _add(
        violations,
        'incomplete_record',
        location,
        'prerequisite status must be PASS',
      );
    }
  }
}

void _validateSteps(
  Object? value,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  final steps = _list(value);
  if (steps == null || steps.isEmpty) {
    _add(
      violations,
      'incomplete_record',
      location,
      'ordered steps are required',
    );
    return;
  }
  for (var index = 0; index < steps.length; index += 1) {
    final step = _object(steps[index]);
    if (step == null) {
      _add(violations, 'invalid_step', location, 'step must be an object');
      continue;
    }
    const expected = <String>{
      'index',
      'action',
      'expected',
      'actual',
      'status',
    };
    _validateKeys(step, expected, expected, location, violations);
    if (step['index'] != index + 1) {
      _add(
        violations,
        'invalid_step',
        location,
        'steps must be ordered without gaps',
      );
    }
    for (final field in <String>['action', 'expected', 'actual']) {
      final text = _requiredString(step, field, location, violations);
      if (text != null && !_safeLabel.hasMatch(text)) {
        _add(
          violations,
          'privacy_violation',
          location,
          '$field must be a controlled label',
        );
      }
    }
    final status = _requiredString(step, 'status', location, violations);
    if (status != null && status != 'PASS') {
      _add(
        violations,
        'incomplete_record',
        location,
        'step status must be PASS',
      );
    }
  }
}

void _validateDefects(
  Map<String, Object?> record,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  final defects = _list(record['defects']);
  final retestOutcome = _requiredString(
    record,
    'retest_outcome',
    location,
    violations,
  );
  if (defects == null) {
    _add(violations, 'incomplete_record', location, 'defects must be a list');
    return;
  }
  if (defects.isEmpty) {
    if (retestOutcome != null && retestOutcome != 'NOT_REQUIRED') {
      _add(
        violations,
        'invalid_retest',
        location,
        'retest outcome must be NOT_REQUIRED',
      );
    }
    return;
  }
  if (retestOutcome != null && retestOutcome != 'PASS') {
    _add(
      violations,
      'open_defect',
      location,
      'open defect or unresolved retest outcome',
    );
  }
  for (final defectValue in defects) {
    final defect = _object(defectValue);
    if (defect == null) {
      _add(
        violations,
        'open_defect',
        location,
        'defect must be structured and closed',
      );
      continue;
    }
    const expected = <String>{'id', 'status', 'retest_outcome'};
    _validateKeys(defect, expected, expected, location, violations);
    final id = _requiredString(defect, 'id', location, violations);
    final status = _requiredString(defect, 'status', location, violations);
    final retest = _requiredString(
      defect,
      'retest_outcome',
      location,
      violations,
    );
    if (id != null && !_defectId.hasMatch(id)) {
      _add(
        violations,
        'privacy_violation',
        location,
        'defect identifier is not opaque',
      );
    }
    if (status != 'CLOSED' || retest != 'PASS') {
      _add(
        violations,
        'open_defect',
        location,
        'open defect or unresolved retest outcome',
      );
    }
  }
}

void _validatePrivacy(
  Object? value,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  final privacy = _object(value);
  const expected = <String>{
    'raw_content_stored',
    'raw_evidence_stored',
    'sensitive_identifiers_stored',
    'sanitized',
  };
  if (privacy == null) {
    _add(
      violations,
      'privacy_violation',
      location,
      'privacy declaration is required',
    );
    return;
  }
  _validateKeys(privacy, expected, expected, location, violations);
  if (privacy['raw_content_stored'] != false ||
      privacy['raw_evidence_stored'] != false ||
      privacy['sensitive_identifiers_stored'] != false ||
      privacy['sanitized'] != true) {
    _add(
      violations,
      'privacy_violation',
      location,
      'privacy declaration is not safe',
    );
  }
}

void _validateBranchReviews(
  Object? value,
  String location,
  String? caseId,
  List<M212ReleaseMatrixViolation> violations,
) {
  final reviews = _list(value);
  if (reviews == null) {
    _add(
      violations,
      'incomplete_record',
      location,
      'branch reviews must be a list',
    );
    return;
  }
  if (caseId != 'all_reaction_audio_branches') {
    if (reviews.isNotEmpty) {
      _add(
        violations,
        'invalid_branch_reviews',
        location,
        'branch reviews belong only to audio case',
      );
    }
    return;
  }
  final branches = <String>{};
  for (final reviewValue in reviews) {
    final review = _object(reviewValue);
    if (review == null) {
      _add(
        violations,
        'invalid_branch_reviews',
        location,
        'branch review must be an object',
      );
      continue;
    }
    const expected = <String>{
      'branch',
      'scene_match',
      'reaction_match',
      'low_pressure_language',
      'directly_speakable',
      'audio_matches_displayed_branch',
      'reviewer_verdict',
    };
    _validateKeys(review, expected, expected, location, violations);
    final branch = _requiredString(review, 'branch', location, violations);
    if (branch != null &&
        (!_requiredBranches.contains(branch) || !branches.add(branch))) {
      _add(
        violations,
        'invalid_branch_reviews',
        location,
        'branch review is missing or duplicate',
      );
    }
    for (final field in expected.where((field) => field != 'branch')) {
      final verdict = _requiredString(review, field, location, violations);
      if (verdict != null && verdict != 'PASS') {
        _add(
          violations,
          'non_passing_branch_review',
          location,
          'branch review must be PASS',
        );
      }
    }
  }
  if (branches.length != _requiredBranches.length ||
      !branches.containsAll(_requiredBranches)) {
    _add(
      violations,
      'incomplete_record',
      location,
      'all starter and reaction branch reviews are required',
    );
  }
}

void _validateAccessibility(
  Map<String, Object?> record,
  String location,
  String? caseId,
  List<M212ReleaseMatrixViolation> violations,
) {
  final value = record['accessibility'];
  if (caseId != 'talkback_human_accessibility') {
    if (value != null) {
      _add(
        violations,
        'invalid_accessibility',
        location,
        'accessibility evidence belongs only to TalkBack case',
      );
    }
    return;
  }
  final accessibility = _object(value);
  const expected = <String>{'method', 'observations'};
  if (accessibility == null) {
    _add(
      violations,
      'accessibility_human_evidence',
      location,
      'human TalkBack evidence is required',
    );
    return;
  }
  _validateKeys(accessibility, expected, expected, location, violations);
  if (accessibility['method'] != 'HUMAN_HEARD_TOUCH_EXPLORATION') {
    _add(
      violations,
      'accessibility_human_evidence',
      location,
      'human TalkBack evidence is required',
    );
  }
  final observations = _list(accessibility['observations']);
  const expectedObservations = <String>{
    'spoken_order',
    'touch_exploration',
    'labels',
    'cta_error_retry_announcements',
    'return_focus',
  };
  if (observations == null ||
      observations.whereType<String>().toSet().length != observations.length ||
      observations.whereType<String>().toSet().length !=
          expectedObservations.length ||
      !observations.whereType<String>().toSet().containsAll(
        expectedObservations,
      )) {
    _add(
      violations,
      'accessibility_human_evidence',
      location,
      'human TalkBack observations are incomplete',
    );
  }
}

void _validateCaseCompleteness(
  List<_ParsedRecord> records,
  List<M212ReleaseMatrixViolation> violations,
) {
  final counts = <String, int>{};
  final recordIds = <String, int>{};
  for (final record in records) {
    counts.update(record.caseId, (count) => count + 1, ifAbsent: () => 1);
    recordIds.update(record.recordId, (count) => count + 1, ifAbsent: () => 1);
  }
  for (final caseId in _requiredCaseIds) {
    if (!counts.containsKey(caseId)) {
      _add(
        violations,
        'incomplete_cases',
        'records',
        'missing required UAT case: $caseId',
      );
    }
  }
  for (final record in records) {
    if (counts[record.caseId]! > 1) {
      _add(
        violations,
        'duplicate_case',
        record.location,
        'duplicate required UAT case',
      );
    }
    if (recordIds[record.recordId]! > 1) {
      _add(
        violations,
        'duplicate_record',
        record.location,
        'duplicate UAT record identifier',
      );
    }
  }
}

void _validateCandidateIdentity(
  List<_ParsedRecord> records,
  List<M212ReleaseMatrixViolation> violations,
) {
  if (records.isEmpty) return;
  final baseline = records.first.candidateTuple;
  for (final record in records.skip(1)) {
    if (!_candidateKeys.every(
      (key) => record.candidateTuple[key] == baseline[key],
    )) {
      _add(
        violations,
        'candidate_identity_mismatch',
        record.location,
        'candidate identity mismatch',
      );
    }
  }
}

_FrozenCandidate? _loadFrozenCandidate({
  required String root,
  required String? candidateManifestPath,
  required List<M212ReleaseMatrixViolation> violations,
}) {
  if (candidateManifestPath == null) {
    _add(
      violations,
      'missing_manifest',
      'manifest',
      'frozen candidate manifest is missing',
    );
    return null;
  }
  final configured = File(candidateManifestPath).isAbsolute
      ? candidateManifestPath
      : '$root/$candidateManifestPath';
  final file = File(configured);
  if (!file.existsSync()) {
    _add(
      violations,
      'missing_manifest',
      'manifest',
      'frozen candidate manifest is missing',
    );
    return null;
  }

  List<int> bytes;
  try {
    bytes = file.readAsBytesSync();
  } on FileSystemException {
    _add(
      violations,
      'unreadable_manifest',
      'manifest',
      'frozen candidate manifest cannot be read',
    );
    return null;
  }
  final closureReport = closure_candidate.scanM213ClosureCandidate(
    manifestPath: file.path,
  );
  if (!closureReport.passes || closureReport.manifest == null) {
    _add(
      violations,
      'invalid_manifest',
      'manifest',
      'frozen candidate manifest is invalid',
    );
    return null;
  }

  final tuple = <String, String>{};
  for (final key in _candidateKeys) {
    final value = closureReport.manifest!.candidate[key];
    if (value == null) {
      _add(
        violations,
        'invalid_manifest',
        'manifest',
        'frozen candidate tuple is incomplete',
      );
      return null;
    }
    tuple[key] = key == 'provider_mode' ? value.toUpperCase() : value;
  }
  return _FrozenCandidate(
    candidateId: closureReport.manifest!.candidateId,
    sha256: sha256.convert(bytes).toString(),
    bytes: bytes.length,
    candidateTuple: tuple,
  );
}

void _validateFrozenCandidate(
  List<_ParsedRecord> records,
  _FrozenCandidate frozenCandidate,
  List<M212ReleaseMatrixViolation> violations,
) {
  for (final record in records) {
    final reference = record.candidateManifestReference;
    if (reference.candidateId != frozenCandidate.candidateId ||
        reference.sha256 != frozenCandidate.sha256 ||
        reference.bytes != frozenCandidate.bytes) {
      _add(
        violations,
        'candidate_manifest_reference_mismatch',
        record.location,
        'record does not reference supplied manifest bytes',
      );
    }
    if (!_candidateKeys.every(
      (key) =>
          record.candidateTuple[key] == frozenCandidate.candidateTuple[key],
    )) {
      _add(
        violations,
        'frozen_candidate_mismatch',
        record.location,
        'candidate does not match frozen manifest',
      );
    }
  }
}

void _validateKeys(
  Map<String, Object?> value,
  Set<String> required,
  Set<String> allowed,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      _add(
        violations,
        'privacy_violation',
        location,
        'unapproved record field is forbidden',
      );
    }
  }
  for (final key in required) {
    if (!value.containsKey(key)) {
      _add(
        violations,
        'missing_field',
        location,
        'missing required field: $key',
      );
    }
  }
}

String? _requiredString(
  Map<String, Object?> value,
  String field,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  final text = value[field];
  if (text is String && text.isNotEmpty) return text;
  if (value.containsKey(field)) {
    _add(
      violations,
      'invalid_field',
      location,
      '$field must be a non-empty string',
    );
  }
  return null;
}

Map<String, Object?>? _requiredObject(
  Map<String, Object?> value,
  String field,
  String location,
  List<M212ReleaseMatrixViolation> violations,
) {
  final object = _object(value[field]);
  if (object != null) return object;
  if (value.containsKey(field)) {
    _add(violations, 'invalid_field', location, '$field must be an object');
  }
  return null;
}

Map<String, Object?>? _object(Object? value) {
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?>? _list(Object? value) {
  if (value is! List) return null;
  return List<Object?>.from(value);
}

void _add(
  List<M212ReleaseMatrixViolation> violations,
  String code,
  String recordLocation,
  String detail,
) {
  violations.add(
    M212ReleaseMatrixViolation(
      code: code,
      recordLocation: recordLocation,
      detail: detail,
    ),
  );
}

String _safeFileLabel(File file) => file.uri.pathSegments.last;

String _normalize(String value) => value.replaceAll('\\', '/');

final _gitSha = RegExp(r'^[a-f0-9]{40}(?:[a-f0-9]{24})?$');
final _sha256 = RegExp(r'^[a-f0-9]{64}$');
final _artifactIdentity = RegExp(r'^(?:image|build)_sha256:[a-f0-9]{64}$');
final _configurationFingerprint = RegExp(r'^sha256:[a-f0-9]{64}$');
final _environmentIdentity = RegExp(r'^sanitized-[a-z0-9][a-z0-9-]{2,100}$');
final _providerProfile = RegExp(r'^[a-z][a-z0-9-]{2,100}$');
final _forbiddenProviderTerm = RegExp(
  r'(?:^|-)(?:dev|fake|fixture|mock|test|loopback)(?:-|$)',
);
final _modelIdentity = RegExp(r'^model_sha256:[a-f0-9]{64}$');
final _opaqueId = RegExp(r'^[a-z][a-z0-9_]{2,100}$');
final _candidateId = RegExp(r'^m2-final-[a-z0-9-]{3,100}$');
final _executor = RegExp(r'^role:[a-z][a-z0-9_-]{2,63}$');
final _rfc3339 = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})$',
);
final _timezone = RegExp(r'^[A-Za-z]+/[A-Za-z_]+$');
final _safeLabel = RegExp(r'^[a-z][a-z0-9_]{1,100}$');
final _safeDescriptor = RegExp(r'^[a-z][a-z0-9_-]{1,100}$');
final _version = RegExp(r'^\d+(?:\.\d+){0,2}$');
final _evidenceLocation = RegExp(r'^reviewed://[a-z0-9][a-z0-9_/-]{2,160}$');
final _defectId = RegExp(r'^DEF-[0-9]+$');

class _ParsedRecord {
  const _ParsedRecord({
    required this.recordId,
    required this.caseId,
    required this.candidateManifestReference,
    required this.candidateTuple,
    required this.location,
  });

  final String recordId;
  final String caseId;
  final _CandidateManifestReference candidateManifestReference;
  final Map<String, String> candidateTuple;
  final String location;
}

class _CandidateManifestReference {
  const _CandidateManifestReference({
    required this.candidateId,
    required this.sha256,
    required this.bytes,
  });

  final String candidateId;
  final String sha256;
  final int bytes;
}

class _FrozenCandidate {
  const _FrozenCandidate({
    required this.candidateId,
    required this.sha256,
    required this.bytes,
    required this.candidateTuple,
  });

  final String candidateId;
  final String sha256;
  final int bytes;
  final Map<String, String> candidateTuple;
}

class _M212CliOptions {
  const _M212CliOptions({
    required this.recordsPath,
    required this.manifestPath,
    required this.showHelp,
    required this.usageError,
  });

  final String? recordsPath;
  final String? manifestPath;
  final bool showHelp;
  final String? usageError;

  factory _M212CliOptions.parse(List<String> args) {
    String? recordsPath;
    String? manifestPath;
    var showHelp = false;
    String? usageError;
    for (var index = 0; index < args.length; index += 1) {
      switch (args[index]) {
        case '--help':
        case '-h':
          showHelp = true;
          break;
        case '--records':
          if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
            usageError = '--records requires a directory';
          } else {
            recordsPath = args[++index];
          }
          break;
        case '--manifest':
          if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
            usageError = '--manifest requires a path';
          } else {
            manifestPath = args[++index];
          }
          break;
        default:
          usageError = 'Unknown argument: ${args[index]}';
      }
    }
    return _M212CliOptions(
      recordsPath: recordsPath,
      manifestPath: manifestPath,
      showHelp: showHelp,
      usageError:
          usageError ??
          (showHelp || manifestPath != null
              ? null
              : '--manifest is required for closure verification'),
    );
  }
}

Future<void> main(List<String> args) async {
  final options = _M212CliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(m212ReleaseMatrixUsage);
    return;
  }
  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(m212ReleaseMatrixUsage);
    exit(64);
  }
  final report = scanM212ReleaseMatrix(
    uatRecordsPath: options.recordsPath,
    candidateManifestPath: options.manifestPath,
  );
  stdout.write(renderM212ReleaseMatrixReport(report));
  if (!report.passes) exit(1);
  stdout.writeln(m212ReleaseMatrixSuccessMarker);
}
