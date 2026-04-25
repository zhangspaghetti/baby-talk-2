import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m006_s14_release_closure.dart' as s14;

void main() {
  group('M006 S14 release closure contract', () {
    test('keeps child order, labels, runbooks, and scoped artifact hints', () {
      final gates = s14.releaseClosureChildGates;

      expect(gates.map((gate) => gate.gateId).toList(), <String>[
        'S07',
        'S08',
        'S12',
        'S13',
      ]);
      expect(gates.map((gate) => gate.stepLabel).toList(), <String>[
        'Release closure | S07 mentor + distribution gate',
        'Release closure | S08 Helm release gate',
        'Release closure | S12 control-plane freshness gate',
        'Release closure | S13 repo front-door gate',
      ]);
      expect(gates.map((gate) => gate.verifierPath).toList(), <String>[
        'tool/verify_m006_s07_mentor_distribution.dart',
        'tool/verify_m006_s08_release.dart',
        'tool/verify_m006_s12_control_plane_freshness.dart',
        'tool/verify_m006_s13_demo_path.dart',
      ]);
      expect(gates.map((gate) => gate.runbookPath).toList(), <String>[
        'docs/runbooks/m006-s07-mentor-distribution-closure.md',
        'docs/runbooks/k8s-deploy.md',
        'docs/runbooks/m006-s12-control-plane-freshness.md',
        'docs/runbooks/m006-s13-demo-path.md',
      ]);
      expect(gates.map((gate) => gate.successMarker).toList(), <String>[
        'All M006/S07 mentor + distribution verification steps passed.',
        'All M006/S08 release verification steps passed.',
        'All M006/S12 overview control-plane verification steps passed.',
        'All M006/S13 demo-path verification steps passed.',
      ]);
      expect(gates[1].verifierArgs, <String>['--helm']);
      expect(
        gates[1].rerunCommand,
        'dart run tool/verify_m006_s08_release.dart --helm',
      );
      expect(
        gates.map((gate) => gate.stepCommandLine).toList(),
        <String>[
          r'$ dart run tool/verify_m006_s07_mentor_distribution.dart',
          r'$ dart run tool/verify_m006_s08_release.dart --helm',
          r'$ dart run tool/verify_m006_s12_control_plane_freshness.dart',
          r'$ dart run tool/verify_m006_s13_demo_path.dart',
        ],
      );
      expect(
        gates
            .where((gate) => gate.artifactHint != null)
            .map((gate) => gate.gateId)
            .toList(),
        <String>['S07', 'S12'],
      );
      expect(gates[0].artifactHint, 'admin-web/playwright-report/index.html');
      expect(gates[1].artifactHint, isNull);
      expect(gates[2].artifactHint, 'admin-web/playwright-report/index.html');
      expect(gates[3].artifactHint, isNull);
    });

    test('current child gates resolve to tracked verifier and runbook files', () {
      for (final gate in s14.releaseClosureChildGates) {
        expect(
          s14.validateChildGateContract(gate, pathExists: _rootRelativeExists),
          isNull,
          reason:
              'Expected ${gate.gateId} contract to stay resolvable from repo root.',
        );
      }
    });

    test('cli parser keeps help explicit and rejects unknown flags', () {
      final defaultOptions = s14.ReleaseClosureCliOptions.parse(const []);
      expect(defaultOptions.showHelp, isFalse);
      expect(defaultOptions.usageError, isNull);

      final helpOptions = s14.ReleaseClosureCliOptions.parse(const ['--help']);
      expect(helpOptions.showHelp, isTrue);
      expect(helpOptions.usageError, isNull);

      final shortHelpOptions = s14.ReleaseClosureCliOptions.parse(const ['-h']);
      expect(shortHelpOptions.showHelp, isTrue);
      expect(shortHelpOptions.usageError, isNull);

      final invalidOptions = s14.ReleaseClosureCliOptions.parse(const [
        '--bogus',
      ]);
      expect(invalidOptions.showHelp, isFalse);
      expect(invalidOptions.usageError, 'Unknown arguments: --bogus');

      final mixedOptions = s14.ReleaseClosureCliOptions.parse(const [
        '--help',
        '--bogus',
      ]);
      expect(mixedOptions.showHelp, isFalse);
      expect(mixedOptions.usageError, 'Unknown arguments: --bogus');
    });

    test('help text stays usage-only contract', () {
      expect(
        s14.releaseClosureUsage.trim(),
        startsWith(
          'Usage: dart run tool/verify_m006_s14_release_closure.dart [--help]',
        ),
      );
      expect(
        s14.releaseClosureUsage,
        contains('1. S07 mentor + distribution closure'),
      );
      expect(s14.releaseClosureUsage, contains('2. S08 Helm release truth'));
      expect(
        s14.releaseClosureUsage,
        contains('3. S12 control-plane freshness'),
      );
      expect(s14.releaseClosureUsage, contains('4. S13 repo front-door truth'));
      expect(s14.releaseClosureUsage, isNot(contains('drill_down_verifier=')));
      expect(s14.releaseClosureUsage, isNot(contains('child_gate=')));
      expect(
        s14.releaseClosureUsage,
        isNot(contains(s14.releaseClosureSuccessMarker)),
      );
    });
  });

  group('M006 S14 repo-root handoff surfaces', () {
    test(
      'workflow keeps relay, canonical gate, and artifact-preserving fail path',
      () {
        final workflow = _readRootText('.github/workflows/ci.yml');

        expect(
          workflow,
          contains(
            '- name: Start localhost:2375 Docker relay for Testcontainers',
          ),
        );
        expect(
          workflow,
          contains(
            'if docker --host tcp://localhost:2375 info >/dev/null 2>&1; then',
          ),
        );
        expect(
          workflow,
          contains(
            'continue-on-error: true\n        timeout-minutes: 45\n        env:\n          DOCKER_HOST: tcp://localhost:2375\n        run: dart run tool/verify_m006_s14_release_closure.dart',
          ),
        );
        expect(
          workflow,
          contains(
            '- name: Upload playwright-report artifact\n        if: \${{ always() }}',
          ),
        );
        expect(
          workflow,
          contains(
            'path: |\n            admin-web/playwright-report\n            admin-web/test-results',
          ),
        );

        final verifierIndex = workflow.indexOf(
          'Run M006 S14 release-closure verifier',
        );
        final uploadIndex = workflow.indexOf(
          'Upload playwright-report artifact',
        );
        final failIndex = workflow.indexOf(
          'Fail when release-closure verifier fails',
        );

        expect(verifierIndex, greaterThanOrEqualTo(0));
        expect(uploadIndex, greaterThan(verifierIndex));
        expect(failIndex, greaterThan(uploadIndex));
      },
    );

    test('repo-root docs keep canonical command and drill-down references', () {
      const canonicalCommand =
          'dart run tool/verify_m006_s14_release_closure.dart';

      final readme = _readRootText('README.md');
      expect(readme, contains('## Final release closure（CI 同款）'));
      expect(readme, contains(canonicalCommand));
      expect(readme, contains('仓库根唯一 final release command 仍是这条'));
      expect(
        readme,
        contains(
          '[M006 / S14 release-closure runbook](docs/runbooks/m006-s14-release-closure.md)',
        ),
      );
      expect(
        readme,
        contains(
          '[Kubernetes split-stack deploy runbook](docs/runbooks/k8s-deploy.md)',
        ),
      );
      expect(readme, contains('internal-only'));
      expect(readme, contains('不要在 repo root 重新发明第二条 release command chain'));

      final contributing = _readRootText('CONTRIBUTING.md');
      expect(
        contributing,
        contains(
          '想跑最终 release closure（CI 同款，唯一 final release command）：`dart run tool/verify_m006_s14_release_closure.dart`',
        ),
      );
      expect(
        contributing,
        contains(
          '除这条 S14 release closure 之外，其余 repo-root verifier 都只用于 scoped drill-down；不要再拼 ad-hoc shell chain。',
        ),
      );
      expect(
        contributing,
        contains(
          '| `backend/admin-api` | admin auth + admin data contracts | public ingress / repo-root front door |',
        ),
      );

      final releaseRunbook = _readRootText(
        'docs/runbooks/m006-s14-release-closure.md',
      );
      expect(releaseRunbook, contains('## Canonical command'));
      expect(releaseRunbook, contains(canonicalCommand));
      expect(
        releaseRunbook,
        contains('仓库根唯一 final release command 始终是这条 S14 gate。'),
      );
      expect(
        releaseRunbook,
        contains('[S07 runbook](m006-s07-mentor-distribution-closure.md)'),
      );
      expect(
        releaseRunbook,
        contains('[Kubernetes split-stack deploy runbook](k8s-deploy.md)'),
      );

      final k8sRunbook = _readRootText('docs/runbooks/k8s-deploy.md');
      expect(k8sRunbook, contains(canonicalCommand));
      expect(
        k8sRunbook,
        contains(
          '仓库根唯一 final release command 仍是这条 S14 gate；S08 `--helm` 只是其中的 deploy-truth child。',
        ),
      );
      expect(
        k8sRunbook,
        contains(
          '`admin-api` 只有 ClusterIP Service，没有 Ingress；它是 **internal-only**。',
        ),
      );
      expect(
        k8sRunbook,
        contains(
          'S08 仍然是 Helm deploy truth 的 authoritative child；S14 只负责 composition。',
        ),
      );
    });

    test('documented drill-down files still resolve from repo root', () {
      for (final relativePath in const <String>[
        'docs/runbooks/m006-s14-release-closure.md',
        'docs/runbooks/k8s-deploy.md',
        'docs/runbooks/m006-s07-mentor-distribution-closure.md',
        'docs/runbooks/m006-s12-control-plane-freshness.md',
        'docs/runbooks/m006-s13-demo-path.md',
      ]) {
        expect(
          _rootRelativeExists(relativePath),
          isTrue,
          reason: 'Expected documented drill-down file to exist: $relativePath',
        );
      }
    });
  });

  group('M006 S14 fail-closed contract helpers', () {
    test(
      'missing verifier, runbook, marker, and artifact hint fail closed',
      () {
        expect(
          s14.validateChildGateContract(
            _fakeGate(verifierPath: ''),
            pathExists: (_) => true,
          ),
          isA<s14.StepFailure>().having(
            (error) => error.message,
            'message',
            contains('does not declare a verifier path'),
          ),
        );
        expect(
          s14.validateChildGateContract(
            _fakeGate(runbookPath: ''),
            pathExists: (_) => true,
          ),
          isA<s14.StepFailure>().having(
            (error) => error.message,
            'message',
            contains('does not declare a drill-down runbook path'),
          ),
        );
        expect(
          s14.validateChildGateContract(
            _fakeGate(successMarker: '   '),
            pathExists: (_) => true,
          ),
          isA<s14.StepFailure>().having(
            (error) => error.message,
            'message',
            contains('empty success marker'),
          ),
        );
        expect(
          s14.validateChildGateContract(
            _fakeGate(artifactHint: '  '),
            pathExists: (_) => true,
          ),
          isA<s14.StepFailure>().having(
            (error) => error.message,
            'message',
            contains('blank artifact hint'),
          ),
        );
        expect(
          s14.validateChildGateContract(
            _fakeGate(),
            pathExists: (path) => path != 'tool/missing_child.dart',
          ),
          isA<s14.StepFailure>().having(
            (error) => error.message,
            'message',
            contains('missing at `tool/missing_child.dart`'),
          ),
        );
        expect(
          s14.validateChildGateContract(
            _fakeGate(
              verifierPath: 'tool/present.dart',
              runbookPath: 'docs/runbooks/missing.md',
            ),
            pathExists: (path) => path != 'docs/runbooks/missing.md',
          ),
          isA<s14.StepFailure>().having(
            (error) => error.message,
            'message',
            contains('missing at `docs/runbooks/missing.md`'),
          ),
        );
      },
    );

    test('child exit handling stays fail-fast and marker-based', () {
      final gate = _fakeGate(
        verifierPath: 'tool/verify_m006_s08_release.dart',
        verifierArgs: const ['--helm'],
        successMarker: 'All M006/S08 release verification steps passed.',
        runbookPath: 'docs/runbooks/k8s-deploy.md',
      );

      expect(
        s14.validateChildGateResult(
          gate,
          const s14.ProcessResultSnapshot(
            exitCode: 0,
            stdout: 'All M006/S08 release verification steps passed.',
            stderr: '',
          ),
        ),
        isNull,
      );

      expect(
        s14.validateChildGateResult(
          gate,
          const s14.ProcessResultSnapshot(
            exitCode: 124,
            stdout: '',
            stderr: '',
          ),
        ),
        isA<s14.StepFailure>()
            .having((error) => error.exitCode, 'exitCode', 124)
            .having(
              (error) => error.message,
              'message',
              contains('Timed out after'),
            ),
      );
      expect(
        s14.validateChildGateResult(
          gate,
          const s14.ProcessResultSnapshot(
            exitCode: 7,
            stdout: '',
            stderr: 'boom',
          ),
        ),
        isA<s14.StepFailure>()
            .having((error) => error.exitCode, 'exitCode', 7)
            .having(
              (error) => error.message,
              'message',
              contains('exited with code 7'),
            ),
      );
      expect(
        s14.validateChildGateResult(
          gate,
          const s14.ProcessResultSnapshot(
            exitCode: 0,
            stdout: 'no marker here',
            stderr: '',
          ),
        ),
        isA<s14.StepFailure>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('did not emit the expected success marker'),
            contains('All M006/S08 release verification steps passed.'),
          ),
        ),
      );
    });
  });
}

s14.ChildGate _fakeGate({
  String gateId = 'S99',
  String stepLabel = 'Release closure | Fake child gate',
  String verifierPath = 'tool/missing_child.dart',
  List<String> verifierArgs = const [],
  String successMarker = 'fake success marker',
  Duration timeout = const Duration(minutes: 1),
  String runbookPath = 'docs/runbooks/fake.md',
  String? artifactHint,
}) {
  return s14.ChildGate(
    gateId: gateId,
    stepLabel: stepLabel,
    verifierPath: verifierPath,
    verifierArgs: verifierArgs,
    successMarker: successMarker,
    timeout: timeout,
    runbookPath: runbookPath,
    artifactHint: artifactHint,
  );
}

Directory _repoRootDirectory() {
  final current = Directory.current;
  final rootCandidate = File(
    '${current.path}${Platform.pathSeparator}tool${Platform.pathSeparator}verify_m006_s14_release_closure.dart',
  );
  if (rootCandidate.existsSync()) {
    return current;
  }

  final parent = current.parent;
  final parentCandidate = File(
    '${parent.path}${Platform.pathSeparator}tool${Platform.pathSeparator}verify_m006_s14_release_closure.dart',
  );
  if (parentCandidate.existsSync()) {
    return parent;
  }

  throw StateError(
    'Unable to resolve repo root for verify_m006_s14_release_closure.dart',
  );
}

bool _rootRelativeExists(String relativePath) {
  final root = _repoRootDirectory().path;
  return File('$root${Platform.pathSeparator}$relativePath').existsSync();
}

String _readRootText(String relativePath) {
  final root = _repoRootDirectory().path;
  return File('$root${Platform.pathSeparator}$relativePath').readAsStringSync();
}
