import 'dart:io';

Future<void> main(List<String> args) async {
  final mobileDirectory = Directory('mobile');
  if (!mobileDirectory.existsSync()) {
    stderr.writeln('未找到 mobile/ 子工程，无法代理 inspect_interaction_events.dart。');
    exit(64);
  }

  final result = await Process.run(
    Platform.resolvedExecutable,
    ['run', 'tool/inspect_interaction_events.dart', ...args],
    workingDirectory: mobileDirectory.path,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode is int ? result.exitCode as int : 1);
}
