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
