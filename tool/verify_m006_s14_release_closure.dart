import 'dart:async';
import 'dart:convert';
import 'dart:io';

const releaseClosureUsage =
    '''Usage: dart run tool/verify_m006_s14_release_closure.dart [--help]

Legacy M006 S14 child chain is not runnable. Its dependencies include archived or removed active paths.
Current executable CI front door: bash ci/k8s-smoke.sh

Historical child order:
  1. S07 mentor + distribution closure
  2. S08 Helm release truth
  3. S12 control-plane freshness
  4. S13 repo front-door truth
''';

const releaseClosureRunbookPath = 'docs/runbooks/m006-s14-release-closure.md';
const releaseClosureSuccessMarker =
    'All M006/S14 release-closure verification steps passed.';

const releaseClosureChildGates = <ChildGate>[
  ChildGate(
    gateId: 'S07',
    stepLabel: 'Release closure | S07 mentor + distribution gate',
    verifierPath: 'tool/verify_m006_s07_mentor_distribution.dart',
    verifierArgs: [],
    successMarker:
        'All M006/S07 mentor + distribution verification steps passed.',
    timeout: Duration(minutes: 30),
    runbookPath:
        'docs/archived/runbooks/m006-s07-mentor-distribution-closure.md',
    artifactHint: 'admin-web/playwright-report/index.html',
  ),
  ChildGate(
    gateId: 'S08',
    stepLabel: 'Release closure | S08 Helm release gate',
    verifierPath: 'tool/verify_m006_s08_release.dart',
    verifierArgs: ['--helm'],
    successMarker: 'All M006/S08 release verification steps passed.',
    timeout: Duration(minutes: 10),
    runbookPath: 'docs/runbooks/k8s-deploy.md',
  ),
  ChildGate(
    gateId: 'S12',
    stepLabel: 'Release closure | S12 control-plane freshness gate',
    verifierPath: 'tool/verify_m006_s12_control_plane_freshness.dart',
    verifierArgs: [],
    successMarker:
        'All M006/S12 overview control-plane verification steps passed.',
    timeout: Duration(minutes: 25),
    runbookPath: 'docs/archived/runbooks/m006-s12-control-plane-freshness.md',
    artifactHint: 'admin-web/playwright-report/index.html',
  ),
  ChildGate(
    gateId: 'S13',
    stepLabel: 'Release closure | S13 repo front-door gate',
    verifierPath: 'tool/verify_m006_s13_demo_path.dart',
    verifierArgs: [],
    successMarker: 'All M006/S13 demo-path verification steps passed.',
    timeout: Duration(minutes: 10),
    runbookPath: 'docs/archived/runbooks/m006-s13-demo-path.md',
  ),
];

Future<void> main(List<String> args) async {
  final options = ReleaseClosureCliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(releaseClosureUsage);
    return;
  }

  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(releaseClosureUsage);
    exit(64);
  }

  try {
    for (final gate in releaseClosureChildGates) {
      await _runChildGate(gate);
    }
  } on StepFailure catch (error) {
    stderr.writeln('Verification failed at step: ${error.stepLabel}');
    stderr.writeln(error.message);
    exit(error.exitCode);
  }

  stdout.writeln('');
  stdout.writeln('release_closure_runbook=$releaseClosureRunbookPath');
  stdout.writeln(releaseClosureSuccessMarker);
}

Future<void> _runChildGate(ChildGate gate) async {
  final contractFailure = validateChildGateContract(gate);
  if (contractFailure != null) {
    throw contractFailure;
  }

  stdout.writeln('');
  stdout.writeln('==> ${gate.stepLabel}');
  stdout.writeln(gate.stepCommandLine);
  stdout.writeln('drill_down_verifier=${gate.rerunCommand}');
  stdout.writeln('drill_down_runbook=${gate.runbookPath}');
  if (gate.artifactHint != null) {
    stdout.writeln('drill_down_artifact=${gate.artifactHint}');
  }

  final result = await _runChildProcess(gate);
  final resultFailure = validateChildGateResult(gate, result);
  if (resultFailure != null) {
    throw resultFailure;
  }

  stdout.writeln('child_gate=${gate.gateId} status=passed');
}

Future<ProcessResultSnapshot> _runChildProcess(ChildGate gate) async {
  late final Process process;
  try {
    process = await Process.start(
      Platform.resolvedExecutable,
      ['run', gate.verifierPath, ...gate.verifierArgs],
      workingDirectory: Directory.current.path,
      runInShell: false,
      environment: Platform.environment,
    );
  } on ProcessException catch (error) {
    throw StepFailure(
      gate.stepLabel,
      'Unable to start child gate `${gate.gateId}` via `${gate.rerunCommand}`: ${error.message}',
      error.errorCode == 0 ? 1 : error.errorCode,
    );
  }

  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  final stdoutDone = process.stdout.transform(utf8.decoder).listen((chunk) {
    stdout.write(chunk);
    stdoutBuffer.write(chunk);
  }).asFuture<void>();
  final stderrDone = process.stderr.transform(utf8.decoder).listen((chunk) {
    stderr.write(chunk);
    stderrBuffer.write(chunk);
  }).asFuture<void>();

  try {
    final exitCode = await process.exitCode.timeout(gate.timeout);
    await Future.wait([stdoutDone, stderrDone]);
    return ProcessResultSnapshot(
      exitCode: exitCode,
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
    );
  } on TimeoutException {
    process.kill(ProcessSignal.sigterm);
    await Future<void>.delayed(const Duration(seconds: 2));
    process.kill(ProcessSignal.sigkill);
    await Future.wait([stdoutDone, stderrDone]);
    return ProcessResultSnapshot(
      exitCode: 124,
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
    );
  }
}

typedef PathExists = bool Function(String path);

StepFailure? validateChildGateContract(
  ChildGate gate, {
  PathExists? pathExists,
}) {
  final exists = pathExists ?? (path) => File(path).existsSync();

  if (gate.verifierPath.trim().isEmpty) {
    return StepFailure(
      gate.stepLabel,
      'Child gate `${gate.gateId}` does not declare a verifier path. '
      'S14 must stay composition-only and point at an explicit child verifier.',
      1,
    );
  }

  if (gate.runbookPath.trim().isEmpty) {
    return StepFailure(
      gate.stepLabel,
      'Child gate `${gate.gateId}` does not declare a drill-down runbook path. '
      'Release-closure docs must stay discoverable.',
      1,
    );
  }

  if (gate.successMarker.trim().isEmpty) {
    return StepFailure(
      gate.stepLabel,
      'Child gate `${gate.gateId}` declares an empty success marker. '
      'S14 requires explicit success markers so malformed child output fails closed. '
      'Drill-down: ${gate.rerunCommand}${gate.runbookLabel}',
      1,
    );
  }

  if (gate.artifactHint != null && gate.artifactHint!.trim().isEmpty) {
    return StepFailure(
      gate.stepLabel,
      'Child gate `${gate.gateId}` declares a blank artifact hint. '
      'Drill-down artifacts must stay explicit when present. '
      'Drill-down: ${gate.rerunCommand}${gate.runbookLabel}',
      1,
    );
  }

  if (!exists(gate.verifierPath)) {
    return StepFailure(
      gate.stepLabel,
      'Required child verifier is missing at `${gate.verifierPath}`. '
      'S14 treats missing child gates as hard failures. '
      'Drill-down: ${gate.rerunCommand}${gate.runbookLabel}',
      1,
    );
  }

  if (!exists(gate.runbookPath)) {
    return StepFailure(
      gate.stepLabel,
      'Expected drill-down runbook is missing at `${gate.runbookPath}`. '
      'Release-closure docs must stay discoverable. '
      'Drill-down verifier: ${gate.rerunCommand}',
      1,
    );
  }

  return null;
}

StepFailure? validateChildGateResult(
  ChildGate gate,
  ProcessResultSnapshot result,
) {
  if (result.exitCode == 124) {
    return StepFailure(
      gate.stepLabel,
      'Timed out after ${gate.timeout.inMinutes}m while waiting for child gate `${gate.gateId}`. '
      'Drill-down: ${gate.rerunCommand}${gate.runbookLabel}',
      124,
    );
  }

  if (result.exitCode != 0) {
    return StepFailure(
      gate.stepLabel,
      'Child gate `${gate.gateId}` exited with code ${result.exitCode}. '
      'Fail-fast stopped the release closure at the first red dependency. '
      'Drill-down: ${gate.rerunCommand}${gate.runbookLabel}${gate.artifactLabel}',
      result.exitCode,
    );
  }

  if (!result.combinedOutput.contains(gate.successMarker)) {
    return StepFailure(
      gate.stepLabel,
      'Child gate `${gate.gateId}` exited 0 but did not emit the expected success marker. '
      'Treating this as malformed child output. '
      'Expected marker: `${gate.successMarker}`. '
      'Drill-down: ${gate.rerunCommand}${gate.runbookLabel}',
      1,
    );
  }

  return null;
}

class ReleaseClosureCliOptions {
  const ReleaseClosureCliOptions({
    required this.showHelp,
    required this.usageError,
  });

  final bool showHelp;
  final String? usageError;

  factory ReleaseClosureCliOptions.parse(List<String> args) {
    var showHelp = false;
    final unknownArgs = <String>[];

    for (final arg in args) {
      switch (arg) {
        case '--help':
        case '-h':
          showHelp = true;
          break;
        default:
          unknownArgs.add(arg);
      }
    }

    if (unknownArgs.isNotEmpty) {
      return ReleaseClosureCliOptions(
        showHelp: false,
        usageError: 'Unknown arguments: ${unknownArgs.join(' ')}',
      );
    }

    return ReleaseClosureCliOptions(showHelp: showHelp, usageError: null);
  }
}

class ChildGate {
  const ChildGate({
    required this.gateId,
    required this.stepLabel,
    required this.verifierPath,
    required this.verifierArgs,
    required this.successMarker,
    required this.timeout,
    required this.runbookPath,
    this.artifactHint,
  });

  final String gateId;
  final String stepLabel;
  final String verifierPath;
  final List<String> verifierArgs;
  final String successMarker;
  final Duration timeout;
  final String runbookPath;
  final String? artifactHint;

  String get rerunCommand =>
      'dart run $verifierPath${verifierArgs.isEmpty ? '' : ' ${verifierArgs.join(' ')}'}';

  String get stepCommandLine => r'$ ' + rerunCommand;

  String get runbookLabel => ' | Runbook: $runbookPath';

  String get artifactLabel =>
      artifactHint == null ? '' : ' | Artifact: $artifactHint';
}

class ProcessResultSnapshot {
  const ProcessResultSnapshot({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  String get combinedOutput => '$stdout\n$stderr';
}

class StepFailure implements Exception {
  const StepFailure(this.stepLabel, this.message, this.exitCode);

  final String stepLabel;
  final String message;
  final int exitCode;
}
