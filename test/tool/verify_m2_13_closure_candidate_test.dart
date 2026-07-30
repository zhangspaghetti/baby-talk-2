import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m2_13_closure_candidate.dart' as verifier;

void main() {
  test('complete PASS manifest freezes every required closure gate', () {
    final report = verifier.scanM213ClosureCandidate(
      manifestPath: _fixturePath(),
    );

    expect(
      report.passes,
      isTrue,
      reason: verifier.renderM213ClosureCandidateReport(report),
    );
    expect(report.manifest!.gateIds, unorderedEquals(verifier.closureGateIds));
  });

  for (final status in ['FAIL', 'BLOCKED', 'NOT RUN']) {
    test('$status cannot be reinterpreted as PASS', () async {
      final path = await _mutatedFixture((manifest) {
        manifest['closure_matrix'][0]['status'] = status;
      });
      addTearDown(() => path.parent.delete(recursive: true));

      final report = verifier.scanM213ClosureCandidate(manifestPath: path.path);

      expect(report.passes, isFalse);
      expect(
        verifier.renderM213ClosureCandidateReport(report),
        contains('non_passing_gate'),
      );
    });
  }

  test('manifest rejects tuple or final-UAT input mutation', () async {
    final path = await _mutatedFixture((manifest) {
      manifest['candidate']['environment_identity'] = 'prod-secrets-here';
      manifest['final_uat_input']['only_allowed_input'] = false;
    });
    addTearDown(() => path.parent.delete(recursive: true));

    final report = verifier.scanM213ClosureCandidate(manifestPath: path.path);

    expect(report.passes, isFalse);
    final output = verifier.renderM213ClosureCandidateReport(report);
    expect(output, contains('environment_identity must be sanitized'));
    expect(
      output,
      contains('final UAT accepts only this candidate manifest schema'),
    );
  });

  test('entrypoint gate matrix invokes every fixed upstream gate', () async {
    final invoked = <String>[];
    final result = await verifier.runM213ClosureGates(
      projectRoot: _repoRootPath(),
      commandExecutor: (gate, command, root) async {
        invoked.add(gate.id);
        return const verifier.ClosureCommandResult(0, '', '');
      },
    );

    expect(result.passes, isTrue);
    expect(invoked.toSet(), unorderedEquals(verifier.closureGateIds));
  });

  test('failed command reports stable output fingerprints without raw output',
      () async {
    final invoked = <String>[];
    final result = await verifier.runM213ClosureGates(
      projectRoot: _repoRootPath(),
      commandExecutor: (gate, command, root) async {
        invoked.add(gate.id);
        if (gate.id == 'complete_bundle') {
          return const verifier.ClosureCommandResult(
            23,
            'closure-stdout-fixture',
            'closure-stderr-fixture',
          );
        }
        return const verifier.ClosureCommandResult(0, '', '');
      },
    );

    expect(result.passes, isFalse);
    expect(result.failedGate, 'complete_bundle');
    expect(
      result.detail,
      'command_identity=complete_bundle:1 '
      'exit_code=23 '
      'stdout_bytes=22 '
      'stdout_sha256=3c33ab1258b6a844e6c3a113fb8e25245c39a19ca8005cb44bf0823e84ded227 '
      'stderr_bytes=22 '
      'stderr_sha256=0532325e737bfa8e9d3b20cb0292de36439de5ba672623f4b2cfb7fd13b38aa6',
    );
    expect(result.detail, isNot(contains('closure-stdout-fixture')));
    expect(result.detail, isNot(contains('closure-stderr-fixture')));
    expect(invoked, ['clean_worktree', 'complete_bundle']);
  });

  test('dirty clean-worktree command cannot pass', () async {
    final invoked = <String>[];
    final result = await verifier.runM213ClosureGates(
      projectRoot: _repoRootPath(),
      commandExecutor: (gate, command, root) async {
        invoked.add(gate.id);
        if (gate.id == 'clean_worktree') {
          return const verifier.ClosureCommandResult(0, ' M changed.dart', '');
        }
        return const verifier.ClosureCommandResult(0, '', '');
      },
    );

    expect(result.passes, isFalse);
    expect(result.failedGate, 'clean_worktree');
    expect(invoked, ['clean_worktree']);
  });

  test('Windows bash gates use the repository wrapper', () async {
    final root = await Directory.systemTemp.createTemp(
      'm2_13_closure_windows_wrapper_',
    );
    addTearDown(() => root.delete(recursive: true));
    final wrapper = File('${root.path}${Platform.pathSeparator}bash.cmd');
    await wrapper.writeAsString('@echo off\r\n');
    const command = verifier.ClosureCommand('bash', [
      'mvnw',
      'test',
    ], 'backend');

    final execution = verifier.resolveM213ClosureCommandExecution(
      command: command,
      projectRoot: root.path,
      isWindows: true,
    );

    expect(execution.executable, wrapper.path);
    expect(execution.runInShell, isTrue);
    expect(command.arguments, ['mvnw', 'test']);
    expect(command.workingDirectory, 'backend');
  });

  test('bash gates retain bare executable without a Windows wrapper', () async {
    final root = await Directory.systemTemp.createTemp(
      'm2_13_closure_bash_fallback_',
    );
    addTearDown(() => root.delete(recursive: true));
    const command = verifier.ClosureCommand('bash', ['ci/full-ci.sh'], '.');
    const nonBashCommand = verifier.ClosureCommand(
      'git',
      ['status', '--porcelain'],
      '.',
    );

    final missingWrapper = verifier.resolveM213ClosureCommandExecution(
      command: command,
      projectRoot: root.path,
      isWindows: true,
    );
    await File(
      '${root.path}${Platform.pathSeparator}bash.cmd',
    ).writeAsString('@echo off\r\n');
    final nonWindows = verifier.resolveM213ClosureCommandExecution(
      command: command,
      projectRoot: root.path,
      isWindows: false,
    );
    final nonBash = verifier.resolveM213ClosureCommandExecution(
      command: nonBashCommand,
      projectRoot: root.path,
      isWindows: true,
    );

    expect(missingWrapper.executable, 'bash');
    expect(missingWrapper.runInShell, isFalse);
    expect(nonWindows.executable, 'bash');
    expect(nonWindows.runInShell, isFalse);
    expect(nonBash.executable, 'git');
    expect(nonBash.runInShell, isFalse);
  });
}

String _fixturePath() =>
    '${_repoRootPath()}${Platform.pathSeparator}test${Platform.pathSeparator}tool${Platform.pathSeparator}fixtures${Platform.pathSeparator}m2_13_closure_candidate${Platform.pathSeparator}complete_pass.json';

Future<File> _mutatedFixture(void Function(Map<String, dynamic>) mutate) async {
  final root = await Directory.systemTemp.createTemp(
    'm2_13_closure_candidate_',
  );
  final manifest =
      jsonDecode(await File(_fixturePath()).readAsString())
          as Map<String, dynamic>;
  mutate(manifest);
  final file = File('${root.path}${Platform.pathSeparator}manifest.json');
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
  return file;
}

String _repoRootPath() {
  final current = Directory.current;
  if (Directory(
    '${current.path}${Platform.pathSeparator}mobile${Platform.pathSeparator}lib',
  ).existsSync()) {
    return current.path;
  }
  return current.parent.path;
}
