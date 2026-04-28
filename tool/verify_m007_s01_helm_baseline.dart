import 'dart:async';
import 'dart:convert';
import 'dart:io';

const helmTelemetryHistoryPath = 'tmp/m007-s01-helm-metrics.jsonl';
const helmTelemetryMaxEntries = 50;
const namespace = 'babytalk';
const infraReleaseName = 'babytalk-infra';
const appReleaseName = 'babytalk-app';
const gatewayServiceName = '$appReleaseName-gateway';
const gatewayLocalPort = 8090;
const gatewayUrl = 'http://127.0.0.1:$gatewayLocalPort/';

const _usage = '''Usage: dart run tool/verify_m007_s01_helm_baseline.dart <demo|smoke> [--help]

Modes:
  demo    Install infra + app charts into the active kubectl context, then verify gateway.
          Requires Docker Desktop Kubernetes (or any reachable cluster via kubectl).
  smoke   Assume the cluster is already up and only re-check the gateway smoke path.
''';

Future<void> main(List<String> args) async {
  final options = CliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(_usage);
    exit(64);
  }

  final startedAt = DateTime.now();
  StepFailure? failure;

  try {
    await _runPreflight();

    if (options.mode == ExecutionMode.demo) {
      await _runClusterStage();
      await _runInfraStage();
      await _runAppStage();
    }

    await _runGatewayAndSmokeStages();
  } on StepFailure catch (error) {
    failure = error;
  }

  final now = DateTime.now();
  final tthwSeconds = now.difference(startedAt).inSeconds;
  final nextAction = failure?.nextAction ?? nextWrapperCommand();

  await appendHelmTelemetry(
    HelmTelemetryEntry(
      mode: options.mode.name,
      shell: currentFrontDoorShell(),
      success: failure == null,
      tthwSeconds: tthwSeconds,
      firstFailureStage: failure?.stageKey ?? 'none',
      likelyCause: failure?.likelyCause ?? 'none',
      nextAction: nextAction,
      timestampIso8601: now.toUtc().toIso8601String(),
    ),
  );

  if (failure != null) {
    _printFailure(failure, tthwSeconds: tthwSeconds, nextAction: nextAction);
    exit(failure.exitCode);
  }

  _printSuccess(tthwSeconds: tthwSeconds, nextAction: nextAction);
}

Future<void> _runPreflight() async {
  await _requireCommandAvailable(
    'helm',
    const CommandSpec(command: 'helm', args: ['version', '--short']),
  );
  await _requireCommandAvailable(
    'kubectl',
    const CommandSpec(
      command: 'kubectl',
      args: ['version', '--client', '-o', 'yaml'],
    ),
  );
  await _requireCommandAvailable(
    'dart',
    const CommandSpec(command: 'dart', args: ['--version']),
  );
}

Future<void> _runClusterStage() async {
  // Docker Desktop Kubernetes (or any reachable cluster) — just verify connectivity.
  final result = await _runCommand(
    const CommandSpec(command: 'kubectl', args: ['cluster-info']),
    timeout: const Duration(seconds: 20),
  );
  if (result.exitCode != 0) {
    throw StepFailure(
      stageKey: 'cluster',
      exitCode: result.exitCode,
      likelyCause: 'cluster_unreachable',
      nextAction:
          'Ensure Docker Desktop Kubernetes is enabled and your kubectl context points to it, then rerun ./scripts/dev-up-helm-demo.sh.',
      detail:
          '`kubectl cluster-info` failed.\n${_trimmedOutput(result.combinedOutput)}',
    );
  }
}

Future<void> _runInfraStage() async {
  final result = await _runCommand(
    const CommandSpec(
      command: 'helm',
      args: [
        'upgrade',
        '--install',
        infraReleaseName,
        'deploy/helm/babytalk-infra',
        '-f',
        'deploy/helm/babytalk-infra/values-kind.yaml',
        '--namespace',
        namespace,
        '--create-namespace',
        '--wait',
        '--timeout',
        '120s',
      ],
    ),
    timeout: const Duration(minutes: 4),
  );
  if (result.exitCode != 0) {
    throw StepFailure(
      stageKey: 'infra',
      exitCode: result.exitCode,
      likelyCause: 'infra_release_failed',
      nextAction:
          'Run `helm status $infraReleaseName -n $namespace` and `kubectl get pods -n $namespace`, then fix the first failing infra dependency.',
      detail:
          '`helm upgrade --install $infraReleaseName ...` failed.\n${_trimmedOutput(result.combinedOutput)}',
    );
  }
}

Future<void> _runAppStage() async {
  final result = await _runCommand(
    const CommandSpec(
      command: 'helm',
      args: [
        'upgrade',
        '--install',
        appReleaseName,
        'deploy/helm/babytalk-app',
        '-f',
        'deploy/helm/babytalk-app/values-kind.yaml',
        '--namespace',
        namespace,
        '--create-namespace',
        '--wait',
        '--timeout',
        '180s',
      ],
    ),
    timeout: const Duration(minutes: 5),
  );
  if (result.exitCode != 0) {
    throw StepFailure(
      stageKey: 'app',
      exitCode: result.exitCode,
      likelyCause: 'app_release_failed',
      nextAction:
          'Run `helm status $appReleaseName -n $namespace` and `kubectl get pods -n $namespace`, then fix the first failing app workload.',
      detail:
          '`helm upgrade --install $appReleaseName ...` failed.\n${_trimmedOutput(result.combinedOutput)}',
    );
  }
}

Future<void> _runGatewayAndSmokeStages() async {
  final portForward = await _startPortForward();
  try {
    await _assertGatewayHealthy(
      stageKey: 'gateway',
      likelyCause: 'gateway_not_healthy',
      nextAction:
          'Run `kubectl get pods,svc -n $namespace` and `kubectl logs -n $namespace deploy/$gatewayServiceName`, then rerun the wrapper.',
      portForward: portForward,
    );
    await _assertGatewayHealthy(
      stageKey: 'smoke',
      likelyCause: 'gateway_not_healthy',
      nextAction: nextWrapperCommand(),
      portForward: portForward,
    );
  } finally {
    await portForward.stop();
  }
}

Future<void> _requireCommandAvailable(String tool, CommandSpec spec) async {
  try {
    final result = await Process.run(
      spec.command,
      spec.args,
      runInShell: false,
      workingDirectory: Directory.current.path,
    ).timeout(const Duration(seconds: 20));
    if (result.exitCode != 0) {
      throw StepFailure(
        stageKey: 'preflight',
        exitCode: result.exitCode == 0 ? 1 : result.exitCode,
        likelyCause: '${tool}_missing',
        nextAction: 'Install $tool and rerun.',
        detail:
            '`$tool` failed during preflight.\n${_trimmedOutput((result.stderr ?? result.stdout).toString())}',
      );
    }
  } on ProcessException catch (error) {
    throw StepFailure(
      stageKey: 'preflight',
      exitCode: error.errorCode == 0 ? 127 : error.errorCode,
      likelyCause: '${tool}_missing',
      nextAction: 'Install $tool and rerun.',
      detail: 'Unable to start `$tool`: ${error.message}',
    );
  } on TimeoutException {
    throw StepFailure(
      stageKey: 'preflight',
      exitCode: 124,
      likelyCause: '${tool}_missing',
      nextAction: 'Install $tool and rerun.',
      detail: '`$tool` did not respond during preflight.',
    );
  }
}

Future<CommandResult> _runCommand(
  CommandSpec spec, {
  required Duration timeout,
}) async {
  try {
    final result = await Process.run(
      spec.command,
      spec.args,
      runInShell: false,
      workingDirectory: Directory.current.path,
    ).timeout(timeout);
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  } on ProcessException catch (error) {
    return CommandResult(
      exitCode: error.errorCode == 0 ? 1 : error.errorCode,
      stdout: '',
      stderr: error.message,
    );
  } on TimeoutException {
    return const CommandResult(
      exitCode: 124,
      stdout: '',
      stderr: 'Command timed out.',
    );
  }
}

Future<PortForwardSession> _startPortForward() async {
  late final Process process;
  try {
    process = await Process.start(
      'kubectl',
      [
        '-n',
        namespace,
        'port-forward',
        'service/$gatewayServiceName',
        '$gatewayLocalPort:$gatewayLocalPort',
      ],
      runInShell: false,
      workingDirectory: Directory.current.path,
    );
  } on ProcessException catch (error) {
    throw StepFailure(
      stageKey: 'gateway',
      exitCode: error.errorCode == 0 ? 1 : error.errorCode,
      likelyCause: 'gateway_not_healthy',
      nextAction:
          'Verify `kubectl` can reach the `$gatewayServiceName` service in namespace `$namespace`, then rerun the wrapper.',
      detail: 'Unable to start kubectl port-forward: ${error.message}',
    );
  }

  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  int? exitCode;

  process.stdout
      .transform(utf8.decoder)
      .listen(stdoutBuffer.write, onError: (_) {});
  process.stderr
      .transform(utf8.decoder)
      .listen(stderrBuffer.write, onError: (_) {});
  unawaited(
    process.exitCode.then((code) {
      exitCode = code;
    }),
  );

  final startedAt = DateTime.now();
  while (DateTime.now().difference(startedAt) < const Duration(seconds: 20)) {
    if (exitCode != null) {
      throw StepFailure(
        stageKey: 'gateway',
        exitCode: exitCode == 0 ? 1 : exitCode!,
        likelyCause: 'gateway_not_healthy',
        nextAction:
            'Run `kubectl get svc,pods -n $namespace` and confirm `$gatewayServiceName` exists before rerunning.',
        detail:
            'kubectl port-forward exited early.\n${_trimmedOutput('${stdoutBuffer.toString()}\n${stderrBuffer.toString()}')}',
      );
    }

    final probe = await _fetchHttp(Uri.parse(gatewayUrl));
    if (probe.statusCode == 200) {
      return PortForwardSession(
        process: process,
        stdoutBuffer: stdoutBuffer,
        stderrBuffer: stderrBuffer,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  final session = PortForwardSession(
    process: process,
    stdoutBuffer: stdoutBuffer,
    stderrBuffer: stderrBuffer,
  );
  await session.stop();
  throw StepFailure(
    stageKey: 'gateway',
    exitCode: 124,
    likelyCause: 'gateway_not_healthy',
    nextAction:
        'Run `kubectl get svc,pods -n $namespace` and `kubectl logs -n $namespace deploy/$gatewayServiceName`, then rerun the wrapper.',
    detail:
        'Timed out waiting for kubectl port-forward to expose $gatewayUrl.\n${_trimmedOutput('${stdoutBuffer.toString()}\n${stderrBuffer.toString()}')}',
  );
}

Future<void> _assertGatewayHealthy({
  required String stageKey,
  required String likelyCause,
  required String nextAction,
  required PortForwardSession portForward,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));

  while (DateTime.now().isBefore(deadline)) {
    final probe = await _fetchHttp(Uri.parse(gatewayUrl));
    if (probe.statusCode == 200) {
      return;
    }
    if (probe.statusCode != null && probe.statusCode != 200) {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: 1,
        likelyCause: likelyCause,
        nextAction: nextAction,
        detail:
            'Gateway probe returned HTTP ${probe.statusCode}. Body: ${_trimmedOutput(probe.body)}',
      );
    }
    if (portForward.hasExited) {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: portForward.exitCode ?? 1,
        likelyCause: likelyCause,
        nextAction: nextAction,
        detail:
            'kubectl port-forward exited before the gateway became healthy.\n${_trimmedOutput(portForward.combinedOutput)}',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  throw StepFailure(
    stageKey: stageKey,
    exitCode: 124,
    likelyCause: likelyCause,
    nextAction: nextAction,
    detail: 'Timed out waiting for $gatewayUrl to return HTTP 200.',
  );
}

Future<HttpProbeResult> _fetchHttp(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return HttpProbeResult(statusCode: response.statusCode, body: body);
  } on SocketException catch (error) {
    return HttpProbeResult(connectionError: error.message);
  } on HttpException catch (error) {
    return HttpProbeResult(connectionError: error.message);
  } finally {
    client.close(force: true);
  }
}

Future<HelmTelemetrySummary> appendHelmTelemetry(
  HelmTelemetryEntry entry, {
  String historyPath = helmTelemetryHistoryPath,
  int maxEntries = helmTelemetryMaxEntries,
}) async {
  final file = File(historyPath);
  final history = <Map<String, Object?>>[];

  if (file.existsSync()) {
    final lines = await file.readAsLines();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          history.add(decoded);
        }
      } on FormatException {
        continue;
      }
    }
  }

  history.add(entry.toJson());
  final bounded = history.length <= maxEntries
      ? history
      : history.sublist(history.length - maxEntries);

  await file.parent.create(recursive: true);
  await file.writeAsString(
    bounded
            .map((item) => jsonEncode(item))
            .join('\n') +
        '\n',
    flush: true,
  );

  return HelmTelemetrySummary(
    historyPath: historyPath,
    recentEntries: bounded.length,
  );
}

String currentFrontDoorShell({Map<String, String>? environment, bool? isWindows}) {
  final effectiveEnvironment = environment ?? Platform.environment;
  final configured = effectiveEnvironment['BABY_TALK_FRONT_DOOR_SHELL']?.trim();
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }

  final effectiveIsWindows = isWindows ?? Platform.isWindows;
  return effectiveIsWindows ? 'cmd' : 'posix';
}

String nextWrapperCommand({Map<String, String>? environment, bool? isWindows}) {
  final shell = currentFrontDoorShell(
    environment: environment,
    isWindows: isWindows,
  ).toLowerCase();
  return shell == 'cmd'
      ? r'scripts\dev-verify-helm-demo.cmd'
      : './scripts/dev-verify-helm-demo.sh';
}

void _printSuccess({required int tthwSeconds, required String nextAction}) {
  stdout.writeln('demo_status=passed');
  stdout.writeln('tthw_seconds=$tthwSeconds');
  stdout.writeln('next_action=$nextAction');
  stdout.writeln('gateway_url=$gatewayUrl');
  stdout.writeln('telemetry_path=$helmTelemetryHistoryPath');
}

void _printFailure(
  StepFailure failure, {
  required int tthwSeconds,
  required String nextAction,
}) {
  stdout.writeln('demo_status=failed');
  stdout.writeln('tthw_seconds=$tthwSeconds');
  stdout.writeln('first_failure_stage=${failure.stageKey}');
  stdout.writeln('likely_cause=${failure.likelyCause}');
  stdout.writeln('next_action=$nextAction');
  stdout.writeln('gateway_url=$gatewayUrl');
  stdout.writeln('telemetry_path=$helmTelemetryHistoryPath');
  stderr.writeln(failure.detail);
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

class CliOptions {
  CliOptions({
    required this.mode,
    required this.showHelp,
    required this.usageError,
  });

  final ExecutionMode mode;
  final bool showHelp;
  final String? usageError;

  factory CliOptions.parse(List<String> args) {
    ExecutionMode mode = ExecutionMode.demo;
    var showHelp = false;
    String? usageError;
    String? selectedMode;

    for (final arg in args) {
      switch (arg) {
        case 'demo':
        case 'smoke':
          if (selectedMode != null) {
            usageError = 'Only one mode may be provided.';
          } else {
            selectedMode = arg;
            mode = arg == 'demo' ? ExecutionMode.demo : ExecutionMode.smoke;
          }
          break;
        case '--help':
        case '-h':
          showHelp = true;
          break;
        default:
          usageError = 'Unknown argument: $arg';
      }
    }

    if (!showHelp && usageError == null && selectedMode == null) {
      usageError = 'Missing mode: expected `demo` or `smoke`.';
    }

    return CliOptions(mode: mode, showHelp: showHelp, usageError: usageError);
  }
}

enum ExecutionMode { demo, smoke }

class CommandSpec {
  const CommandSpec({required this.command, required this.args});

  final String command;
  final List<String> args;
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
    required this.likelyCause,
    required this.nextAction,
    required this.detail,
  });

  final String stageKey;
  final int exitCode;
  final String likelyCause;
  final String nextAction;
  final String detail;
}

class PortForwardSession {
  PortForwardSession({
    required this.process,
    required this.stdoutBuffer,
    required this.stderrBuffer,
  }) {
    unawaited(
      process.exitCode.then((code) {
        _exitCode = code;
      }),
    );
  }

  final Process process;
  final StringBuffer stdoutBuffer;
  final StringBuffer stderrBuffer;
  int? _exitCode;

  bool get hasExited => _exitCode != null;
  int? get exitCode => _exitCode;
  String get combinedOutput => '${stdoutBuffer.toString()}\n${stderrBuffer.toString()}';

  Future<void> stop() async {
    if (_exitCode != null) {
      return;
    }

    process.kill();
    try {
      _exitCode = await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill();
    }
  }
}

class HttpProbeResult {
  const HttpProbeResult({
    this.statusCode,
    this.body = '',
    this.connectionError,
  });

  final int? statusCode;
  final String body;
  final String? connectionError;
}

class HelmTelemetryEntry {
  const HelmTelemetryEntry({
    required this.mode,
    required this.shell,
    required this.success,
    required this.tthwSeconds,
    required this.firstFailureStage,
    required this.likelyCause,
    required this.nextAction,
    required this.timestampIso8601,
  });

  final String mode;
  final String shell;
  final bool success;
  final int tthwSeconds;
  final String firstFailureStage;
  final String likelyCause;
  final String nextAction;
  final String timestampIso8601;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'mode': mode,
      'shell': shell,
      'success': success,
      'tthw_seconds': tthwSeconds,
      'first_failure_stage': firstFailureStage,
      'likely_cause': likelyCause,
      'next_action': nextAction,
      'timestamp': timestampIso8601,
      'timestamp_iso8601': timestampIso8601,
    };
  }
}

class HelmTelemetrySummary {
  const HelmTelemetrySummary({
    required this.historyPath,
    required this.recentEntries,
  });

  final String historyPath;
  final int recentEntries;
}
