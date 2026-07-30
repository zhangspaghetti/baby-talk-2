import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const m213ClosureCandidateSuccessMarker =
    'M2-13 final candidate is frozen for UAT.';

const m213ClosureCandidateSchemaVersion = 'M2_FINAL_CANDIDATE_V1';

const m213ClosureCandidateUsage =
    '''Usage: dart tool/verify_m2_13_closure_candidate.dart --manifest <path> [--help]

Validates one frozen final-candidate manifest, confirms its source tuple is the
checked-out clean candidate, then runs every upstream #30-#38 closure gate.
The accepted manifest is the only input contract for final UAT.
''';

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

const _requiredTopLevelKeys = <String>{
  'schema_version',
  'candidate_id',
  'frozen_at',
  'candidate',
  'closure_matrix',
  'final_uat_input',
  'privacy',
};

const _requiredGateReceiptKeys = <String>{'gate_id', 'status', 'evidence_ref'};

const closureGateIds = <String>[
  'complete_bundle',
  'activation_safety_repair',
  'legacy_quarantine',
  'recovery_coordinator',
  'handoff_confirmation',
  'backend_real_tts',
  'mobile_formal_audio',
  'garden_today_continuity',
  'privacy',
  'static_source',
  'release_evidence_schema',
  'clean_worktree',
  'full_ci',
];

final _gitSha = RegExp(r'^[a-f0-9]{40}(?:[a-f0-9]{24})?$');
final _sha256 = RegExp(r'^[a-f0-9]{64}$');
final _artifactIdentity = RegExp(r'^(?:image|build)_sha256:[a-f0-9]{64}$');
final _environmentIdentity = RegExp(r'^sanitized-[a-z0-9][a-z0-9-]{2,100}$');
final _providerProfile = RegExp(r'^[a-z][a-z0-9-]{2,100}$');
final _modelIdentity = RegExp(r'^model_sha256:[a-f0-9]{64}$');
final _configurationFingerprint = RegExp(r'^sha256:[a-f0-9]{64}$');
final _candidateId = RegExp(r'^m2-final-[a-z0-9-]{3,100}$');
final _rfc3339 = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})$',
);
final _evidenceRef = RegExp(r'^reviewed://closure/[a-z0-9_-]{3,100}$');

class M213ClosureCandidateViolation {
  const M213ClosureCandidateViolation(this.code, this.detail);

  final String code;
  final String detail;

  @override
  String toString() => '$code | $detail';
}

class M213ClosureCandidateManifest {
  const M213ClosureCandidateManifest({
    required this.candidate,
    required this.gateIds,
  });

  final Map<String, String> candidate;
  final Set<String> gateIds;
}

class M213ClosureCandidateReport {
  const M213ClosureCandidateReport({
    required this.violations,
    required this.manifest,
  });

  final List<M213ClosureCandidateViolation> violations;
  final M213ClosureCandidateManifest? manifest;

  bool get passes => violations.isEmpty;
}

M213ClosureCandidateReport scanM213ClosureCandidate({
  required String manifestPath,
}) {
  final violations = <M213ClosureCandidateViolation>[];
  final file = File(manifestPath);
  if (!file.existsSync()) {
    return M213ClosureCandidateReport(
      violations: const [
        M213ClosureCandidateViolation(
          'missing_manifest',
          'manifest file missing',
        ),
      ],
      manifest: null,
    );
  }

  final value = _readJson(file, violations);
  final root = _object(value);
  if (root == null) {
    _add(violations, 'invalid_manifest', 'manifest root must be a JSON object');
    return M213ClosureCandidateReport(violations: violations, manifest: null);
  }

  _validateKeys(root, _requiredTopLevelKeys, _requiredTopLevelKeys, violations);
  if (root['schema_version'] != m213ClosureCandidateSchemaVersion) {
    _add(
      violations,
      'schema_version',
      'schema_version must be $m213ClosureCandidateSchemaVersion',
    );
  }
  final candidateId = _string(root['candidate_id']);
  if (candidateId == null || !_candidateId.hasMatch(candidateId)) {
    _add(
      violations,
      'candidate_id',
      'candidate_id must be a final-candidate identifier',
    );
  }
  final frozenAt = _string(root['frozen_at']);
  if (frozenAt == null || !_rfc3339.hasMatch(frozenAt)) {
    _add(violations, 'frozen_at', 'frozen_at must be RFC3339 with timezone');
  }

  final candidate = _validateCandidate(root['candidate'], violations);
  final gateIds = _validateClosureMatrix(root['closure_matrix'], violations);
  _validateFinalUatInput(root['final_uat_input'], violations);
  _validatePrivacy(root['privacy'], violations);

  violations.sort((left, right) => left.code.compareTo(right.code));
  return M213ClosureCandidateReport(
    violations: List.unmodifiable(violations),
    manifest: violations.isEmpty && candidate != null
        ? M213ClosureCandidateManifest(candidate: candidate, gateIds: gateIds)
        : null,
  );
}

String renderM213ClosureCandidateReport(M213ClosureCandidateReport report) {
  final buffer = StringBuffer()
    ..writeln(
      'm2_13_closure_candidate_status=${report.passes ? 'pass' : 'fail'}',
    )
    ..writeln('violations=${report.violations.length}');
  for (final violation in report.violations) {
    buffer.writeln('  $violation');
  }
  return buffer.toString();
}

Map<String, String>? _validateCandidate(
  Object? value,
  List<M213ClosureCandidateViolation> violations,
) {
  final candidate = _object(value);
  if (candidate == null) {
    _add(violations, 'candidate', 'candidate must be a JSON object');
    return null;
  }
  _validateKeys(candidate, _candidateKeys, _candidateKeys, violations);
  final fields = <String, String>{};
  for (final key in _candidateKeys) {
    final text = _string(candidate[key]);
    if (text == null) {
      _add(violations, 'candidate', '$key must be a non-empty string');
    } else {
      fields[key] = text;
    }
  }
  if (fields.length != _candidateKeys.length) return null;
  if (!_gitSha.hasMatch(fields['mobile_source_sha']!)) {
    _add(violations, 'candidate', 'mobile_source_sha must be a git SHA');
  }
  if (!_sha256.hasMatch(fields['mobile_apk_sha256']!)) {
    _add(violations, 'candidate', 'mobile_apk_sha256 must be SHA-256');
  }
  if (!_gitSha.hasMatch(fields['backend_source_sha']!)) {
    _add(violations, 'candidate', 'backend_source_sha must be a git SHA');
  }
  if (!_artifactIdentity.hasMatch(fields['backend_artifact_identity']!)) {
    _add(
      violations,
      'candidate',
      'backend_artifact_identity must be image/build SHA-256',
    );
  }
  if (!_environmentIdentity.hasMatch(fields['environment_identity']!)) {
    _add(violations, 'candidate', 'environment_identity must be sanitized');
  }
  if (fields['provider_mode'] != 'real') {
    _add(violations, 'candidate', 'provider_mode must be real');
  }
  if (!_providerProfile.hasMatch(fields['provider_profile']!)) {
    _add(violations, 'candidate', 'provider_profile must be sanitized');
  }
  if (!_modelIdentity.hasMatch(fields['provider_model_identity']!)) {
    _add(violations, 'candidate', 'provider_model_identity must be hashed');
  }
  if (!_configurationFingerprint.hasMatch(
    fields['configuration_fingerprint']!,
  )) {
    _add(violations, 'candidate', 'configuration_fingerprint must be SHA-256');
  }
  return fields;
}

Set<String> _validateClosureMatrix(
  Object? value,
  List<M213ClosureCandidateViolation> violations,
) {
  final matrix = _list(value);
  final gateIds = <String>{};
  if (matrix == null) {
    _add(violations, 'closure_matrix', 'closure_matrix must be a list');
    return gateIds;
  }
  for (final entry in matrix) {
    final receipt = _object(entry);
    if (receipt == null) {
      _add(violations, 'closure_matrix', 'gate receipt must be an object');
      continue;
    }
    _validateKeys(
      receipt,
      _requiredGateReceiptKeys,
      _requiredGateReceiptKeys,
      violations,
    );
    final id = _string(receipt['gate_id']);
    if (id == null || !closureGateIds.contains(id) || !gateIds.add(id)) {
      _add(
        violations,
        'closure_matrix',
        'gate_id must be one unique known closure gate',
      );
    }
    final status = _string(receipt['status']);
    if (status != 'PASS') {
      _add(
        violations,
        'non_passing_gate',
        'gate ${id ?? 'unknown'} status must be PASS; FAIL/BLOCKED/NOT RUN never pass',
      );
    }
    final evidenceRef = _string(receipt['evidence_ref']);
    if (evidenceRef == null || !_evidenceRef.hasMatch(evidenceRef)) {
      _add(
        violations,
        'closure_matrix',
        'gate evidence_ref must be reviewed://closure/...',
      );
    }
  }
  if (gateIds.length != closureGateIds.length ||
      !gateIds.containsAll(closureGateIds)) {
    _add(
      violations,
      'closure_matrix',
      'closure_matrix must contain every #30-#38, clean-worktree, and full-CI gate exactly once',
    );
  }
  return gateIds;
}

void _validateFinalUatInput(
  Object? value,
  List<M213ClosureCandidateViolation> violations,
) {
  final input = _object(value);
  const keys = <String>{'only_allowed_input', 'schema_version'};
  if (input == null) {
    _add(violations, 'final_uat_input', 'final_uat_input is required');
    return;
  }
  _validateKeys(input, keys, keys, violations);
  if (input['only_allowed_input'] != true ||
      input['schema_version'] != m213ClosureCandidateSchemaVersion) {
    _add(
      violations,
      'final_uat_input',
      'final UAT accepts only this candidate manifest schema',
    );
  }
}

void _validatePrivacy(
  Object? value,
  List<M213ClosureCandidateViolation> violations,
) {
  final privacy = _object(value);
  const keys = <String>{
    'raw_content_stored',
    'raw_evidence_stored',
    'sensitive_identifiers_stored',
    'sanitized',
  };
  if (privacy == null) {
    _add(violations, 'privacy', 'privacy declaration is required');
    return;
  }
  _validateKeys(privacy, keys, keys, violations);
  if (privacy['raw_content_stored'] != false ||
      privacy['raw_evidence_stored'] != false ||
      privacy['sensitive_identifiers_stored'] != false ||
      privacy['sanitized'] != true) {
    _add(violations, 'privacy', 'privacy declaration is not safe');
  }
}

class ClosureCommand {
  const ClosureCommand(
    this.executable,
    this.arguments,
    this.workingDirectory, {
    this.requireEmptyStdout = false,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final bool requireEmptyStdout;
}

class M213ClosureGate {
  const M213ClosureGate(this.id, this.commands);

  final String id;
  final List<ClosureCommand> commands;
}

const m213ClosureGates = <M213ClosureGate>[
  M213ClosureGate('clean_worktree', [
    ClosureCommand(
      'git',
      ['status', '--porcelain'],
      '.',
      requireEmptyStdout: true,
    ),
  ]),
  M213ClosureGate('complete_bundle', [
    ClosureCommand('bash', [
      'mvnw',
      '-pl',
      'app-api',
      '-Dtest=CompleteGeneratedBundleContractTest,GeneratedCareMomentBundleTest,PracticeGeneratedContentMapperContractTest',
      'test',
    ], 'backend'),
  ]),
  M213ClosureGate('activation_safety_repair', [
    ClosureCommand('bash', [
      'mvnw',
      '-pl',
      'app-api',
      '-Dtest=CustomSceneGenerationOrchestratorTest,PracticeGeneratedContentServiceOrchestrationTest,PracticeGeneratedContentStateMachineTest,CustomSceneGeneratedContentValidatorTest,JudgeVerdictCalculatorTest',
      'test',
    ], 'backend'),
  ]),
  M213ClosureGate('legacy_quarantine', [
    ClosureCommand('flutter', [
      'test',
      'test/features/practice/generated/generated_practice_content_registry_test.dart',
    ], 'mobile'),
  ]),
  M213ClosureGate('recovery_coordinator', [
    ClosureCommand('flutter', [
      'test',
      'test/app/custom_scene_recovery_coordinator_test.dart',
      'test/features/custom_scene/custom_scene_draft_continuation_test.dart',
    ], 'mobile'),
  ]),
  M213ClosureGate('handoff_confirmation', [
    ClosureCommand('flutter', [
      'test',
      'test/features/custom_scene/custom_scene_handoff_confirmation_coordinator_test.dart',
      'test/features/practice/generated_care_turn_handoff_readiness_test.dart',
    ], 'mobile'),
  ]),
  M213ClosureGate('backend_real_tts', [
    ClosureCommand('bash', [
      'mvnw',
      '-pl',
      'app-api',
      '-Dtest=GeneratedUtteranceAudioServiceTest,GeneratedSpeechSynthesisConfigurationTest,ConfiguredGeneratedSpeechProviderTest,GeneratedUtteranceAudioControllerTest',
      'test',
    ], 'backend'),
  ]),
  M213ClosureGate('mobile_formal_audio', [
    ClosureCommand('flutter', [
      'test',
      'test/features/care_path/presentation/care_audio_playback_controller_test.dart',
      'test/features/practice/generated/generated_audio_memory_cache_test.dart',
      'test/features/practice/generated/generated_audio_api_test.dart',
    ], 'mobile'),
  ]),
  M213ClosureGate('garden_today_continuity', [
    ClosureCommand('dart', [
      'tool/verify_m2_generated_reaction_contract.dart',
    ], '.'),
    ClosureCommand('flutter', [
      'test',
      'test/features/practice/interaction_event_payload_test.dart',
      'test/features/practice/generated/generated_practice_content_registry_test.dart',
    ], 'mobile'),
  ]),
  M213ClosureGate('privacy', [
    ClosureCommand('python3', [
      'tool/verify_practice_generation_privacy.py',
    ], '.'),
    ClosureCommand('dart', ['tool/verify_m2_11_custom_scene_gates.dart'], '.'),
  ]),
  M213ClosureGate('static_source', [
    ClosureCommand('python3', [
      'tool/verify_spring_ai_2_backend_platform.py',
    ], '.'),
  ]),
  M213ClosureGate('release_evidence_schema', [
    ClosureCommand('flutter', [
      'test',
      'test/tool/verify_m2_12_release_matrix_test.dart',
    ], '.'),
  ]),
  M213ClosureGate('full_ci', [
    ClosureCommand('bash', ['ci/full-ci.sh'], '.'),
  ]),
];

class ClosureCommandResult {
  const ClosureCommandResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}

class ClosureCommandExecution {
  const ClosureCommandExecution({
    required this.executable,
    required this.runInShell,
  });

  final String executable;
  final bool runInShell;
}

typedef ClosureCommandExecutor =
    Future<ClosureCommandResult> Function(
      M213ClosureGate gate,
      ClosureCommand command,
      String projectRoot,
    );

class M213ClosureGateRunReport {
  const M213ClosureGateRunReport(this.failedGate, this.detail);

  final String? failedGate;
  final String? detail;
  bool get passes => failedGate == null;
}

Future<M213ClosureGateRunReport> runM213ClosureGates({
  required String projectRoot,
  ClosureCommandExecutor? commandExecutor,
}) async {
  final run = commandExecutor ?? _runProcess;
  for (final gate in m213ClosureGates) {
    for (var commandIndex = 0;
        commandIndex < gate.commands.length;
        commandIndex += 1) {
      final command = gate.commands[commandIndex];
      final result = await run(gate, command, projectRoot);
      if (result.exitCode != 0) {
        return M213ClosureGateRunReport(
          gate.id,
          _nonzeroCommandDiagnostic(gate.id, commandIndex, result),
        );
      }
      if (command.requireEmptyStdout && result.stdout.trim().isNotEmpty) {
        return M213ClosureGateRunReport(
          gate.id,
          'worktree has uncommitted changes',
        );
      }
    }
  }
  return const M213ClosureGateRunReport(null, null);
}

String _nonzeroCommandDiagnostic(
  String gateId,
  int commandIndex,
  ClosureCommandResult result,
) {
  final stdoutBytes = utf8.encode(result.stdout);
  final stderrBytes = utf8.encode(result.stderr);
  return 'command_identity=$gateId:${commandIndex + 1} '
      'exit_code=${result.exitCode} '
      'stdout_bytes=${stdoutBytes.length} '
      'stdout_sha256=${sha256.convert(stdoutBytes)} '
      'stderr_bytes=${stderrBytes.length} '
      'stderr_sha256=${sha256.convert(stderrBytes)}';
}

ClosureCommandExecution resolveM213ClosureCommandExecution({
  required ClosureCommand command,
  required String projectRoot,
  bool? isWindows,
}) {
  final useWindowsWrapper = isWindows ?? Platform.isWindows;
  if (command.executable != 'bash' || !useWindowsWrapper) {
    return ClosureCommandExecution(
      executable: command.executable,
      runInShell: false,
    );
  }

  final wrapper = File(
    '${Directory(projectRoot).path}${Platform.pathSeparator}bash.cmd',
  );
  if (!wrapper.existsSync()) {
    return ClosureCommandExecution(
      executable: command.executable,
      runInShell: false,
    );
  }
  return ClosureCommandExecution(executable: wrapper.path, runInShell: true);
}

Future<ClosureCommandResult> _runProcess(
  M213ClosureGate gate,
  ClosureCommand command,
  String projectRoot,
) async {
  final execution = resolveM213ClosureCommandExecution(
    command: command,
    projectRoot: projectRoot,
  );
  final result = await Process.run(
    execution.executable,
    command.arguments,
    workingDirectory: Directory(
      '$projectRoot/${command.workingDirectory}',
    ).path,
    runInShell: execution.runInShell,
  );
  return ClosureCommandResult(
    result.exitCode,
    '${result.stdout}',
    '${result.stderr}',
  );
}

Future<List<M213ClosureCandidateViolation>> verifyM213CurrentCandidate(
  M213ClosureCandidateManifest manifest,
  String projectRoot,
) async {
  final result = await Process.run(
    'git',
    ['rev-parse', 'HEAD'],
    workingDirectory: projectRoot,
    runInShell: false,
  );
  if (result.exitCode != 0) {
    return const [
      M213ClosureCandidateViolation(
        'git_head',
        'cannot resolve checked-out candidate SHA',
      ),
    ];
  }
  final head = '${result.stdout}'.trim();
  if (manifest.candidate['mobile_source_sha'] != head ||
      manifest.candidate['backend_source_sha'] != head) {
    return const [
      M213ClosureCandidateViolation(
        'candidate_identity_mismatch',
        'manifest mobile/backend SHA must equal checked-out HEAD',
      ),
    ];
  }
  return const [];
}

Object? _readJson(File file, List<M213ClosureCandidateViolation> violations) {
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException {
    _add(violations, 'invalid_json', 'manifest is not valid JSON');
    return null;
  }
}

Map<String, Object?>? _object(Object? value) {
  if (value is! Map) return null;
  final object = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    object[entry.key as String] = entry.value;
  }
  return object;
}

List<Object?>? _list(Object? value) =>
    value is List ? List<Object?>.from(value) : null;

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

void _validateKeys(
  Map<String, Object?> object,
  Set<String> required,
  Set<String> allowed,
  List<M213ClosureCandidateViolation> violations,
) {
  for (final key in object.keys) {
    if (!allowed.contains(key))
      _add(violations, 'privacy_violation', 'unapproved field: $key');
  }
  for (final key in required) {
    if (!object.containsKey(key))
      _add(violations, 'missing_field', 'missing required field: $key');
  }
}

void _add(
  List<M213ClosureCandidateViolation> violations,
  String code,
  String detail,
) {
  violations.add(M213ClosureCandidateViolation(code, detail));
}

class _M213CliOptions {
  const _M213CliOptions(this.manifestPath, this.showHelp, this.usageError);

  final String? manifestPath;
  final bool showHelp;
  final String? usageError;

  factory _M213CliOptions.parse(List<String> args) {
    String? manifestPath;
    var showHelp = false;
    for (var index = 0; index < args.length; index += 1) {
      switch (args[index]) {
        case '--help':
        case '-h':
          showHelp = true;
          break;
        case '--manifest':
          if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
            return const _M213CliOptions(
              null,
              false,
              '--manifest requires a JSON file',
            );
          }
          manifestPath = args[++index];
          break;
        default:
          return _M213CliOptions(
            null,
            false,
            'unknown argument: ${args[index]}',
          );
      }
    }
    if (!showHelp && manifestPath == null) {
      return const _M213CliOptions(null, false, '--manifest is required');
    }
    return _M213CliOptions(manifestPath, showHelp, null);
  }
}

Future<void> main(List<String> args) async {
  final options = _M213CliOptions.parse(args);
  if (options.showHelp) {
    stdout.write(m213ClosureCandidateUsage);
    return;
  }
  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.write(m213ClosureCandidateUsage);
    exit(64);
  }
  final report = scanM213ClosureCandidate(manifestPath: options.manifestPath!);
  stdout.write(renderM213ClosureCandidateReport(report));
  if (!report.passes || report.manifest == null) exit(1);

  final root = Directory.current.path;
  final currentCandidateViolations = await verifyM213CurrentCandidate(
    report.manifest!,
    root,
  );
  if (currentCandidateViolations.isNotEmpty) {
    for (final violation in currentCandidateViolations) {
      stderr.writeln(violation);
    }
    exit(1);
  }
  final gateReport = await runM213ClosureGates(projectRoot: root);
  if (!gateReport.passes) {
    stderr.writeln(
      'closure_gate_failed=${gateReport.failedGate} | ${gateReport.detail}',
    );
    exit(1);
  }
  stdout.writeln(m213ClosureCandidateSuccessMarker);
}
