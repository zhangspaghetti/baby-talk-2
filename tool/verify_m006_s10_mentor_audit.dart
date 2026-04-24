import 'dart:io';

Future<void> main() async {
  final repoRoot = Directory.current;
  final steps = <VerificationStep>[
    VerificationStep(
      name: 'Focused backend contract',
      command: Platform.isWindows ? 'cmd' : 'backend/mvnw',
      args: Platform.isWindows
          ? ['/c', r'backend\mvnw.cmd', '-f', 'backend/pom.xml', '-q', '-pl', 'admin-api', '-am', 'test', '-Dtest=AdminMentorAuditWebTest']
          : ['-f', 'backend/pom.xml', '-q', '-pl', 'admin-api', '-am', 'test', '-Dtest=AdminMentorAuditWebTest'],
    ),
    VerificationStep(
      name: 'admin-web build',
      command: Platform.isWindows ? 'npm.cmd' : 'npm',
      args: ['--prefix', 'admin-web', 'run', 'build'],
    ),
    VerificationStep(
      name: 'mentor Playwright spec',
      command: Platform.isWindows ? 'npm.cmd' : 'npm',
      args: ['--prefix', 'admin-web', 'run', 'test:e2e', '--', 'mentor-audit.spec.ts'],
    ),
    VerificationStep(
      name: 'inspect helper smoke',
      command: Platform.resolvedExecutable,
      args: ['run', 'tool/inspect_mentor_facts.dart', '--help'],
    ),
  ];

  for (final step in steps) {
    stdout.writeln('');
    stdout.writeln('==> ${step.name}');
    stdout.writeln(r'$ ${step.renderedCommand}');

    final process = await Process.start(
      step.command,
      step.args,
      workingDirectory: repoRoot.path,
      mode: ProcessStartMode.inheritStdio,
      runInShell: false,
    );
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      stderr.writeln('Verification failed at step: ${step.name} (exit $exitCode)');
      exit(exitCode);
    }
  }

  stdout.writeln('');
  stdout.writeln('All M006/S10 mentor audit verification steps passed.');
}

class VerificationStep {
  VerificationStep({
    required this.name,
    required this.command,
    required this.args,
  });

  final String name;
  final String command;
  final List<String> args;

  String get renderedCommand => ([command, ...args]).join(' ');
}
