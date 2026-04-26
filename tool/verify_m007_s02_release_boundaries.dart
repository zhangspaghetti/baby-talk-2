import 'dart:convert';
import 'dart:io';

const boundaryTelemetryPath = 'tmp/m007-s02-boundary-metrics.jsonl';
const stagesRun = 4;
const infraReleaseName = 'babytalk-infra';
const infraChartPath = 'deploy/helm/babytalk-infra';
const appReleaseName = 'babytalk-app';
const appChartPath = 'deploy/helm/babytalk-app';
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
    StageCheck(key: 'infra', label: 'Infra boundary', run: _runInfraBoundaryStage),
    StageCheck(key: 'app', label: 'App boundary', run: _runAppBoundaryStage),
    StageCheck(key: 'docs', label: 'Documentation boundary', run: _runDocStage),
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

  stdout.writeln('telemetry_path=$boundaryTelemetryPath');
  stdout.writeln('stages_run=$stagesRun');
  stdout.writeln('stages_passed=$stagesPassed');
  stdout.writeln('first_failure_stage=${failure?.stageKey ?? 'none'}');
  stdout.writeln('started_at=${startedAt.toIso8601String()}');

  if (failure != null) {
    exit(failure.exitCode);
  }
}

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

Future<void> _runInfraBoundaryStage() async {
  final helmCommand = _resolveHelmCommand();
  final result = await _runCommand(
    command: helmCommand,
    args: ['template', infraReleaseName, infraChartPath],
  );
  if (result.exitCode != 0) {
    throw StepFailure(
      stageKey: 'infra',
      exitCode: result.exitCode,
      detail:
          'helm template $infraReleaseName $infraChartPath failed.\n${_trimmedOutput(result.combinedOutput)}',
    );
  }

  final jobCount = RegExp(r'^kind:\s+Job\s*$', multiLine: true)
      .allMatches(result.stdout)
      .length;
  if (jobCount != 0) {
    throw StepFailure(
      stageKey: 'infra',
      exitCode: 1,
      detail:
          'infra chart must not contain a db-migration Job; found $jobCount Job resources',
    );
  }
}

Future<void> _runAppBoundaryStage() async {
  final helmCommand = _resolveHelmCommand();
  final result = await _runCommand(
    command: helmCommand,
    args: ['template', appReleaseName, appChartPath],
  );
  if (result.exitCode != 0) {
    throw StepFailure(
      stageKey: 'app',
      exitCode: result.exitCode,
      detail:
          'helm template $appReleaseName $appChartPath failed.\n${_trimmedOutput(result.combinedOutput)}',
    );
  }

  if (!result.stdout.contains('before-hook-creation,hook-succeeded')) {
    throw const StepFailure(
      stageKey: 'app',
      exitCode: 1,
      detail:
          'app chart must keep db-migration hook-delete-policy: before-hook-creation,hook-succeeded',
    );
  }

  if (!result.stdout.contains('pre-install,pre-upgrade')) {
    throw const StepFailure(
      stageKey: 'app',
      exitCode: 1,
      detail: 'app chart must keep helm.sh/hook: pre-install,pre-upgrade',
    );
  }
}

Future<void> _runDocStage() async {
  final runbook = File(runbookPath);
  if (!runbook.existsSync()) {
    throw const StepFailure(
      stageKey: 'docs',
      exitCode: 1,
      detail: 'docs/runbooks/k8s-deploy.md must exist',
    );
  }

  final runbookText = await runbook.readAsString();
  if (!runbookText.contains('babytalk-infra')) {
    throw const StepFailure(
      stageKey: 'docs',
      exitCode: 1,
      detail: 'docs/runbooks/k8s-deploy.md must mention babytalk-infra',
    );
  }
  if (!runbookText.contains('babytalk-app')) {
    throw const StepFailure(
      stageKey: 'docs',
      exitCode: 1,
      detail: 'docs/runbooks/k8s-deploy.md must mention babytalk-app',
    );
  }

  if (!File(schemaMatrixPath).existsSync()) {
    throw const StepFailure(
      stageKey: 'docs',
      exitCode: 1,
      detail: 'docs/schema-compatibility-matrix.md must exist',
    );
  }
}

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
  final file = File(boundaryTelemetryPath);
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
