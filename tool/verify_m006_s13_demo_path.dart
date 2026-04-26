import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _adminWebUrl = 'http://127.0.0.1:3000';
const _adminWebLoginUrl = 'http://127.0.0.1:3000/login';
const _appApiHealthUrl = 'http://127.0.0.1:8080/actuator/health';
const _adminApiHealthUrl = 'http://127.0.0.1:8081/actuator/health';
const _demoUsername = 'super_admin';

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

const _verificationDocs = <String>[
  'README.md',
  'CONTRIBUTING.md',
  'mobile/README.md',
  'docs/runbooks/m006-s13-demo-path.md',
];

const _requiredPaths = <String>[
  'README.md',
  'CONTRIBUTING.md',
  'mobile/README.md',
  'scripts/dev-up-admin-demo.sh',
  'scripts/dev-up-admin-demo.cmd',
  'scripts/dev-verify-admin-demo.sh',
  'scripts/dev-verify-admin-demo.cmd',
  'docs/runbooks/m006-s13-demo-path.md',
  'docs/runbooks/m006-s12-control-plane-freshness.md',
  'docs/runbooks/k8s-deploy.md',
  'tool/verify_m006_s12_control_plane_freshness.dart',
  'tool/verify_m006_s13_demo_path.dart',
  'backend/mvnw',
  'backend/mvnw.cmd',
  'bash.cmd',
  'test.cmd',
];

const _s12LiveStackOnlyFlag = '--live-stack-only';
const frontDoorTelemetryHistoryPath = 'tmp/m006-s13-front-door-metrics.jsonl';
const frontDoorTelemetryMaxBytes = 64 * 1024;
const frontDoorTelemetrySummaryWindow = 24;

const _usage =
    '''Usage: dart run tool/verify_m006_s13_demo_path.dart [verify|demo|smoke] [--help]

Modes:
  verify   Static proof that the repo-root front door is truthful (default).
  demo     Boot the split stack and print the admin demo handoff contract.
  smoke    Reuse the live stack and run the fast admin smoke proof.
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

  switch (options.mode) {
    case ExecutionMode.verify:
      await _runStaticVerification();
      return;
    case ExecutionMode.demo:
      await _runDemoMode();
      return;
    case ExecutionMode.smoke:
      await _runSmokeMode();
      return;
  }
}

Future<void> _runStaticVerification() async {
  const stage = 'verify_contract';
  final startedAt = DateTime.now();

  try {
    _announceStage('verify | required artifacts');
    final missingPaths = _requiredPaths
        .where((path) => !FileSystemEntity.typeSync(path).exists)
        .toList();
    if (missingPaths.isNotEmpty) {
      throw StepFailure(
        stageKey: stage,
        exitCode: 1,
        likelyCause: 'required_front_door_artifact_missing',
        nextAction:
            'Create the missing repo-root scripts/docs first, then rerun this verifier.',
        detail:
            'Missing required S13 artifacts:\n- ${missingPaths.join('\n- ')}',
      );
    }
    stdout.writeln('  - All required S13 front-door artifacts are present.');

    _announceStage('verify | docs truth');
    final readme = await File('README.md').readAsString();
    final contributing = await File('CONTRIBUTING.md').readAsString();
    final mobileReadme = await File('mobile/README.md').readAsString();
    final runbook = await File(
      'docs/runbooks/m006-s13-demo-path.md',
    ).readAsString();

    _requireContains(readme, 'README.md', [
      'dev-up-admin-demo',
      'dev-verify-admin-demo',
      'admin-web',
      'admin-api',
      'CONTRIBUTING',
      '/api/admin/auth/login',
      '/api/admin/auth/refresh',
      '/api/admin/overview/summary',
      'm006-s13-front-door-metrics.jsonl',
      'first_failure_hotspot',
      '旧单体 → 新 split-stack',
    ]);
    _requireAbsent(readme, 'README.md', [
      '项目不包含 Maven Wrapper',
      '请使用系统安装的 `mvn` 命令',
      'A new Flutter project',
    ]);

    _requireContains(contributing, 'CONTRIBUTING.md', [
      'dev-up-admin-demo',
      'dev-verify-admin-demo',
      'backend/mvnw',
      'admin-web',
      'verification',
      'm006-s13-front-door-metrics.jsonl',
      'first_failure_hotspot',
    ]);

    _requireContains(mobileReadme, 'mobile/README.md', [
      'Baby Talk 2 mobile',
      'flutter pub get',
      'flutter run',
      'app-api',
      'm006-s13-front-door-metrics.jsonl',
    ]);
    _requireAbsent(mobileReadme, 'mobile/README.md', [
      'A new Flutter project',
      'This project is a starting point for a Flutter application.',
    ]);

    _requireContains(runbook, 'docs/runbooks/m006-s13-demo-path.md', [
      'dev-up-admin-demo',
      'dev-verify-admin-demo',
      'first_failure_stage',
      'm006-s13-front-door-metrics.jsonl',
      'smoke_recent_pass_rate',
      'first_failure_hotspot',
      'Windows / POSIX parity',
      'M006 / S12 Overview Control-Plane Freshness Runbook',
    ]);
    stdout.writeln(
      '  - README / CONTRIBUTING / mobile README / runbook carry the new front-door contract.',
    );

    _announceStage('verify | relative links');
    for (final docPath in _verificationDocs) {
      await _verifyRelativeMarkdownLinks(docPath);
    }
    stdout.writeln(
      '  - All checked relative markdown links resolve to tracked files.',
    );

    _announceStage('verify | wrapper parity');
    final demoShell = await File('scripts/dev-up-admin-demo.sh').readAsString();
    final demoCmd = await File('scripts/dev-up-admin-demo.cmd').readAsString();
    final smokeShell = await File(
      'scripts/dev-verify-admin-demo.sh',
    ).readAsString();
    final smokeCmd = await File(
      'scripts/dev-verify-admin-demo.cmd',
    ).readAsString();

    _requirePattern(
      demoShell,
      'scripts/dev-up-admin-demo.sh',
      RegExp(r'dart\s+run\s+tool/verify_m006_s13_demo_path\.dart\s+demo'),
      'demo shell wrapper must delegate to the shared verifier in demo mode.',
    );
    _requirePattern(
      demoCmd,
      'scripts/dev-up-admin-demo.cmd',
      RegExp(
        r'dart\s+run\s+tool[\\/]verify_m006_s13_demo_path\.dart\s+demo',
        caseSensitive: false,
      ),
      'demo cmd wrapper must delegate to the shared verifier in demo mode.',
    );
    _requirePattern(
      smokeShell,
      'scripts/dev-verify-admin-demo.sh',
      RegExp(r'dart\s+run\s+tool/verify_m006_s13_demo_path\.dart\s+smoke'),
      'smoke shell wrapper must delegate to the shared verifier in smoke mode.',
    );
    _requirePattern(
      smokeCmd,
      'scripts/dev-verify-admin-demo.cmd',
      RegExp(
        r'dart\s+run\s+tool[\\/]verify_m006_s13_demo_path\.dart\s+smoke',
        caseSensitive: false,
      ),
      'smoke cmd wrapper must delegate to the shared verifier in smoke mode.',
    );
    stdout.writeln(
      '  - POSIX and Windows wrappers point at the same verifier modes.',
    );
  } on StepFailure catch (error) {
    _reportFailure(modeLabel: 'verify', error: error, startedAt: startedAt);
    exit(error.exitCode);
  }

  stdout.writeln('');
  stdout.writeln('verify_status=passed');
  stdout.writeln(
    'tthw_seconds=${DateTime.now().difference(startedAt).inSeconds}',
  );
  stdout.writeln('first_failure_stage=none');
  stdout.writeln('All M006/S13 demo-path verification steps passed.');
}

Future<void> _runDemoMode() async {
  final startedAt = DateTime.now();
  StepFailure? failure;

  try {
    _announceStage('demo | preflight');
    await _requireCommandAvailable(
      'docker',
      CommandSpec(
        command: 'docker',
        args: ['--version'],
        displayCommand: 'docker --version',
      ),
      likelyCause: 'docker_missing',
      nextAction:
          'Install Docker Desktop / docker CLI, then rerun the demo wrapper.',
    );
    await _runCommandStep(
      stepLabel: 'demo | docker daemon',
      spec: const CommandSpec(
        command: 'docker',
        args: ['info'],
        displayCommand: 'docker info',
      ),
      timeout: const Duration(seconds: 20),
      likelyCause: 'docker_daemon_unreachable',
      nextAction:
          'Start Docker Desktop (or the daemon), then rerun the demo wrapper.',
      inheritStdio: false,
    );

    _announceStage('demo | compose boot');
    await _runCommandStep(
      stepLabel: 'compose_boot',
      spec: _dockerComposeCommand([
        'up',
        '-d',
        '--build',
        ..._composeServiceOrder,
      ]),
      timeout: const Duration(minutes: 15),
      likelyCause: 'compose_boot_failed',
      nextAction:
          'Run `docker compose ps --all` and `docker compose logs --no-color --tail 120 db-migration app-api admin-api admin-web`, then fix the first failing service.',
    );

    _announceStage('demo | runtime truth');
    final snapshot = await _waitForComposeRuntimeReady(
      stageKey: 'runtime_truth',
      timeout: const Duration(minutes: 4),
      nextAction:
          'Run `docker compose ps --all` and inspect the service that never reached healthy/exited-0, then rerun the demo wrapper.',
    );
    await _assertHealthPayload(
      stageKey: 'runtime_truth',
      serviceName: 'app-api',
      uri: Uri.parse(_appApiHealthUrl),
      nextAction:
          'Run `docker compose logs --no-color --tail 120 app-api` and fix the failing health dependency.',
    );
    await _assertHealthPayload(
      stageKey: 'runtime_truth',
      serviceName: 'admin-api',
      uri: Uri.parse(_adminApiHealthUrl),
      nextAction:
          'Run `docker compose logs --no-color --tail 120 admin-api` and fix the failing health dependency.',
    );
    await _assertAdminWebLanding(
      stageKey: 'runtime_truth',
      uri: Uri.parse(_adminWebUrl),
      nextAction:
          'Run `docker compose logs --no-color --tail 120 admin-web` and confirm the admin-web shell can proxy `/api`.',
    );

    stdout.writeln('  - Compose runtime truth confirmed:');
    for (final serviceName in _composeServiceOrder) {
      stdout.writeln(
        '    • ${_formatComposeEntry(snapshot[serviceName], serviceName)}',
      );
    }
  } on StepFailure catch (error) {
    failure = error;
  }

  if (failure != null) {
    await _reportModeFailure(
      modeLabel: 'demo',
      error: failure,
      startedAt: startedAt,
    );
    exit(failure.exitCode);
  }

  try {
    await _emitModeSuccess(
      modeLabel: 'demo',
      statusValue: 'ready',
      startedAt: startedAt,
      nextAction: _nextWrapperCommand(ExecutionMode.smoke),
      drillDown: 'dart run tool/verify_m006_s12_control_plane_freshness.dart',
      additionalLines: const [
        'admin_web_url=$_adminWebLoginUrl',
        'demo_account=$_demoUsername',
        'password_hint=Use your local BABY_TALK_ADMIN_BOOTSTRAP_PASSWORD value; this wrapper never prints it.',
        'health_hint=docker compose ps --all',
      ],
    );
  } on StepFailure catch (error) {
    _reportFailure(modeLabel: 'demo', error: error, startedAt: startedAt);
    exit(error.exitCode);
  }
}

Future<void> _runSmokeMode() async {
  final startedAt = DateTime.now();
  StepFailure? failure;

  try {
    _announceStage('smoke | preflight');
    await _requireCommandAvailable(
      'docker',
      CommandSpec(
        command: 'docker',
        args: ['--version'],
        displayCommand: 'docker --version',
      ),
      likelyCause: 'docker_missing',
      nextAction:
          'Install Docker Desktop / docker CLI, then rerun the smoke wrapper.',
    );
    await _requireCommandAvailable(
      'npm',
      _npmCommand(['--version']),
      likelyCause: 'npm_missing',
      nextAction: 'Install Node.js + npm, then rerun the smoke wrapper.',
    );

    _announceStage('smoke | live stack precondition');
    await _waitForComposeRuntimeReady(
      stageKey: 'live_stack_precondition',
      timeout: const Duration(seconds: 30),
      nextAction:
          'Run ${_nextWrapperCommand(ExecutionMode.demo)} first so the split stack is healthy before smoke proof.',
    );
    await _assertAdminWebLanding(
      stageKey: 'live_stack_precondition',
      uri: Uri.parse(_adminWebUrl),
      nextAction:
          'Run ${_nextWrapperCommand(ExecutionMode.demo)} first so admin-web is up before smoke proof.',
    );

    _announceStage('smoke | overview proof');
    await _runCommandStep(
      stepLabel: 'fast_smoke',
      spec: buildSmokeDelegateCommand(),
      timeout: const Duration(minutes: 20),
      likelyCause: 'control_plane_smoke_failed',
      nextAction:
          'Run `dart run tool/verify_m006_s12_control_plane_freshness.dart $_s12LiveStackOnlyFlag` directly to see the failing proof-pack step, then inspect the first failing Playwright spec.',
    );
  } on StepFailure catch (error) {
    failure = error;
  }

  if (failure != null) {
    await _reportModeFailure(
      modeLabel: 'smoke',
      error: failure,
      startedAt: startedAt,
    );
    exit(failure.exitCode);
  }

  try {
    await _emitModeSuccess(
      modeLabel: 'smoke',
      statusValue: 'passed',
      startedAt: startedAt,
      nextAction: 'dart run tool/verify_m006_s08_release.dart --runtime',
      drillDown: 'docs/runbooks/m006-s13-demo-path.md',
      additionalLines: const [],
    );
  } on StepFailure catch (error) {
    _reportFailure(modeLabel: 'smoke', error: error, startedAt: startedAt);
    exit(error.exitCode);
  }
}

Future<void> _verifyRelativeMarkdownLinks(String docPath) async {
  final document = await File(docPath).readAsString();
  final directory = File(docPath).parent;
  final pattern = RegExp(r'!?\[[^\]]+\]\(([^)]+)\)');

  for (final match in pattern.allMatches(document)) {
    final rawTarget = match.group(1)?.trim();
    if (rawTarget == null || rawTarget.isEmpty) {
      continue;
    }
    if (rawTarget.startsWith('http://') ||
        rawTarget.startsWith('https://') ||
        rawTarget.startsWith('mailto:') ||
        rawTarget.startsWith('tel:') ||
        rawTarget.startsWith('#')) {
      continue;
    }

    final targetWithoutAnchor = rawTarget.split('#').first.split('?').first;
    if (targetWithoutAnchor.isEmpty) {
      continue;
    }

    final resolved = directory.uri.resolve(Uri.encodeFull(targetWithoutAnchor));
    final localPath = Uri.decodeFull(resolved.toFilePath());
    final type = FileSystemEntity.typeSync(localPath);
    if (!type.exists) {
      throw StepFailure(
        stageKey: 'verify_contract',
        exitCode: 1,
        likelyCause: 'broken_relative_doc_link',
        nextAction:
            'Fix the stale markdown link and rerun `dart run tool/verify_m006_s13_demo_path.dart`.',
        detail: '$docPath links to a missing local target: $rawTarget',
      );
    }
  }
}

void _requireContains(String content, String fileLabel, List<String> needles) {
  final missing = needles.where((needle) => !content.contains(needle)).toList();
  if (missing.isNotEmpty) {
    throw StepFailure(
      stageKey: 'verify_contract',
      exitCode: 1,
      likelyCause: 'doc_contract_drift',
      nextAction:
          'Update the front-door docs so the missing markers are present, then rerun this verifier.',
      detail:
          '$fileLabel is missing expected markers:\n- ${missing.join('\n- ')}',
    );
  }
}

void _requireAbsent(String content, String fileLabel, List<String> needles) {
  final found = needles.where(content.contains).toList();
  if (found.isNotEmpty) {
    throw StepFailure(
      stageKey: 'verify_contract',
      exitCode: 1,
      likelyCause: 'stale_doc_copy_present',
      nextAction:
          'Delete the stale template / single-backend wording from the front-door docs, then rerun this verifier.',
      detail:
          '$fileLabel still contains forbidden stale text:\n- ${found.join('\n- ')}',
    );
  }
}

void _requirePattern(
  String content,
  String fileLabel,
  RegExp pattern,
  String failureMessage,
) {
  if (!pattern.hasMatch(content)) {
    throw StepFailure(
      stageKey: 'verify_contract',
      exitCode: 1,
      likelyCause: 'wrapper_parity_drift',
      nextAction:
          'Point the wrapper back to the shared verifier mode and rerun the contract verifier.',
      detail: '$failureMessage\nFile: $fileLabel',
    );
  }
}

Future<void> _requireCommandAvailable(
  String name,
  CommandSpec spec, {
  required String likelyCause,
  required String nextAction,
}) async {
  try {
    final result = await Process.run(
      spec.command,
      spec.args,
      runInShell: false,
      environment: spec.environment,
      workingDirectory: Directory.current.path,
    ).timeout(const Duration(seconds: 20));
    if (result.exitCode != 0) {
      throw StepFailure(
        stageKey: 'preflight',
        exitCode: result.exitCode == 0 ? 1 : result.exitCode,
        likelyCause: likelyCause,
        nextAction: nextAction,
        detail:
            '`$name` failed during preflight:\n${_trimmedOutput(result.stderr?.toString() ?? result.stdout?.toString() ?? '')}',
      );
    }
  } on ProcessException catch (error) {
    throw StepFailure(
      stageKey: 'preflight',
      exitCode: error.errorCode == 0 ? 127 : error.errorCode,
      likelyCause: likelyCause,
      nextAction: nextAction,
      detail: 'Unable to start `$name`: ${error.message}',
    );
  } on TimeoutException {
    throw StepFailure(
      stageKey: 'preflight',
      exitCode: 124,
      likelyCause: '${likelyCause}_timeout',
      nextAction: nextAction,
      detail: '`$name` did not respond during preflight.',
    );
  }
}

Future<void> _runCommandStep({
  required String stepLabel,
  required CommandSpec spec,
  required Duration timeout,
  required String likelyCause,
  required String nextAction,
  bool inheritStdio = true,
}) async {
  if (inheritStdio) {
    await _runInheritedProcess(
      spec: spec,
      stepLabel: stepLabel,
      timeout: timeout,
      likelyCause: likelyCause,
      nextAction: nextAction,
    );
    return;
  }

  final result = await _runCapturedCommand(spec: spec, timeout: timeout);
  if (result.exitCode != 0) {
    throw StepFailure(
      stageKey: stepLabel,
      exitCode: result.exitCode,
      likelyCause: likelyCause,
      nextAction: nextAction,
      detail:
          '`${spec.displayCommand}` exited with code ${result.exitCode}.\n${_trimmedOutput(result.combinedOutput)}',
    );
  }
}

Future<void> _runInheritedProcess({
  required CommandSpec spec,
  required String stepLabel,
  required Duration timeout,
  required String likelyCause,
  required String nextAction,
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
      stageKey: stepLabel,
      exitCode: error.errorCode == 0 ? 1 : error.errorCode,
      likelyCause: likelyCause,
      nextAction: nextAction,
      detail: 'Unable to start `${spec.displayCommand}`: ${error.message}',
    );
  }

  try {
    final exitCode = await process.exitCode.timeout(timeout);
    if (exitCode != 0) {
      throw StepFailure(
        stageKey: stepLabel,
        exitCode: exitCode,
        likelyCause: likelyCause,
        nextAction: nextAction,
        detail: '`${spec.displayCommand}` exited with code $exitCode.',
      );
    }
  } on TimeoutException {
    process.kill(ProcessSignal.sigterm);
    await Future<void>.delayed(const Duration(seconds: 2));
    process.kill(ProcessSignal.sigkill);
    throw StepFailure(
      stageKey: stepLabel,
      exitCode: 124,
      likelyCause: '${likelyCause}_timeout',
      nextAction: nextAction,
      detail:
          '`${spec.displayCommand}` exceeded the ${timeout.inMinutes}m budget.',
    );
  }
}

Future<Map<String, ComposeServiceStatus>> _waitForComposeRuntimeReady({
  required String stageKey,
  required Duration timeout,
  required String nextAction,
}) async {
  final startedAt = DateTime.now();
  ComposeRuntimeAssessment? lastAssessment;

  while (DateTime.now().difference(startedAt) < timeout) {
    final snapshot = await _readComposeSnapshot(stageKey);
    lastAssessment = _assessComposeSnapshot(snapshot);
    if (lastAssessment.ready) {
      return snapshot;
    }
    if (lastAssessment.hardFailure) {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: 1,
        likelyCause: 'compose_runtime_hard_failure',
        nextAction: nextAction,
        detail: lastAssessment.message,
      );
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  throw StepFailure(
    stageKey: stageKey,
    exitCode: 124,
    likelyCause: 'compose_runtime_timeout',
    nextAction: nextAction,
    detail:
        'Timed out after ${timeout.inSeconds}s while waiting for runtime services. ${lastAssessment?.message ?? ''}'
            .trim(),
  );
}

Future<Map<String, ComposeServiceStatus>> _readComposeSnapshot(
  String stageKey,
) async {
  final result = await _runCapturedCommand(
    spec: _dockerComposeCommand(['ps', '--all', '--format', 'json']),
    timeout: const Duration(seconds: 20),
  );
  if (result.exitCode != 0) {
    throw StepFailure(
      stageKey: stageKey,
      exitCode: result.exitCode,
      likelyCause: 'compose_state_unreadable',
      nextAction:
          'Run `docker compose ps --all` directly and fix docker compose availability before retrying.',
      detail:
          'Unable to inspect docker compose state.\n${_trimmedOutput(result.combinedOutput)}',
    );
  }

  try {
    final entries = _parseComposePs(result.stdout);
    return {for (final entry in entries) entry.service: entry};
  } on FormatException catch (error) {
    throw StepFailure(
      stageKey: stageKey,
      exitCode: 1,
      likelyCause: 'compose_state_malformed',
      nextAction:
          'Run `docker compose ps --all --format json` and inspect why the payload is malformed.',
      detail: 'docker compose ps returned malformed JSON: ${error.message}',
    );
  }
}

ComposeRuntimeAssessment _assessComposeSnapshot(
  Map<String, ComposeServiceStatus> snapshot,
) {
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
    final state = migration.state.toLowerCase();
    if (state == 'exited') {
      if (migration.exitCode == null) {
        hardFailures.add(
          '${_formatComposeEntry(migration, 'db-migration')} (missing exit code metadata)',
        );
      } else if (migration.exitCode != 0) {
        hardFailures.add(_formatComposeEntry(migration, 'db-migration'));
      }
    } else if (state == 'dead') {
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
    throw const FormatException(
      'docker compose ps did not return a JSON list.',
    );
  }

  return decoded
      .whereType<Map>()
      .map(
        (entry) => ComposeServiceStatus.fromJson(entry.cast<String, Object?>()),
      )
      .toList();
}

Future<void> _assertHealthPayload({
  required String stageKey,
  required String serviceName,
  required Uri uri,
  required String nextAction,
}) async {
  final startedAt = DateTime.now();
  const timeout = Duration(seconds: 30);
  while (DateTime.now().difference(startedAt) < timeout) {
    final response = await _fetchHttp(uri);
    if (response.connectionError != null) {
      await Future<void>.delayed(const Duration(seconds: 2));
      continue;
    }
    if (response.statusCode != 200) {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: 1,
        likelyCause: '${serviceName}_health_http_failure',
        nextAction: nextAction,
        detail:
            '$serviceName health probe returned HTTP ${response.statusCode}. Body: ${_redactSensitiveText(response.body)}',
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: 1,
        likelyCause: '${serviceName}_health_malformed_payload',
        nextAction: nextAction,
        detail:
            '$serviceName health probe returned malformed JSON: ${error.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: 1,
        likelyCause: '${serviceName}_health_non_object_payload',
        nextAction: nextAction,
        detail: '$serviceName health probe returned a non-object payload.',
      );
    }

    final status = decoded['status']?.toString();
    if (status != 'UP') {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: 1,
        likelyCause: '${serviceName}_health_not_up',
        nextAction: nextAction,
        detail: '$serviceName health probe returned status=$status.',
      );
    }

    stdout.writeln('  - $serviceName actuator status=UP');
    return;
  }

  throw StepFailure(
    stageKey: stageKey,
    exitCode: 124,
    likelyCause: '${serviceName}_health_timeout',
    nextAction: nextAction,
    detail: 'Timed out while reaching $serviceName health probe at $uri.',
  );
}

Future<void> _assertAdminWebLanding({
  required String stageKey,
  required Uri uri,
  required String nextAction,
}) async {
  final startedAt = DateTime.now();
  const timeout = Duration(seconds: 30);
  while (DateTime.now().difference(startedAt) < timeout) {
    final response = await _fetchHttp(uri);
    if (response.connectionError != null) {
      await Future<void>.delayed(const Duration(seconds: 2));
      continue;
    }
    if (response.statusCode != 200) {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: 1,
        likelyCause: 'admin_web_http_failure',
        nextAction: nextAction,
        detail: 'admin-web landing returned HTTP ${response.statusCode}.',
      );
    }
    if (!response.body.contains('BabyTalk Admin')) {
      throw StepFailure(
        stageKey: stageKey,
        exitCode: 1,
        likelyCause: 'admin_web_marker_missing',
        nextAction: nextAction,
        detail:
            'admin-web landing page did not contain the expected BabyTalk Admin marker.',
      );
    }
    stdout.writeln(
      '  - admin-web landing page responded with the BabyTalk Admin shell',
    );
    return;
  }

  throw StepFailure(
    stageKey: stageKey,
    exitCode: 124,
    likelyCause: 'admin_web_timeout',
    nextAction: nextAction,
    detail: 'Timed out while reaching admin-web at $uri.',
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

CommandSpec buildSmokeDelegateCommand({Map<String, String>? environment}) {
  return CommandSpec(
    command: Platform.resolvedExecutable,
    args: [
      'run',
      'tool/verify_m006_s12_control_plane_freshness.dart',
      _s12LiveStackOnlyFlag,
    ],
    displayCommand:
        'dart run tool/verify_m006_s12_control_plane_freshness.dart $_s12LiveStackOnlyFlag',
    environment: {
      ...Platform.environment,
      'BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT': '1',
      if (environment != null) ...environment,
    },
  );
}

Future<void> _emitModeSuccess({
  required String modeLabel,
  required String statusValue,
  required DateTime startedAt,
  required String nextAction,
  required String drillDown,
  required List<String> additionalLines,
}) async {
  final tthwSeconds = DateTime.now().difference(startedAt).inSeconds;
  final summary = await appendFrontDoorTelemetry(
    FrontDoorTelemetryEntry(
      mode: modeLabel,
      shell: _currentFrontDoorShell(),
      success: true,
      tthwSeconds: tthwSeconds,
      firstFailureStage: 'none',
      likelyCause: 'none',
      nextAction: nextAction,
      recordedAtUtc: DateTime.now().toUtc(),
    ),
  );

  stdout.writeln('');
  stdout.writeln('${modeLabel}_status=$statusValue');
  stdout.writeln('tthw_seconds=$tthwSeconds');
  stdout.writeln('first_failure_stage=none');
  for (final line in additionalLines) {
    stdout.writeln(line);
  }
  stdout.writeln('next_action=$nextAction');
  stdout.writeln('drill_down=$drillDown');
  _printTelemetrySummary(summary);
}

Future<void> _reportModeFailure({
  required String modeLabel,
  required StepFailure error,
  required DateTime startedAt,
}) async {
  final tthwSeconds = DateTime.now().difference(startedAt).inSeconds;

  try {
    final summary = await appendFrontDoorTelemetry(
      FrontDoorTelemetryEntry(
        mode: modeLabel,
        shell: _currentFrontDoorShell(),
        success: false,
        tthwSeconds: tthwSeconds,
        firstFailureStage: error.stageKey,
        likelyCause: error.likelyCause,
        nextAction: error.nextAction,
        recordedAtUtc: DateTime.now().toUtc(),
      ),
    );
    _reportFailure(modeLabel: modeLabel, error: error, startedAt: startedAt);
    _printTelemetrySummary(summary);
  } on StepFailure catch (telemetryError) {
    stderr.writeln(
      'Original ${modeLabel} failure stage=${error.stageKey} likely_cause=${error.likelyCause}',
    );
    stderr.writeln(error.detail);
    _reportFailure(
      modeLabel: modeLabel,
      error: telemetryError,
      startedAt: startedAt,
    );
  }
}

Future<FrontDoorTelemetrySummary> appendFrontDoorTelemetry(
  FrontDoorTelemetryEntry entry, {
  String historyPath = frontDoorTelemetryHistoryPath,
  int maxBytes = frontDoorTelemetryMaxBytes,
  int windowSize = frontDoorTelemetrySummaryWindow,
}) async {
  final historyFile = File(historyPath);

  try {
    await historyFile.parent.create(recursive: true);
    await historyFile.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  } on FileSystemException catch (error) {
    throw StepFailure(
      stageKey: 'telemetry_history',
      exitCode: 1,
      likelyCause: 'telemetry_append_failed',
      nextAction:
          'Fix write access to $historyPath (or remove the broken file), then rerun the front-door wrapper.',
      detail: 'Unable to append front-door telemetry: ${error.message}',
    );
  }

  final recentLines = await _readRecentTelemetryLines(
    historyPath,
    maxBytes: maxBytes,
  );
  return summarizeFrontDoorTelemetryLines(
    recentLines,
    historyPath: historyPath,
    windowSize: windowSize,
  );
}

FrontDoorTelemetrySummary summarizeFrontDoorTelemetryLines(
  Iterable<String> lines, {
  String historyPath = frontDoorTelemetryHistoryPath,
  int windowSize = frontDoorTelemetrySummaryWindow,
}) {
  final rawLines = lines.toList(growable: false);
  final window = rawLines.length <= windowSize
      ? rawLines
      : rawLines.sublist(rawLines.length - windowSize);

  final entries = <FrontDoorTelemetryEntry>[];
  var ignoredLines = 0;

  for (final rawLine in window) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      ignoredLines += 1;
      continue;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        ignoredLines += 1;
        continue;
      }
      entries.add(FrontDoorTelemetryEntry.fromJson(decoded));
    } on FormatException {
      ignoredLines += 1;
    }
  }

  final smokeEntries = entries
      .where((entry) => entry.mode == 'smoke')
      .toList(growable: false);
  final smokeSuccesses = smokeEntries.where((entry) => entry.success).length;
  final hotspotCounts = <String, int>{};

  for (final entry in smokeEntries.where((entry) => !entry.success)) {
    final stage = entry.firstFailureStage.trim();
    if (stage.isEmpty || stage == 'none') {
      continue;
    }
    hotspotCounts.update(stage, (count) => count + 1, ifAbsent: () => 1);
  }

  var firstFailureHotspot = 'none';
  var highestCount = 0;
  for (final entry in hotspotCounts.entries) {
    final shouldReplace =
        entry.value > highestCount ||
        (entry.value == highestCount &&
            (firstFailureHotspot == 'none' ||
                entry.key.compareTo(firstFailureHotspot) < 0));
    if (shouldReplace) {
      firstFailureHotspot = entry.key;
      highestCount = entry.value;
    }
  }

  return FrontDoorTelemetrySummary(
    historyPath: historyPath,
    recentEntries: entries.length,
    ignoredLines: ignoredLines,
    smokeAttempts: smokeEntries.length,
    smokeSuccesses: smokeSuccesses,
    firstFailureHotspot: firstFailureHotspot,
  );
}

Future<List<String>> _readRecentTelemetryLines(
  String historyPath, {
  int maxBytes = frontDoorTelemetryMaxBytes,
}) async {
  final historyFile = File(historyPath);
  if (!historyFile.existsSync()) {
    return const <String>[];
  }

  RandomAccessFile? handle;
  try {
    handle = await historyFile.open();
    final length = await handle.length();
    final start = length > maxBytes ? length - maxBytes : 0;
    await handle.setPosition(start);
    final chunk = await handle.read(length - start);
    var text = utf8.decode(chunk, allowMalformed: true);
    if (start > 0) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline == -1) {
        return const <String>[];
      }
      text = text.substring(firstNewline + 1);
    }
    return const LineSplitter().convert(text);
  } on FileSystemException catch (error) {
    throw StepFailure(
      stageKey: 'telemetry_history',
      exitCode: 1,
      likelyCause: 'telemetry_history_unreadable',
      nextAction:
          'Fix read access to $historyPath (or remove the broken file), then rerun the front-door wrapper.',
      detail: 'Unable to read recent front-door telemetry: ${error.message}',
    );
  } finally {
    await handle?.close();
  }
}

void _printTelemetrySummary(FrontDoorTelemetrySummary summary) {
  stdout.writeln('telemetry_path=${summary.historyPath}');
  stdout.writeln('telemetry_recent_entries=${summary.recentEntries}');
  stdout.writeln('telemetry_ignored_lines=${summary.ignoredLines}');
  stdout.writeln('smoke_recent_attempts=${summary.smokeAttempts}');
  stdout.writeln('smoke_recent_successes=${summary.smokeSuccesses}');
  stdout.writeln('smoke_recent_pass_rate=${summary.smokePassRateDisplay}');
  stdout.writeln('first_failure_hotspot=${summary.firstFailureHotspot}');
}

String _currentFrontDoorShell() {
  final configured = Platform.environment['BABY_TALK_FRONT_DOOR_SHELL']?.trim();
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }
  return Platform.isWindows ? 'cmd' : 'posix';
}

void _announceStage(String label) {
  stdout.writeln('');
  stdout.writeln('==> $label');
}

void _reportFailure({
  required String modeLabel,
  required StepFailure error,
  required DateTime startedAt,
}) {
  stdout.writeln('');
  stdout.writeln('${modeLabel}_status=failed');
  stdout.writeln(
    'tthw_seconds=${DateTime.now().difference(startedAt).inSeconds}',
  );
  stdout.writeln('first_failure_stage=${error.stageKey}');
  stdout.writeln('likely_cause=${error.likelyCause}');
  stdout.writeln('next_action=${error.nextAction}');
  stderr.writeln(error.detail);
}

String _formatComposeEntry(
  ComposeServiceStatus? entry,
  String fallbackServiceName,
) {
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

String _trimmedOutput(String text) {
  final trimmed = text.trim();
  return trimmed.length <= 800 ? trimmed : '${trimmed.substring(0, 800)}...';
}

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

CommandSpec _dockerComposeCommand(
  List<String> args, {
  Map<String, String>? environment,
}) {
  return CommandSpec(
    command: 'docker',
    args: ['compose', ...args],
    displayCommand: 'docker compose ${args.join(' ')}',
    environment: environment,
  );
}

CommandSpec _npmCommand(List<String> args, {Map<String, String>? environment}) {
  return CommandSpec(
    command: Platform.isWindows ? 'npm.cmd' : 'npm',
    args: args,
    displayCommand: 'npm ${args.join(' ')}',
    environment: environment,
  );
}

String _nextWrapperCommand(ExecutionMode mode) {
  final shellFlavor = Platform.environment['BABY_TALK_FRONT_DOOR_SHELL']
      ?.toLowerCase();
  final prefersPosix =
      shellFlavor == 'posix' || (shellFlavor == null && !Platform.isWindows);

  return switch (mode) {
    ExecutionMode.demo =>
      prefersPosix
          ? './scripts/dev-up-admin-demo.sh'
          : 'scripts\\dev-up-admin-demo.cmd',
    ExecutionMode.smoke =>
      prefersPosix
          ? './scripts/dev-verify-admin-demo.sh'
          : 'scripts\\dev-verify-admin-demo.cmd',
    ExecutionMode.verify => 'dart run tool/verify_m006_s13_demo_path.dart',
  };
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
    var mode = ExecutionMode.verify;
    var showHelp = false;
    String? usageError;

    for (final arg in args) {
      switch (arg) {
        case 'verify':
          mode = ExecutionMode.verify;
          break;
        case 'demo':
          mode = ExecutionMode.demo;
          break;
        case 'smoke':
          mode = ExecutionMode.smoke;
          break;
        case '--help':
        case '-h':
          showHelp = true;
          break;
        default:
          usageError = 'Unknown argument: $arg';
      }
    }

    return CliOptions(mode: mode, showHelp: showHelp, usageError: usageError);
  }
}

enum ExecutionMode { verify, demo, smoke }

class FrontDoorTelemetryEntry {
  const FrontDoorTelemetryEntry({
    required this.mode,
    required this.shell,
    required this.success,
    required this.tthwSeconds,
    required this.firstFailureStage,
    required this.likelyCause,
    required this.nextAction,
    required this.recordedAtUtc,
  });

  factory FrontDoorTelemetryEntry.fromJson(Map<String, dynamic> json) {
    final mode = json['mode']?.toString().trim();
    final shell = json['shell']?.toString().trim();
    final firstFailureStage = json['first_failure_stage']?.toString().trim();
    final likelyCause = json['likely_cause']?.toString().trim();
    final nextAction = json['next_action']?.toString().trim();

    if (mode == null || mode.isEmpty) {
      throw const FormatException('mode is required');
    }
    if (shell == null || shell.isEmpty) {
      throw const FormatException('shell is required');
    }
    if (firstFailureStage == null || firstFailureStage.isEmpty) {
      throw const FormatException('first_failure_stage is required');
    }
    if (likelyCause == null || likelyCause.isEmpty) {
      throw const FormatException('likely_cause is required');
    }
    if (nextAction == null || nextAction.isEmpty) {
      throw const FormatException('next_action is required');
    }

    final successRaw = json['success'];
    final success = switch (successRaw) {
      bool value => value,
      String value when value.toLowerCase() == 'true' => true,
      String value when value.toLowerCase() == 'false' => false,
      _ => throw const FormatException('success must be a boolean'),
    };

    final tthwRaw = json['tthw_seconds'];
    final tthwSeconds = switch (tthwRaw) {
      int value => value,
      num value => value.toInt(),
      String value =>
        int.tryParse(value) ??
            (throw const FormatException('tthw_seconds must be an integer')),
      _ => throw const FormatException('tthw_seconds is required'),
    };

    final recordedAtRaw = json['recorded_at_utc']?.toString();
    final recordedAtUtc =
        DateTime.tryParse(recordedAtRaw ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return FrontDoorTelemetryEntry(
      mode: mode,
      shell: shell,
      success: success,
      tthwSeconds: tthwSeconds,
      firstFailureStage: firstFailureStage,
      likelyCause: likelyCause,
      nextAction: nextAction,
      recordedAtUtc: recordedAtUtc,
    );
  }

  final String mode;
  final String shell;
  final bool success;
  final int tthwSeconds;
  final String firstFailureStage;
  final String likelyCause;
  final String nextAction;
  final DateTime recordedAtUtc;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'recorded_at_utc': recordedAtUtc.toIso8601String(),
      'mode': mode,
      'shell': shell,
      'success': success,
      'tthw_seconds': tthwSeconds,
      'first_failure_stage': _redactSensitiveText(firstFailureStage),
      'likely_cause': _redactSensitiveText(likelyCause),
      'next_action': _redactSensitiveText(nextAction),
    };
  }
}

class FrontDoorTelemetrySummary {
  const FrontDoorTelemetrySummary({
    required this.historyPath,
    required this.recentEntries,
    required this.ignoredLines,
    required this.smokeAttempts,
    required this.smokeSuccesses,
    required this.firstFailureHotspot,
  });

  final String historyPath;
  final int recentEntries;
  final int ignoredLines;
  final int smokeAttempts;
  final int smokeSuccesses;
  final String firstFailureHotspot;

  String get smokePassRateDisplay {
    if (smokeAttempts == 0) {
      return 'n/a';
    }
    final percentage = ((smokeSuccesses / smokeAttempts) * 100).toStringAsFixed(
      0,
    );
    return '$percentage% ($smokeSuccesses/$smokeAttempts)';
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
      service:
          json['Service']?.toString() ??
          json['Name']?.toString() ??
          'unknown-service',
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
