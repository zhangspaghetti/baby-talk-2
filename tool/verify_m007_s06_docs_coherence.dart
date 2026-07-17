import 'dart:convert';
import 'dart:io';

const docsTelemetryPath = 'tmp/m007-s06-docs-metrics.jsonl';
const stagesRun = 5;
const readmePath = 'README.md';
const contributingPath = 'CONTRIBUTING.md';
const runbookPath = 'docs/runbooks/k8s-deploy.md';
const schemaMatrixPath = 'docs/schema-compatibility-matrix.md';
const schemaMigrationCommitAnchors = <String, String>{
  'V3': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V4': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V5': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V6': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V7': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V8': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V9': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V10': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V11': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V12': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V13': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V14': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V15': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V16': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V17': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V18': 'efddef2670c81a4483e3e504322c1bdce300076d',
  'V19': 'efddef2670c81a4483e3e504322c1bdce300076d',
  'V20': 'a61f66d39f2b98417fe20fe2ed7f7c5a56c29d98',
  'V21': 'a61f66d39f2b98417fe20fe2ed7f7c5a56c29d98',
  'V22': '347c623ca58be8e7300b48d844c933a6bd257bdc',
  'V22.1': '190d9a1d0b30710d39f88d069a826f9eccbc7f59',
  'V23': 'a13d45407f2143bfe67fe623674d9696c2b7cb3f',
  'V24': '26a5c1f6696aba728ffe34afa233a2dd588c6dd8',
  'V25': 'ad05936ea58283fced9db67a21f9cde2c63ea1c1',
  'V26': '132ea115b3b8c693537aac1e690e84f5d0e18ac9',
};
const windowsWingetHelm =
    'C:/Users/zhang/AppData/Local/Microsoft/WinGet/Packages/Helm.Helm_Microsoft.Winget.Source_8wekyb3d8bbwe/windows-amd64/helm.exe';

Future<void> main() async {
  final startedAt = DateTime.now().toUtc();
  var stagesPassed = 0;
  StepFailure? failure;

  final stages = <StageCheck>[
    StageCheck(key: 'preflight', label: 'Preflight', run: _runPreflightStage),
    StageCheck(
      key: 'readme-truth',
      label: 'README truth',
      run: _runReadmeTruthStage,
    ),
    StageCheck(
      key: 'contributing-truth',
      label: 'CONTRIBUTING truth',
      run: _runContributingTruthStage,
    ),
    StageCheck(
      key: 'runbook-truth',
      label: 'Runbook truth',
      run: _runRunbookTruthStage,
    ),
    StageCheck(
      key: 'schema-matrix-truth',
      label: 'Schema matrix truth',
      run: _runSchemaMatrixTruthStage,
    ),
  ];

  for (final stage in stages) {
    stdout.writeln('== ${stage.label} ==');
    try {
      await stage.run();
      stagesPassed += 1;
      stdout.writeln('PASS ${stage.key}');
    } on StepFailure catch (error) {
      failure = error;
      stderr.writeln('FAIL ${stage.key}: ${error.detail}');
      break;
    } catch (error, stackTrace) {
      failure = StepFailure(
        stageKey: stage.key,
        exitCode: 1,
        detail:
            '${error.runtimeType}: $error\n${_trimmedOutput(stackTrace.toString())}',
      );
      stderr.writeln('FAIL ${stage.key}: ${failure.detail}');
      break;
    }
  }

  await _appendTelemetry(
    mode: 'offline',
    stagesPassed: stagesPassed,
    firstFailureStage: failure?.stageKey,
    timestampIso8601: DateTime.now().toUtc().toIso8601String(),
  );

  stdout.writeln('telemetry_path=$docsTelemetryPath');
  stdout.writeln('stages_run=$stagesRun');
  stdout.writeln('stages_passed=$stagesPassed');
  stdout.writeln('first_failure_stage=${failure?.stageKey ?? 'none'}');
  stdout.writeln('started_at=${startedAt.toIso8601String()}');

  if (failure != null) {
    exitCode = failure.exitCode;
  }
}

// ---------------------------------------------------------------------------
// Stage implementations
// ---------------------------------------------------------------------------

Future<void> _runPreflightStage() async {
  final helmCommand = _resolveHelmCommand();
  await _requireSuccess(
    stageKey: 'preflight',
    command: helmCommand,
    args: ['version'],
    failureMessage: 'helm version must exit 0 during offline preflight',
  );
  await _requireSuccess(
    stageKey: 'preflight',
    command: 'dart',
    args: ['--version'],
    failureMessage: 'dart --version must exit 0 during offline preflight',
  );
}

Future<void> _runReadmeTruthStage() async {
  final readme = File(readmePath);
  if (!readme.existsSync()) {
    throw const StepFailure(
      stageKey: 'readme-truth',
      exitCode: 1,
      detail: 'README.md must exist at repo root',
    );
  }
  final text = readme.readAsStringSync();

  // Must NOT contain stale S01-era references
  _assertNotContains(
    stageKey: 'readme-truth',
    text: text,
    pattern: 'nginx:alpine',
    message:
        'README.md must not reference nginx:alpine (stale gateway stub language)',
  );
  _assertNotContains(
    stageKey: 'readme-truth',
    text: text,
    pattern: 'S03 会替换',
    message:
        'README.md must not reference "S03 会替换" (stale milestone-era language)',
  );
  _assertNotContains(
    stageKey: 'readme-truth',
    text: text,
    pattern: 'S01 的 CI',
    message:
        'README.md must not reference "S01 的 CI" (stale milestone qualifier)',
  );

  // Must contain current gateway truth
  _assertContains(
    stageKey: 'readme-truth',
    text: text,
    pattern: 'Spring Cloud Gateway',
    message: 'README.md must reference Spring Cloud Gateway',
  );
  _assertContains(
    stageKey: 'readme-truth',
    text: text,
    pattern: 'dev-up-helm-demo',
    message:
        'README.md must reference dev-up-helm-demo as the front-door command',
  );
}

Future<void> _runContributingTruthStage() async {
  final contributing = File(contributingPath);
  if (!contributing.existsSync()) {
    throw const StepFailure(
      stageKey: 'contributing-truth',
      exitCode: 1,
      detail: 'CONTRIBUTING.md must exist at repo root',
    );
  }
  final text = contributing.readAsStringSync();

  // Must NOT contain stale references
  _assertNotContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: 'admin-api:8081',
    message:
        'CONTRIBUTING.md must not reference admin-api:8081 (S03 changed proxy target to gateway:8090)',
  );
  _assertNotContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: '127.0.0.1:8081',
    message:
        'CONTRIBUTING.md must not reference 127.0.0.1:8081 (stale admin-api direct port)',
  );
  _assertNotContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: 'S01 的 CI',
    message:
        'CONTRIBUTING.md must not reference "S01 的 CI" (stale milestone qualifier)',
  );

  // Must contain current truth
  _assertContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: 'MyBatisPlus',
    message:
        'CONTRIBUTING.md must document MyBatisPlus as the canonical backend persistence pattern',
  );
  // gateway proxy target must be 8090 not 8081
  _assertContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: '8090',
    message:
        'CONTRIBUTING.md must reference gateway port 8090 as the admin-web proxy target',
  );
}

Future<void> _runRunbookTruthStage() async {
  final runbook = File(runbookPath);
  if (!runbook.existsSync()) {
    throw const StepFailure(
      stageKey: 'runbook-truth',
      exitCode: 1,
      detail: 'docs/runbooks/k8s-deploy.md must exist',
    );
  }
  final text = runbook.readAsStringSync();

  // Must NOT contain stale gateway stub language
  _assertNotContains(
    stageKey: 'runbook-truth',
    text: text,
    pattern: 'gateway stub',
    message:
        'docs/runbooks/k8s-deploy.md must not reference "gateway stub" (S03 replaced stub with Spring Cloud Gateway)',
  );
  _assertNotContains(
    stageKey: 'runbook-truth',
    text: text,
    pattern: 'S03 才会替换',
    message:
        'docs/runbooks/k8s-deploy.md must not contain "S03 才会替换" (stale milestone-era language)',
  );

  // Must contain current gateway truth
  _assertContains(
    stageKey: 'runbook-truth',
    text: text,
    pattern: 'Spring Cloud Gateway',
    message: 'docs/runbooks/k8s-deploy.md must reference Spring Cloud Gateway',
  );
  _assertContains(
    stageKey: 'runbook-truth',
    text: text,
    pattern: 'babytalk-infra',
    message:
        'docs/runbooks/k8s-deploy.md must reference babytalk-infra release',
  );
  _assertContains(
    stageKey: 'runbook-truth',
    text: text,
    pattern: 'babytalk-app',
    message: 'docs/runbooks/k8s-deploy.md must reference babytalk-app release',
  );

  // Schema matrix must exist
  if (!File(schemaMatrixPath).existsSync()) {
    throw const StepFailure(
      stageKey: 'runbook-truth',
      exitCode: 1,
      detail: 'docs/schema-compatibility-matrix.md must exist',
    );
  }
}

Future<void> _runSchemaMatrixTruthStage() async {
  final schemaMatrix = File(schemaMatrixPath);
  if (!schemaMatrix.existsSync()) {
    throw const StepFailure(
      stageKey: 'schema-matrix-truth',
      exitCode: 1,
      detail: 'docs/schema-compatibility-matrix.md must exist',
    );
  }

  final issues = validateSchemaCompatibilityMatrixText(
    schemaMatrix.readAsStringSync(),
  );
  if (issues.isNotEmpty) {
    throw StepFailure(
      stageKey: 'schema-matrix-truth',
      exitCode: 1,
      detail: issues.join('\n'),
    );
  }
}

/// Pure validator for fixture tests and the live M007 docs-coherence stage.
List<String> validateSchemaCompatibilityMatrixText(String text) {
  final expectedVersions = schemaMigrationCommitAnchors.keys.toList();
  const nWorkload = '40bb9600991f5c7a0cf73eb59658b97ce590383f';
  const nMinusOneWorkload = '3ee8bb7729f450a3a3e65b279cc76662ebc1b75e';
  const v23Commit = 'a13d45407f2143bfe67fe623674d9696c2b7cb3f';
  const evidenceMethod =
      'v23UpgradePreservesLegacyReactionRowsButRejectsNMinusOneWrites';
  const rollbackWarning =
      'After V23+, do not roll back to `$nMinusOneWorkload` while reaction-event writes are possible.';
  const allowedStatuses = <String>{
    'compatible',
    'incompatible',
    'not verified',
  };

  final issues = <String>[];
  if (text.contains('unreleased app-api')) {
    issues.add(
      'Schema matrix must not use generic `unreleased app-api` anchors.',
    );
  }
  for (final requiredAnchor in <String, String>{
    'Audited N workload': nWorkload,
    'Exact N-1/pre-V23 workload': nMinusOneWorkload,
    'V23 introducing workload/migration commit': v23Commit,
  }.entries) {
    final declaration = '${requiredAnchor.key}: `${requiredAnchor.value}`';
    if (!text.contains(declaration)) {
      issues.add(
        'Schema matrix must name exact audited anchor `${requiredAnchor.value}` in `$declaration`.',
      );
    }
  }
  if (!text.contains(rollbackWarning)) {
    issues.add(
      'Schema matrix must include exact V23 rollback warning: $rollbackWarning',
    );
  }
  if (!text.contains(evidenceMethod)) {
    issues.add('Schema matrix must link evidence method `$evidenceMethod`.');
  }

  final rowsByVersion = <String, List<String>>{};
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('| V')) {
      continue;
    }
    final cells = trimmed
        .substring(1, trimmed.length - (trimmed.endsWith('|') ? 1 : 0))
        .split('|')
        .map((cell) => cell.trim())
        .toList();
    if (cells.isEmpty || !expectedVersions.contains(cells.first)) {
      continue;
    }
    if (rowsByVersion.containsKey(cells.first)) {
      issues.add(
        'Schema matrix migration row ${cells.first} must appear once.',
      );
    } else {
      rowsByVersion[cells.first] = cells;
    }
  }

  final exactCommit = RegExp(r'^`?[0-9a-f]{40}`?$');
  for (final version in expectedVersions) {
    final cells = rowsByVersion[version];
    if (cells == null) {
      issues.add('Schema matrix must include migration row $version.');
      continue;
    }
    if (cells.length < 5) {
      issues.add(
        'Schema matrix migration row $version must have five columns.',
      );
      continue;
    }
    if (!exactCommit.hasMatch(cells[2])) {
      issues.add(
        'Schema matrix migration row $version must use an exact 40-character commit anchor.',
      );
    }
    final commit = cells[2].replaceAll('`', '');
    final expectedCommit = schemaMigrationCommitAnchors[version]!;
    if (commit != expectedCommit) {
      issues.add(
        'Schema matrix migration row $version must use exact commit anchor `$expectedCommit`.',
      );
    }
    if (!allowedStatuses.contains(cells[3])) {
      issues.add(
        'Schema matrix migration row $version status must be compatible, incompatible, or not verified.',
      );
    }
  }

  final v23 = rowsByVersion['V23'];
  if (v23 == null || v23.length < 5 || v23[3] != 'incompatible') {
    issues.add('Schema matrix V23 status must be incompatible for N-1 writes.');
  }

  return issues;
}

// ---------------------------------------------------------------------------
// Assertion helpers
// ---------------------------------------------------------------------------

void _assertContains({
  required String stageKey,
  required String text,
  required String pattern,
  required String message,
}) {
  if (!text.contains(pattern)) {
    throw StepFailure(stageKey: stageKey, exitCode: 1, detail: message);
  }
}

void _assertNotContains({
  required String stageKey,
  required String text,
  required String pattern,
  required String message,
}) {
  if (text.contains(pattern)) {
    throw StepFailure(stageKey: stageKey, exitCode: 1, detail: message);
  }
}

// ---------------------------------------------------------------------------
// Shared infrastructure (mirrors verify_m007_s02_release_boundaries.dart)
// ---------------------------------------------------------------------------

Future<void> _requireSuccess({
  required String stageKey,
  required String command,
  required List<String> args,
  required String failureMessage,
}) async {
  final result = await _runCommand(command: command, args: args);
  if (result.exitCode != 0) {
    throw StepFailure(
      stageKey: stageKey,
      exitCode: result.exitCode,
      detail: '$failureMessage\n${_trimmedOutput(result.combinedOutput)}',
    );
  }
}

String _resolveHelmCommand() {
  if (Platform.isWindows && File(windowsWingetHelm).existsSync()) {
    return windowsWingetHelm;
  }
  return 'helm';
}

Future<CommandResult> _runCommand({
  required String command,
  required List<String> args,
}) async {
  try {
    final result = await Process.run(
      command,
      args,
      runInShell: false,
      workingDirectory: Directory.current.path,
    );
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  } on ProcessException catch (error) {
    return CommandResult(
      exitCode: error.errorCode == 0 ? 127 : error.errorCode,
      stdout: '',
      stderr: error.message,
    );
  }
}

Future<void> _appendTelemetry({
  required String mode,
  required int stagesPassed,
  required String? firstFailureStage,
  required String timestampIso8601,
}) async {
  final file = File(docsTelemetryPath);
  await file.parent.create(recursive: true);
  final entry = <String, Object?>{
    'mode': mode,
    'stages_run': stagesRun,
    'stages_passed': stagesPassed,
    'first_failure_stage': firstFailureStage,
    'timestamp_iso8601': timestampIso8601,
  };
  await file.writeAsString(
    '${jsonEncode(entry)}\n',
    mode: FileMode.writeOnlyAppend,
    flush: true,
  );
}

String _trimmedOutput(String output) {
  final trimmed = output.trim();
  if (trimmed.isEmpty) {
    return '(no output)';
  }
  return trimmed.length <= 1200 ? trimmed : '${trimmed.substring(0, 1200)}...';
}

class StageCheck {
  const StageCheck({required this.key, required this.label, required this.run});

  final String key;
  final String label;
  final Future<void> Function() run;
}

class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  String get combinedOutput {
    if (stdout.isEmpty) {
      return stderr;
    }
    if (stderr.isEmpty) {
      return stdout;
    }
    return '$stdout\n$stderr';
  }
}

class StepFailure implements Exception {
  const StepFailure({
    required this.stageKey,
    required this.exitCode,
    required this.detail,
  });

  final String stageKey;
  final int exitCode;
  final String detail;
}
