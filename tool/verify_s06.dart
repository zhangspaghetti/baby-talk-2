import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(_usage);
    return;
  }

  final mobileDirectory = Directory('mobile');
  if (!mobileDirectory.existsSync()) {
    _fail('未找到 mobile/ 子工程，无法执行 S06 proof pack。', 64);
  }

  final runIntegration = options.runIntegration || !options.hasExplicitMode;
  final runInspect = options.runInspect || !options.hasExplicitMode;

  final requiredFiles = <String>{};
  if (runIntegration) {
    requiredFiles.addAll(const [
      'mobile/test/smoke/app_boot_test.dart',
      'mobile/test/features/mentor/mentor_shell_panel_test.dart',
      'mobile/integration_test/s06_full_chain_release_flow_test.dart',
    ]);
  }
  if (runInspect) {
    requiredFiles.addAll(const [
      'tool/inspect_interaction_events.dart',
      'tool/inspect_mentor_facts.dart',
      'mobile/tool/inspect_interaction_events.dart',
      'mobile/tool/inspect_mentor_facts.dart',
    ]);
  }
  _assertFilesExist(requiredFiles);

  final steps = <_VerifyStep>[];
  if (runIntegration) {
    const baseUrl = 'http://127.0.0.1:18080';
    final flutterExecutable = _resolveFlutterExecutable();
    steps.addAll([
      _VerifyStep(
        label: 'S06 smoke app_boot_test',
        executable: flutterExecutable,
        arguments: const ['test', 'test/smoke/app_boot_test.dart'],
        workingDirectory: mobileDirectory.path,
        timeout: const Duration(minutes: 6),
      ),
      _VerifyStep(
        label: 'S06 mentor widget mentor_shell_panel_test',
        executable: flutterExecutable,
        arguments: const [
          'test',
          'test/features/mentor/mentor_shell_panel_test.dart',
        ],
        workingDirectory: mobileDirectory.path,
        timeout: const Duration(minutes: 6),
      ),
      _VerifyStep(
        label: 'S06 full-chain integration s06_full_chain_release_flow_test',
        executable: flutterExecutable,
        arguments: const [
          'test',
          'integration_test/s06_full_chain_release_flow_test.dart',
          '--dart-define=BABY_TALK_API_BASE_URL=$baseUrl',
          '--dart-define=BABY_TALK_API_VERSION=1.2.0',
        ],
        workingDirectory: mobileDirectory.path,
        timeout: const Duration(minutes: 12),
      ),
    ]);
  }

  if (runInspect) {
    steps.addAll([
      _VerifyStep(
        label: 'S06 inspect interaction events help',
        executable: Platform.resolvedExecutable,
        arguments: const [
          'run',
          'tool/inspect_interaction_events.dart',
          '--help',
        ],
        timeout: const Duration(minutes: 2),
      ),
      _VerifyStep(
        label: 'S06 inspect mentor facts help',
        executable: Platform.resolvedExecutable,
        arguments: const ['run', 'tool/inspect_mentor_facts.dart', '--help'],
        timeout: const Duration(minutes: 2),
      ),
    ]);
  }

  if (steps.isEmpty) {
    _fail('没有可执行的 verify 步骤。请传入 --inspect 或 --integration。', 64);
  }

  for (final step in steps) {
    final exitCode = await _runStep(step);
    if (exitCode != 0) {
      stderr.writeln('❌ ${step.label} 失败，exit code=$exitCode');
      exit(exitCode);
    }
  }

  stdout.writeln('✅ S06 continuity / mentor / retention proof pack 完成。');
}

Future<int> _runStep(_VerifyStep step) async {
  stdout.writeln('==> ${step.label}');
  stdout.writeln('    ${_formatCommand(step)}');

  final process = await Process.start(
    step.executable,
    step.arguments,
    workingDirectory: step.workingDirectory,
    mode: ProcessStartMode.normal,
  );

  final stdoutDone = stdout.addStream(process.stdout);
  final stderrDone = stderr.addStream(process.stderr);

  final exitCode = await process.exitCode.timeout(
    step.timeout,
    onTimeout: () {
      stderr.writeln('步骤 `${step.label}` 超时（${step.timeout.inSeconds}s），已中止。');
      process.kill();
      return 124;
    },
  );

  await Future.wait<void>([stdoutDone, stderrDone]);
  return exitCode;
}

void _assertFilesExist(Iterable<String> paths) {
  final missing = <String>[];
  for (final path in paths) {
    if (!File(path).existsSync()) {
      missing.add(path);
    }
  }

  if (missing.isEmpty) {
    return;
  }

  stderr.writeln('S06 proof pack 缺少必要文件：');
  for (final path in missing) {
    stderr.writeln('  - $path');
  }
  exit(64);
}

Never _fail(String message, int exitCode) {
  stderr.writeln(message);
  exit(exitCode);
}

String _formatCommand(_VerifyStep step) {
  final prefix = step.workingDirectory == null
      ? ''
      : '(cd ${step.workingDirectory} && ';
  final suffix = step.workingDirectory == null ? '' : ')';
  return '$prefix${step.executable} ${step.arguments.join(' ')}$suffix';
}

String _resolveFlutterExecutable() {
  final executableName = Platform.isWindows ? 'flutter.bat' : 'flutter';

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final candidate = File(
      '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}$executableName',
    );
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }

  final dartBinDirectory = File(Platform.resolvedExecutable).parent;
  final inferredFlutterBin = dartBinDirectory.parent.parent.parent;
  final inferredCandidate = File(
    '${inferredFlutterBin.path}${Platform.pathSeparator}$executableName',
  );
  if (inferredCandidate.existsSync()) {
    return inferredCandidate.path;
  }

  return executableName;
}

class _VerifyStep {
  const _VerifyStep({
    required this.label,
    required this.executable,
    required this.arguments,
    required this.timeout,
    this.workingDirectory,
  });

  final String label;
  final String executable;
  final List<String> arguments;
  final Duration timeout;
  final String? workingDirectory;
}

class _CliOptions {
  const _CliOptions({
    required this.showHelp,
    required this.runIntegration,
    required this.runInspect,
  });

  final bool showHelp;
  final bool runIntegration;
  final bool runInspect;

  bool get hasExplicitMode => runIntegration || runInspect;

  static _CliOptions parse(List<String> args) {
    var showHelp = false;
    var runIntegration = false;
    var runInspect = false;

    for (final arg in args) {
      switch (arg) {
        case '--help':
        case '-h':
          showHelp = true;
          break;
        case '--integration':
          runIntegration = true;
          break;
        case '--inspect':
          runInspect = true;
          break;
        default:
          stderr.writeln('未知参数：$arg\n');
          stderr.writeln(_usage);
          exit(64);
      }
    }

    return _CliOptions(
      showHelp: showHelp,
      runIntegration: runIntegration,
      runInspect: runInspect,
    );
  }
}

const String _usage = '''用法：
  dart run tool/verify_s06.dart [--integration] [--inspect]

说明：
  --integration  从仓库根顺序代理 S06 smoke/widget/integration proof
                 - mobile/test/smoke/app_boot_test.dart
                 - mobile/test/features/mentor/mentor_shell_panel_test.dart
                 - mobile/integration_test/s06_full_chain_release_flow_test.dart
  --inspect      从仓库根顺序代理 inspect_interaction_events / inspect_mentor_facts --help
  --help, -h     显示帮助

默认：
  不带参数时同时执行 integration 与 inspect 两组步骤。

当前 continuity / mentor proof 约束：
  - Home 下一步 key: home-start-practice-<activityId>
  - Garden 下一步 key: garden-continue-target-<activityId>
  - Mentor failure surface: blocked_fallback / timeout / correlationId

超时策略：
  smoke 6 分钟，widget 6 分钟，integration 12 分钟，inspect 单步 2 分钟；
  任一步失败或超时都会返回非 0 exit code，并保留失败 step label。
''';
