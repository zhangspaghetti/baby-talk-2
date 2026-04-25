import 'dart:async';
import 'dart:io';

Future<void> main() async {
  final repoRoot = Directory.current;
  final steps = <VerificationStep>[
    VerificationStep(
      name: 'Focused backend contracts',
      command: Platform.isWindows ? 'cmd' : 'backend/mvnw',
      args: Platform.isWindows
          ? [
              '/c',
              r'backend\mvnw.cmd',
              '-f',
              'backend/pom.xml',
              '-q',
              '-pl',
              'admin-api',
              '-am',
              'test',
              '-Dtest=AdminMentorAuditWebTest,AdminDistributionStatsWebTest',
            ]
          : [
              '-f',
              'backend/pom.xml',
              '-q',
              '-pl',
              'admin-api',
              '-am',
              'test',
              '-Dtest=AdminMentorAuditWebTest,AdminDistributionStatsWebTest',
            ],
      timeout: const Duration(minutes: 8),
    ),
    VerificationStep(
      name: 'admin-web build',
      command: Platform.isWindows ? 'npm.cmd' : 'npm',
      args: ['--prefix', 'admin-web', 'run', 'build'],
      timeout: const Duration(minutes: 5),
    ),
    VerificationStep(
      name: 'Closure browser proof pack',
      command: Platform.isWindows ? 'npm.cmd' : 'npm',
      args: [
        '--prefix',
        'admin-web',
        'run',
        'test:e2e',
        '--',
        'access-and-landing.spec.ts',
        'mentor-audit.spec.ts',
        'distribution-stats.spec.ts',
        'mentor-distribution-closure.spec.ts',
      ],
      timeout: const Duration(minutes: 12),
    ),
  ];

  for (final step in steps) {
    stdout.writeln('');
    stdout.writeln('==> ${step.name}');
    stdout.writeln('\$ ${step.renderedCommand}');

    final exitCode = await runStep(step, repoRoot.path);
    if (exitCode != 0) {
      stderr.writeln('Verification failed at step: ${step.name} (exit $exitCode)');
      exit(exitCode);
    }
  }

  stdout.writeln('');
  stdout.writeln('All M006/S07 mentor + distribution verification steps passed.');
}

Future<int> runStep(VerificationStep step, String workingDirectory) async {
  late final Process process;
  try {
    process = await Process.start(
      step.command,
      step.args,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
      runInShell: false,
    );
  } on ProcessException catch (error) {
    stderr.writeln('Unable to start ${step.name}: ${error.message}');
    return error.errorCode == 0 ? 1 : error.errorCode;
  }

  try {
    return await process.exitCode.timeout(step.timeout);
  } on TimeoutException {
    stderr.writeln(
      'Timed out after ${step.timeout.inMinutes}m while running ${step.name}. Killing the hung step.',
    );
    process.kill(ProcessSignal.sigterm);
    await Future<void>.delayed(const Duration(seconds: 2));
    process.kill(ProcessSignal.sigkill);
    return 124;
  }
}

class VerificationStep {
  VerificationStep({
    required this.name,
    required this.command,
    required this.args,
    required this.timeout,
  });

  final String name;
  final String command;
  final List<String> args;
  final Duration timeout;

  String get renderedCommand => ([command, ...args]).join(' ');
}
