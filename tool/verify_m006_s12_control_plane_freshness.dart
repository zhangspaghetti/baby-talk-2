import 'dart:io';

const _requiredPaths = <String>[
  'admin-web/src/lib/overviewClient.ts',
  'admin-web/src/pages/OverviewPage.tsx',
  'admin-web/tests/overview-control-plane.spec.ts',
  'admin-web/tests/auth-and-rbac.spec.ts',
  'docs/runbooks/m006-s12-control-plane-freshness.md',
];

Future<void> main() async {
  final repoRoot = Directory.current;
  final missingPaths = _requiredPaths.where((path) => !File(path).existsSync()).toList();
  if (missingPaths.isNotEmpty) {
    stderr.writeln('Missing required S12 proof-pack files:');
    for (final path in missingPaths) {
      stderr.writeln('  - $path');
    }
    exit(1);
  }

  final steps = <VerificationStep>[
    VerificationStep(
      name: 'admin-web build',
      command: Platform.isWindows ? 'npm.cmd' : 'npm',
      args: ['--prefix', 'admin-web', 'run', 'build'],
    ),
    VerificationStep(
      name: 'overview browser proof pack',
      command: Platform.isWindows ? 'npm.cmd' : 'npm',
      args: ['--prefix', 'admin-web', 'run', 'test:e2e', '--', 'auth-and-rbac.spec.ts', 'overview-control-plane.spec.ts'],
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
  stdout.writeln('All M006/S12 overview control-plane verification steps passed.');
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
