import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _canonicalBrowserSpecs = <String>[
  'auth-and-rbac.spec.ts',
  'users-management.spec.ts',
  'knowledge-ops.spec.ts',
];

const _composeHealthServices = <String>[
  'postgres',
  'minio',
  'app-api',
  'admin-api',
  'admin-web',
];

const _composeServiceOrder = <String>[
  'postgres',
  'minio',
  'db-migration',
  'app-api',
  'admin-api',
  'admin-web',
];

const _composeDiagnosticServices = <String>[
  'db-migration',
  'app-api',
  'admin-api',
  'admin-web',
  'minio',
];

const _playwrightConfigPath = 'admin-web/playwright.config.ts';
const _playwrightGlobalSetupPath = 'admin-web/playwright.global-setup.ts';
const _playwrightReportDirectoryPath = 'admin-web/playwright-report';
const _playwrightReportIndexPath = 'admin-web/playwright-report/index.html';
const _helmSmokeScriptPath = 'ci/k8s-smoke.sh';
const _appApiHealthUrl = 'http://127.0.0.1:8080/actuator/health';
const _adminApiHealthUrl = 'http://127.0.0.1:8081/actuator/health';
const _adminWebUrl = 'http://127.0.0.1:3000/';

Future<void> main(List<String> args) async {
  final options = ReleaseVerifierOptions.parse(args);

  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  if (options.usageError != null) {
    stderr.writeln(options.usageError);
    stderr.writeln(_usage);
    exit(64);
  }

  final selectedTargets = <String>[
    if (options.runRuntime) 'runtime',
    if (options.runHelm) 'helm',
  ];
  stdout.writeln('Selected verification targets: ${selectedTargets.join(', ')}');

  try {
    if (options.runRuntime) {
      await _runCommandStep(
        stepLabel: 'Runtime | compose boot',
        spec: _dockerComposeCommand(['up', '-d', '--build']),
        timeout: const Duration(minutes: 15),
      );
      await _verifyRuntimeComposeTruth();
      await _runCommandStep(
        stepLabel: 'Runtime | backend reactor tests',
        spec: _mavenWrapperCommand(['-f', 'backend/pom.xml', '-q', 'test', '-DexcludedGroups=llm-it']),
        timeout: const Duration(minutes: 20),
      );
      await _runCanonicalBrowserProof();
    }

    if (options.runHelm) {
      await _runHelmSmokeProof();
    }
  } on StepFailure catch (error) {
    stderr.writeln('Verification failed at step: ${error.stepLabel}');
    stderr.writeln(error.message);
    exit(error.exitCode);
  }

  stdout.writeln('');
  stdout.writeln('All M006/S08 release verification steps passed.');
}

Future<void> _verifyRuntimeComposeTruth() async {
  const stepLabel = 'Runtime | migration-first compose truth';
  _announceStep(
    stepLabel,
    'docker compose ps --all --format json + actuator health probes + admin-web landing check',
  );

  final snapshot = await _waitForComposeRuntimeReady(stepLabel, const Duration(minutes: 4));
  await _assertHealthPayload(stepLabel, 'app-api', Uri.parse(_appApiHealthUrl));
  await _assertHealthPayload(stepLabel, 'admin-api', Uri.parse(_adminApiHealthUrl));
  await _assertAdminWebLanding(stepLabel, Uri.parse(_adminWebUrl));

  stdout.writeln('Compose runtime truth confirmed:');
  for (final serviceName in _composeServiceOrder) {
    stdout.writeln('  - ${_formatComposeEntry(snapshot[serviceName], serviceName)}');
  }
}

Future<Map<String, ComposeServiceStatus>> _waitForComposeRuntimeReady(
  String stepLabel,
  Duration timeout,
) async {
  final startedAt = DateTime.now();
  ComposeRuntimeAssessment? lastAssessment;

  while (DateTime.now().difference(startedAt) < timeout) {
    final snapshot = await _readComposeSnapshot(stepLabel);
    lastAssessment = _assessComposeSnapshot(snapshot);

    if (lastAssessment.ready) {
      return snapshot;
    }

    if (lastAssessment.hardFailure) {
      await _dumpComposeDiagnostics();
      throw StepFailure(stepLabel, lastAssessment.message, 1);
    }

    await Future<void>.delayed(const Duration(seconds: 2));
  }

  await _dumpComposeDiagnostics();
  throw StepFailure(
    stepLabel,
    'Timed out after ${timeout.inMinutes}m waiting for runtime services. '
    '${lastAssessment?.message ?? 'docker compose did not materialize the expected services.'}',
    124,
  );
}

Future<Map<String, ComposeServiceStatus>> _readComposeSnapshot(String stepLabel) async {
  final result = await _runCapturedCommand(
    spec: _dockerComposeCommand(['ps', '--all', '--format', 'json']),
    timeout: const Duration(seconds: 20),
  );

  if (result.exitCode != 0) {
    throw StepFailure(
      stepLabel,
      'Unable to inspect docker compose state (exit ${result.exitCode}).\n${_trimmedOutput(result.combinedOutput)}',
      result.exitCode,
    );
  }

  late final List<ComposeServiceStatus> entries;
  try {
    entries = _parseComposePs(result.stdout);
  } on FormatException catch (error) {
    throw StepFailure(
      stepLabel,
      'docker compose ps returned malformed JSON: ${error.message}. Raw output:\n${_trimmedOutput(result.stdout)}',
      1,
    );
  }

  final byService = <String, ComposeServiceStatus>{};
  for (final entry in entries) {
    byService[entry.service] = entry;
  }
  return byService;
}

ComposeRuntimeAssessment _assessComposeSnapshot(Map<String, ComposeServiceStatus> snapshot) {
  final pending = <String>[];
  final hardFailures = <String>[];

  for (final serviceName in _composeHealthServices) {
    final entry = snapshot[serviceName];
    if (entry == null) {
      pending.add('$serviceName missing from docker compose ps --all');
      continue;
    }

    final state = entry.state.toLowerCase();
    final health = entry.health.toLowerCase();

    if (state == 'dead' || state == 'exited') {
      hardFailures.add(_formatComposeEntry(entry, serviceName));
      continue;
    }

    if (health == 'unhealthy') {
      hardFailures.add(_formatComposeEntry(entry, serviceName));
      continue;
    }

    if (state != 'running' || health != 'healthy') {
      pending.add(_formatComposeEntry(entry, serviceName));
    }
  }

  final migration = snapshot['db-migration'];
  if (migration == null) {
    pending.add('db-migration missing from docker compose ps --all');
  } else {
    final migrationState = migration.state.toLowerCase();
    if (migrationState == 'exited') {
      if (migration.exitCode == null) {
        hardFailures.add('${_formatComposeEntry(migration, 'db-migration')} (missing exit code metadata)');
      } else if (migration.exitCode != 0) {
        hardFailures.add(_formatComposeEntry(migration, 'db-migration'));
      }
    } else if (migrationState == 'dead') {
      hardFailures.add(_formatComposeEntry(migration, 'db-migration'));
    } else {
      pending.add(_formatComposeEntry(migration, 'db-migration'));
    }
  }

  if (hardFailures.isNotEmpty) {
    return ComposeRuntimeAssessment.failure(
      'Compose runtime hit a hard failure:\n- ${hardFailures.join('\n- ')}',
    );
  }

  if (pending.isNotEmpty) {
    return ComposeRuntimeAssessment.pending(
      'Still waiting for runtime services:\n- ${pending.join('\n- ')}',
    );
  }

  return const ComposeRuntimeAssessment.ready();
}

Future<void> _assertHealthPayload(String stepLabel, String serviceName, Uri uri) async {
  final startedAt = DateTime.now();
  const timeout = Duration(seconds: 30);

  while (DateTime.now().difference(startedAt) < timeout) {
    final healthResponse = await _fetchHttp(uri);
    if (healthResponse.connectionError != null) {
      await Future<void>.delayed(const Duration(seconds: 2));
      continue;
    }

    if (healthResponse.statusCode != 200) {
      await _dumpComposeDiagnostics();
      throw StepFailure(
        stepLabel,
        '$serviceName health probe returned HTTP ${healthResponse.statusCode} from $uri. Body:\n'
        '${_redactSensitiveText(healthResponse.body)}',
        1,
      );
    }

    late final Object? decodedBody;
    try {
      decodedBody = jsonDecode(healthResponse.body);
    } on FormatException catch (error) {
      await _dumpComposeDiagnostics();
      throw StepFailure(
        stepLabel,
        '$serviceName health probe returned malformed JSON: ${error.message}. Body:\n'
        '${_redactSensitiveText(healthResponse.body)}',
        1,
      );
    }

    if (decodedBody is! Map<String, dynamic>) {
      await _dumpComposeDiagnostics();
      throw StepFailure(
        stepLabel,
        '$serviceName health probe returned a non-object payload. Body:\n'
        '${_redactSensitiveText(healthResponse.body)}',
        1,
      );
    }

    final status = decodedBody['status']?.toString();
    if (status != 'UP') {
      await _dumpComposeDiagnostics();
      throw StepFailure(
        stepLabel,
        '$serviceName health probe was reachable but not healthy. Body:\n'
        '${_redactSensitiveText(healthResponse.body)}',
        1,
      );
    }

    stdout.writeln('  - $serviceName actuator status=UP');
    return;
  }

  await _dumpComposeDiagnostics();
  throw StepFailure(
    stepLabel,
    'Timed out after ${timeout.inSeconds}s while reaching $serviceName health probe at $uri.',
    124,
  );
}

Future<void> _assertAdminWebLanding(String stepLabel, Uri uri) async {
  final startedAt = DateTime.now();
  const timeout = Duration(seconds: 30);

  while (DateTime.now().difference(startedAt) < timeout) {
    final response = await _fetchHttp(uri);
    if (response.connectionError != null) {
      await Future<void>.delayed(const Duration(seconds: 2));
      continue;
    }

    if (response.statusCode != 200) {
      await _dumpComposeDiagnostics();
      throw StepFailure(
        stepLabel,
        'admin-web landing check returned HTTP ${response.statusCode} from $uri. Body:\n'
        '${_redactSensitiveText(response.body)}',
        1,
      );
    }

    if (!response.body.contains('BabyTalk Admin')) {
      await _dumpComposeDiagnostics();
      throw StepFailure(
        stepLabel,
        'admin-web landing page did not contain the expected BabyTalk Admin marker. Body:\n'
        '${_redactSensitiveText(response.body)}',
        1,
      );
    }

    stdout.writeln('  - admin-web landing page responded with the BabyTalk Admin shell');
    return;
  }

  await _dumpComposeDiagnostics();
  throw StepFailure(
    stepLabel,
    'Timed out after ${timeout.inSeconds}s while reaching admin-web at $uri.',
    124,
  );
}

Future<HttpProbeResult> _fetchHttp(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return HttpProbeResult(statusCode: response.statusCode, body: body);
  } on SocketException catch (error) {
    return HttpProbeResult(connectionError: error.message);
  } on HandshakeException catch (error) {
    return HttpProbeResult(connectionError: error.message);
  } on HttpException catch (error) {
    return HttpProbeResult(connectionError: error.message);
  } finally {
    client.close(force: true);
  }
}

Future<void> _runCanonicalBrowserProof() async {
  const stepLabel = 'Runtime | canonical admin browser proof pack';
  final browserSpecPaths = [
    _playwrightConfigPath,
    _playwrightGlobalSetupPath,
    ..._canonicalBrowserSpecs.map((spec) => 'admin-web/tests/$spec'),
  ];
  final missingPaths = browserSpecPaths.where((path) => !FileSystemEntity.typeSync(path).exists).toList();
  if (missingPaths.isNotEmpty) {
    throw StepFailure(
      stepLabel,
      'Playwright wiring is incomplete; required files are missing:\n- ${missingPaths.join('\n- ')}',
      1,
    );
  }

  final reportDirectory = Directory(_playwrightReportDirectoryPath);
  if (reportDirectory.existsSync()) {
    stdout.writeln('Removing stale Playwright report at ${reportDirectory.path}.');
    await reportDirectory.delete(recursive: true);
  }

  final command = _npmCommand(
    ['--prefix', 'admin-web', 'run', 'test:e2e', '--', ..._canonicalBrowserSpecs],
    environment: const {'BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT': '1'},
  );

  _announceStep(stepLabel, command.displayCommand);
  stdout.writeln('Canonical specs: ${_canonicalBrowserSpecs.join(', ')}');

  final exitCode = await _runProcess(
    stepLabel: stepLabel,
    spec: command,
    timeout: const Duration(minutes: 20),
    failOnNonZero: false,
  );

  final reportIndex = File(_playwrightReportIndexPath);
  if (!reportIndex.existsSync()) {
    throw StepFailure(
      stepLabel,
      'Playwright did not materialize $_playwrightReportIndexPath. '
      'The browser report/config wiring regressed or the runner failed before report creation.',
      exitCode == 0 ? 1 : exitCode,
    );
  }

  if (exitCode != 0) {
    stderr.writeln('Playwright HTML report: ${reportIndex.path}');
    throw StepFailure(
      stepLabel,
      'Canonical admin browser proof pack failed. Inspect the failing spec output above '
      'and the HTML report at ${reportIndex.path}.',
      exitCode,
    );
  }

  stdout.writeln('Playwright HTML report: ${reportIndex.path}');
}

Future<void> _runHelmSmokeProof() async {
  const stepLabel = 'Helm | split-stack smoke proof';
  final smokeScript = File(_helmSmokeScriptPath);
  if (!smokeScript.existsSync()) {
    throw StepFailure(
      stepLabel,
      'Helm smoke script is missing at ${smokeScript.path}.',
      1,
    );
  }

  await _runCommandStep(
    stepLabel: stepLabel,
    spec: _bashCommand([_helmSmokeScriptPath]),
    timeout: const Duration(minutes: 5),
  );
}

Future<void> _runCommandStep({
  required String stepLabel,
  required CommandSpec spec,
  required Duration timeout,
}) async {
  _announceStep(stepLabel, spec.displayCommand);
  await _runProcess(stepLabel: stepLabel, spec: spec, timeout: timeout);
}

void _announceStep(String stepLabel, String displayCommand) {
  stdout.writeln('');
  stdout.writeln('==> $stepLabel');
  stdout.writeln(r'$ ' + displayCommand);
}

Future<int> _runProcess({
  required String stepLabel,
  required CommandSpec spec,
  required Duration timeout,
  bool failOnNonZero = true,
}) async {
  late final Process process;
  try {
    process = await Process.start(
      spec.command,
      spec.args,
      workingDirectory: Directory.current.path,
      mode: ProcessStartMode.inheritStdio,
      runInShell: false,
      environment: spec.environment,
    );
  } on ProcessException catch (error) {
    throw StepFailure(
      stepLabel,
      'Unable to start `${spec.displayCommand}`: ${error.message}',
      error.errorCode == 0 ? 1 : error.errorCode,
    );
  }

  try {
    final exitCode = await process.exitCode.timeout(timeout);
    if (exitCode != 0 && failOnNonZero) {
      throw StepFailure(stepLabel, '`${spec.displayCommand}` exited with code $exitCode.', exitCode);
    }
    return exitCode;
  } on TimeoutException {
    process.kill(ProcessSignal.sigterm);
    await Future<void>.delayed(const Duration(seconds: 2));
    process.kill(ProcessSignal.sigkill);
    throw StepFailure(
      stepLabel,
      'Timed out after ${timeout.inMinutes}m while running `${spec.displayCommand}`.',
      124,
    );
  }
}

Future<CapturedCommandResult> _runCapturedCommand({
  required CommandSpec spec,
  required Duration timeout,
}) async {
  try {
    final result = await Process.run(
      spec.command,
      spec.args,
      workingDirectory: Directory.current.path,
      runInShell: false,
      environment: spec.environment,
    ).timeout(timeout);

    return CapturedCommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  } on ProcessException catch (error) {
    return CapturedCommandResult(
      exitCode: error.errorCode == 0 ? 1 : error.errorCode,
      stdout: '',
      stderr: error.message,
    );
  } on TimeoutException {
    return const CapturedCommandResult(
      exitCode: 124,
      stdout: '',
      stderr: 'Command timed out.',
    );
  }
}

Future<void> _dumpComposeDiagnostics() async {
  stderr.writeln('');
  stderr.writeln('Compose diagnostics (sanitized):');

  final psResult = await _runCapturedCommand(
    spec: _dockerComposeCommand(['ps', '--all']),
    timeout: const Duration(seconds: 20),
  );
  final psOutput = _trimmedOutput(psResult.combinedOutput);
  if (psOutput.isNotEmpty) {
    stderr.writeln(_redactSensitiveText(psOutput));
  }

  final logsResult = await _runCapturedCommand(
    spec: _dockerComposeCommand(['logs', '--no-color', '--tail', '120', ..._composeDiagnosticServices]),
    timeout: const Duration(seconds: 30),
  );
  final logsOutput = _trimmedOutput(logsResult.combinedOutput);
  if (logsOutput.isNotEmpty) {
    stderr.writeln(_redactSensitiveText(logsOutput));
  }
}

List<ComposeServiceStatus> _parseComposePs(String rawJson) {
  final trimmed = rawJson.trim();
  if (trimmed.isEmpty) {
    return const <ComposeServiceStatus>[];
  }

  final decoded = trimmed.startsWith('[')
      ? jsonDecode(trimmed)
      : LineSplitter.split(trimmed)
          .where((line) => line.trim().isNotEmpty)
          .map((line) => jsonDecode(line))
          .toList();

  if (decoded is! List) {
    throw const FormatException('docker compose ps did not return a JSON list.');
  }

  return decoded
      .whereType<Map>()
      .map((entry) => ComposeServiceStatus.fromJson(entry.cast<String, Object?>()))
      .toList();
}

String _formatComposeEntry(ComposeServiceStatus? entry, String fallbackServiceName) {
  if (entry == null) {
    return '$fallbackServiceName: missing';
  }

  final parts = <String>['state=${entry.state}'];
  if (entry.health.isNotEmpty) {
    parts.add('health=${entry.health}');
  }
  if (entry.exitCode != null) {
    parts.add('exit=${entry.exitCode}');
  }
  if (entry.statusText.isNotEmpty) {
    parts.add('status="${entry.statusText}"');
  }
  return '${entry.service}: ${parts.join(', ')}';
}

String _trimmedOutput(String text) => text.trim().isEmpty ? '' : text.trim();

String _redactSensitiveText(String text) {
  var redacted = text;
  redacted = redacted.replaceAllMapped(
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    (_) => 'Bearer [REDACTED]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
    (_) => '[REDACTED_JWT]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(
      r'((?:password|secret|token|jwt|authorization)[^:=\n\r]{0,40}[:=]\s*)([^\s,;]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[REDACTED]',
  );
  redacted = redacted.replaceAll('SuperAdmin123!', '[REDACTED]');
  redacted = redacted.replaceAll('babytalk123', '[REDACTED]');
  return redacted;
}

CommandSpec _bashCommand(List<String> args, {Map<String, String>? environment}) {
  return _platformCommand(
    displayCommand: 'bash ${args.join(' ')}',
    unixCommand: 'bash',
    unixArgs: args,
    windowsArgs: ['bash', ...args],
    environment: environment,
  );
}

CommandSpec _dockerComposeCommand(List<String> args, {Map<String, String>? environment}) {
  return _platformCommand(
    displayCommand: 'docker compose ${args.join(' ')}',
    unixCommand: 'docker',
    unixArgs: ['compose', ...args],
    windowsArgs: ['docker', 'compose', ...args],
    environment: environment,
  );
}

CommandSpec _mavenWrapperCommand(List<String> args) {
  return _platformCommand(
    displayCommand: 'backend/mvnw ${args.join(' ')}',
    unixCommand: 'backend/mvnw',
    unixArgs: args,
    windowsArgs: [r'backend\mvnw.cmd', ...args],
  );
}

CommandSpec _npmCommand(List<String> args, {Map<String, String>? environment}) {
  if (Platform.isWindows) {
    return CommandSpec(
      command: 'npm.cmd',
      args: args,
      displayCommand: 'npm ${args.join(' ')}',
      environment: environment,
    );
  }

  return CommandSpec(
    command: 'npm',
    args: args,
    displayCommand: 'npm ${args.join(' ')}',
    environment: environment,
  );
}

CommandSpec _platformCommand({
  required String displayCommand,
  required String unixCommand,
  required List<String> unixArgs,
  required List<String> windowsArgs,
  Map<String, String>? environment,
}) {
  if (Platform.isWindows) {
    return CommandSpec(
      command: 'cmd',
      args: ['/c', ...windowsArgs],
      displayCommand: displayCommand,
      environment: environment,
    );
  }

  return CommandSpec(
    command: unixCommand,
    args: unixArgs,
    displayCommand: displayCommand,
    environment: environment,
  );
}

const _usage = '''Usage: dart run tool/verify_m006_s08_release.dart [--runtime] [--helm]

Verification targets:
  --runtime   Run the migration-first compose + backend + canonical admin browser proof pack.
  --helm      Run the named Helm smoke proof (lint/template/test-hook/NOTES truth).

With no flags, the verifier runs the full release gate: runtime + helm.
''';

class ReleaseVerifierOptions {
  ReleaseVerifierOptions({
    required this.runRuntime,
    required this.runHelm,
    required this.showHelp,
    required this.usageError,
  });

  final bool runRuntime;
  final bool runHelm;
  final bool showHelp;
  final String? usageError;

  factory ReleaseVerifierOptions.parse(List<String> args) {
    var runRuntime = false;
    var runHelm = false;
    var showHelp = false;
    String? usageError;

    for (final arg in args) {
      switch (arg) {
        case '--runtime':
          runRuntime = true;
          break;
        case '--helm':
          runHelm = true;
          break;
        case '--help':
        case '-h':
          showHelp = true;
          break;
        default:
          usageError = 'Unknown argument: $arg';
      }
    }

    if (!runRuntime && !runHelm && !showHelp && usageError == null) {
      runRuntime = true;
      runHelm = true;
    }

    return ReleaseVerifierOptions(
      runRuntime: runRuntime,
      runHelm: runHelm,
      showHelp: showHelp,
      usageError: usageError,
    );
  }
}

class CommandSpec {
  const CommandSpec({
    required this.command,
    required this.args,
    required this.displayCommand,
    this.environment,
  });

  final String command;
  final List<String> args;
  final String displayCommand;
  final Map<String, String>? environment;
}

class CapturedCommandResult {
  const CapturedCommandResult({
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
  const StepFailure(this.stepLabel, this.message, this.exitCode);

  final String stepLabel;
  final String message;
  final int exitCode;
}

class ComposeRuntimeAssessment {
  const ComposeRuntimeAssessment._({
    required this.ready,
    required this.hardFailure,
    required this.message,
  });

  const ComposeRuntimeAssessment.ready()
      : this._(ready: true, hardFailure: false, message: 'ready');

  ComposeRuntimeAssessment.pending(String message)
      : this._(ready: false, hardFailure: false, message: message);

  ComposeRuntimeAssessment.failure(String message)
      : this._(ready: false, hardFailure: true, message: message);

  final bool ready;
  final bool hardFailure;
  final String message;
}

class ComposeServiceStatus {
  const ComposeServiceStatus({
    required this.service,
    required this.state,
    required this.health,
    required this.exitCode,
    required this.statusText,
  });

  factory ComposeServiceStatus.fromJson(Map<String, Object?> json) {
    final rawExitCode = json['ExitCode'];
    return ComposeServiceStatus(
      service: json['Service']?.toString() ?? json['Name']?.toString() ?? 'unknown-service',
      state: json['State']?.toString() ?? 'unknown',
      health: json['Health']?.toString() ?? '',
      exitCode: rawExitCode == null || rawExitCode.toString().isEmpty
          ? null
          : int.tryParse(rawExitCode.toString()),
      statusText: json['Status']?.toString() ?? '',
    );
  }

  final String service;
  final String state;
  final String health;
  final int? exitCode;
  final String statusText;
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

extension on FileSystemEntityType {
  bool get exists => this != FileSystemEntityType.notFound;
}
