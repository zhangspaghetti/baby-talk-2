import 'dart:io';

Future<void> main(List<String> args) async {
  final mobileDirectory = Directory('mobile');
  if (!mobileDirectory.existsSync()) {
    stderr.writeln('未找到 mobile/ 子工程，无法代理 inspect_mentor_facts.dart。');
    exit(64);
  }

  final delegatedScript = File(
    '${mobileDirectory.path}${Platform.pathSeparator}tool${Platform.pathSeparator}inspect_mentor_facts.dart',
  );
  if (!delegatedScript.existsSync()) {
    stderr.writeln('未找到 mobile/tool/inspect_mentor_facts.dart，无法继续代理。');
    exit(64);
  }

  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    'tool/inspect_mentor_facts.dart',
    ...args,
  ], workingDirectory: mobileDirectory.path);

  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}
