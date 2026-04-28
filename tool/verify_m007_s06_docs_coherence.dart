import 'dart:convert';
import 'dart:io';

const docsTelemetryPath = 'tmp/m007-s06-docs-metrics.jsonl';
const stagesRun = 4;
const readmePath = 'README.md';
const contributingPath = 'CONTRIBUTING.md';
const runbookPath = 'docs/runbooks/k8s-deploy.md';
const schemaMatrixPath = 'docs/schema-compatibility-matrix.md';
const windowsWingetHelm =
    'C:/Users/zhang/AppData/Local/Microsoft/WinGet/Packages/Helm.Helm_Microsoft.Winget.Source_8wekyb3d8bbwe/windows-amd64/helm.exe';

Future<void> main() async {
  final startedAt = DateTime.now().toUtc();
  var stagesPassed = 0;
  StepFailure? failure;

  final stages = <StageCheck>[
    StageCheck(key: 'preflight', label: 'Preflight', run: _runPreflightStage),
    StageCheck(key: 'readme-truth', label: 'README truth', run: _runReadmeTruthStage),
    StageCheck(key: 'contributing-truth', label: 'CONTRIBUTING truth', run: _runContributingTruthStage),
    StageCheck(key: 'runbook-truth', label: 'Runbook truth', run: _runRunbookTruthStage),
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
        detail: '${error.runtimeType}: $error\n${_trimmedOutput(stackTrace.toString())}',
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
    message: 'README.md must not reference nginx:alpine (stale gateway stub language)',
  );
  _assertNotContains(
    stageKey: 'readme-truth',
    text: text,
    pattern: 'S03 会替换',
    message: 'README.md must not reference "S03 会替换" (stale milestone-era language)',
  );
  _assertNotContains(
    stageKey: 'readme-truth',
    text: text,
    pattern: 'S01 的 CI',
    message: 'README.md must not reference "S01 的 CI" (stale milestone qualifier)',
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
    message: 'README.md must reference dev-up-helm-demo as the front-door command',
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
    message: 'CONTRIBUTING.md must not reference admin-api:8081 (S03 changed proxy target to gateway:8090)',
  );
  _assertNotContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: '127.0.0.1:8081',
    message: 'CONTRIBUTING.md must not reference 127.0.0.1:8081 (stale admin-api direct port)',
  );
  _assertNotContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: 'S01 的 CI',
    message: 'CONTRIBUTING.md must not reference "S01 的 CI" (stale milestone qualifier)',
  );

  // Must contain current truth
  _assertContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: 'MyBatisPlus',
    message: 'CONTRIBUTING.md must document MyBatisPlus as the canonical backend persistence pattern',
  );
  // gateway proxy target must be 8090 not 8081
  _assertContains(
    stageKey: 'contributing-truth',
    text: text,
    pattern: '8090',
    message: 'CONTRIBUTING.md must reference gateway port 8090 as the admin-web proxy target',
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
    message: 'docs/runbooks/k8s-deploy.md must not reference "gateway stub" (S03 replaced stub with Spring Cloud Gateway)',
  );
  _assertNotContains(
    stageKey: 'runbook-truth',
    text: text,
    pattern: 'S03 才会替换',
    message: 'docs/runbooks/k8s-deploy.md must not contain "S03 才会替换" (stale milestone-era language)',
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
    message: 'docs/runbooks/k8s-deploy.md must reference babytalk-infra release',
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
  return trimmed.length <= 1200
      ? trimmed
      : '${trimmed.substring(0, 1200)}...';
}

class StageCheck {
  const StageCheck({
    required this.key,
    required this.label,
    required this.run,
  });

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
