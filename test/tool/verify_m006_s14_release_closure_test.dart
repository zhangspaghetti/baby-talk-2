import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m006_s14_release_closure.dart' as s14;

void main() {
  group('M006 S14 executable fail-closed contract', () {
    test(
      'no arguments reject immediately without launching legacy children',
      () async {
        final fixture = await _legacyLaunchTrapFixture();
        addTearDown(() => fixture.delete(recursive: true));

        final result = await _runReleaseClosureCli(
          const [],
          workingDirectory: fixture.path,
        );
        final output = '${result.stdout}\n${result.stderr}';

        expect(result.exitCode, isNonZero);
        expect(
          output,
          contains('Current repository CI gates: .github/workflows/ci.yml'),
        );
        expect(
          output,
          contains('Helm/release smoke front door only: bash ci/k8s-smoke.sh'),
        );
        expect(output, contains('not complete repository CI'));
        expect(output, isNot(contains('child_gate=')));
        expect(output, isNot(contains('==> Release closure | S07')));
        expect(
          output,
          isNot(
            contains(
              r'$ dart run tool/verify_m006_s07_mentor_distribution.dart',
            ),
          ),
        );
        expect(output, isNot(contains('drill_down_verifier=')));
        expect(output, isNot(contains('LEGACY_CHILD_EXECUTED')));
        expect(
          File(
            '${fixture.path}${Platform.pathSeparator}legacy-child-launched',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test('--help and -h print usage and exit zero', () async {
      final fixture = await Directory.systemTemp.createTemp('m006_s14_help_');
      addTearDown(() => fixture.delete(recursive: true));

      for (final args in const <List<String>>[
        ['--help'],
        ['-h'],
      ]) {
        final result = await _runReleaseClosureCli(
          args,
          workingDirectory: fixture.path,
        );
        final output = '${result.stdout}\n${result.stderr}';

        expect(result.exitCode, 0, reason: 'args=$args\n$output');
        expect(output, contains('Usage: dart run'));
        expect(output, isNot(contains('child_gate=')));
      }
    });

    test('unknown arguments remain non-zero', () async {
      final fixture = await Directory.systemTemp.createTemp(
        'm006_s14_unknown_',
      );
      addTearDown(() => fixture.delete(recursive: true));

      final result = await _runReleaseClosureCli(const [
        '--bogus',
      ], workingDirectory: fixture.path);
      final output = '${result.stdout}\n${result.stderr}';

      expect(result.exitCode, isNonZero);
      expect(output, contains('Unknown arguments: --bogus'));
      expect(output, isNot(contains('child_gate=')));
    });
  });

  group('M006 S14 release closure contract', () {
    test('keeps historical child metadata and artifact hints', () {
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
        'docs/archived/runbooks/m006-s07-mentor-distribution-closure.md',
        'docs/runbooks/k8s-deploy.md',
        'docs/archived/runbooks/m006-s12-control-plane-freshness.md',
        'docs/archived/runbooks/m006-s13-demo-path.md',
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
      expect(gates.map((gate) => gate.stepCommandLine).toList(), <String>[
        r'$ dart run tool/verify_m006_s07_mentor_distribution.dart',
        r'$ dart run tool/verify_m006_s08_release.dart --helm',
        r'$ dart run tool/verify_m006_s12_control_plane_freshness.dart',
        r'$ dart run tool/verify_m006_s13_demo_path.dart',
      ]);
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

    test('historical child metadata resolves to tracked reference files', () {
      for (final gate in s14.releaseClosureChildGates) {
        expect(
          s14.validateChildGateContract(gate, pathExists: _rootRelativeExists),
          isNull,
          reason:
              'Expected ${gate.gateId} historical metadata to resolve from repo root.',
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

    test(
      'help text rejects legacy execution and names current CI front door',
      () {
        expect(
          s14.releaseClosureUsage.trim(),
          startsWith(
            'Usage: dart run tool/verify_m006_s14_release_closure.dart [--help]',
          ),
        );
        expect(
          s14.releaseClosureUsage,
          contains('Legacy M006 S14 child chain is not runnable.'),
        );
        expect(
          s14.releaseClosureUsage,
          contains('Current executable CI front door: bash ci/k8s-smoke.sh'),
        );
        expect(
          s14.releaseClosureUsage,
          isNot(contains('Runs the final M006 release-closure chain')),
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
        expect(
          s14.releaseClosureUsage,
          contains('4. S13 repo front-door truth'),
        );
        expect(
          s14.releaseClosureUsage,
          isNot(contains('drill_down_verifier=')),
        );
        expect(s14.releaseClosureUsage, isNot(contains('child_gate=')));
        expect(
          s14.releaseClosureUsage,
          isNot(contains(s14.releaseClosureSuccessMarker)),
        );
      },
    );
  });

  group('M006 S14 repo-root handoff surfaces', () {
    test(
      'workflow scopes relay to backend tests, installs Helm smoke, and preserves artifacts',
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
            'continue-on-error: true\n        timeout-minutes: 45\n        env:\n          DOCKER_HOST: tcp://localhost:2375\n        run: bash ci/backend-test.sh',
          ),
        );
        expect(
          workflow,
          contains("BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT: '1'"),
        );
        expect(
          workflow,
          contains('- name: Install Helm\n        uses: azure/setup-helm@v4'),
        );
        expect(
          workflow,
          contains(
            'continue-on-error: true\n        timeout-minutes: 20\n        run: bash ci/k8s-smoke.sh',
          ),
        );
        expect(workflow, isNot(contains('verify_m006_s14_release_closure')));
        expect(
          workflow,
          contains(r'''- name: Upload playwright-report artifact
        if: ${{ always() }}'''),
        );
        expect(
          workflow,
          contains(
            'path: |\n            admin-web/playwright-report\n            admin-web/test-results',
          ),
        );

        final backendIndex = workflow.indexOf('Run backend tests');
        final stopRelayIndex = workflow.indexOf('Stop Docker relay');
        final checkstyleIndex = workflow.indexOf('Run checkstyle');
        final helmIndex = workflow.indexOf(
          'Run Helm dual-chart smoke (babytalk-infra + babytalk-app)',
        );
        final uploadIndex = workflow.indexOf(
          'Upload playwright-report artifact',
        );
        final failIndex = workflow.indexOf(
          'Fail when backend tests, checkstyle, or Helm smoke fail',
        );

        expect(backendIndex, greaterThanOrEqualTo(0));
        expect(checkstyleIndex, greaterThan(backendIndex));
        expect(stopRelayIndex, greaterThan(backendIndex));
        expect(helmIndex, greaterThan(stopRelayIndex));
        expect(uploadIndex, greaterThan(helmIndex));
        expect(failIndex, greaterThan(uploadIndex));
      },
    );

    test('repo-root docs keep current CI gate and non-runnable M006 history', () {
      const ciEquivalentCommand = 'bash ci/k8s-smoke.sh';
      const legacyM006Verifier = 'tool/verify_m006_s14_release_closure.dart';

      final readme = _readRootText('README.md');
      expect(readme, contains('## Final release closure (CI smoke gate)'));
      expect(
        readme,
        contains(
          '[Kubernetes split-stack deploy runbook](docs/runbooks/k8s-deploy.md)',
        ),
      );
      expect(readme, contains('internal-only'));

      final contributing = _readRootText('CONTRIBUTING.md');
      expect(
        contributing,
        contains('想跑 CI-equivalent gate：`bash ci/k8s-smoke.sh`'),
      );
      expect(
        contributing,
        contains(
          '除 `bash ci/k8s-smoke.sh` 这条 CI-equivalent gate 之外，其余 repo-root verifier 都是 scoped drill-down；不要再拼 ad-hoc shell chain。',
        ),
      );
      expect(
        contributing,
        contains(
          '| `backend/admin-api` | admin auth + admin data contracts | repo-root gateway front door |',
        ),
      );

      final releaseRunbook = _readRootText(
        'docs/runbooks/m006-s14-release-closure.md',
      );
      expect(releaseRunbook, contains('## Current CI-equivalent command'));
      expect(releaseRunbook, contains(ciEquivalentCommand));
      expect(
        releaseRunbook,
        contains('这是 README、CONTRIBUTING 与 CI 共同声明的唯一可执行 CI 前门。'),
      );
      expect(
        releaseRunbook,
        contains('## Historical M006 reference (not runnable)'),
      );
      expect(releaseRunbook, contains(legacyM006Verifier));
      expect(
        releaseRunbook,
        contains(
          'M006 S14 verifier 与 child chain 仅保留为历史参考，不再是 CI 或仓库前门，当前不可运行。',
        ),
      );
      expect(
        releaseRunbook,
        contains(
          '不要运行该 verifier 或任一 legacy child chain；S13/S12 仍依赖已归档或移除的 active 路径，执行结果不能作为当前 release proof。',
        ),
      );
      expect(
        releaseRunbook,
        contains(
          '[S07 archived runbook](../archived/runbooks/m006-s07-mentor-distribution-closure.md)',
        ),
      );
      expect(
        releaseRunbook,
        contains('[Kubernetes split-stack deploy runbook](k8s-deploy.md)'),
      );
      expect(
        releaseRunbook,
        contains(
          '[S12 archived runbook](../archived/runbooks/m006-s12-control-plane-freshness.md)',
        ),
      );
      expect(
        releaseRunbook,
        contains(
          '[S13 archived runbook](../archived/runbooks/m006-s13-demo-path.md)',
        ),
      );
      expect(
        releaseRunbook,
        isNot(contains('dart run tool/verify_m006_s14_release_closure.dart')),
      );
      expect(releaseRunbook, isNot(contains('## Scoped M006 drill-down')));
      expect(releaseRunbook, isNot(contains('才运行')));

      final k8sRunbook = _readRootText('docs/runbooks/k8s-deploy.md');
      expect(k8sRunbook, contains('admin-api'));
      expect(k8sRunbook, contains('internal-only'));
    });

    test('documented historical reference files resolve from repo root', () {
      for (final relativePath in const <String>[
        'docs/runbooks/m006-s14-release-closure.md',
        'docs/runbooks/k8s-deploy.md',
        'docs/archived/runbooks/m006-s07-mentor-distribution-closure.md',
        'docs/archived/runbooks/m006-s12-control-plane-freshness.md',
        'docs/archived/runbooks/m006-s13-demo-path.md',
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
  return File(
    '$root${Platform.pathSeparator}$relativePath',
  ).readAsStringSync().replaceAll('\r\n', '\n');
}

Future<ProcessResult> _runReleaseClosureCli(
  List<String> args, {
  required String workingDirectory,
}) {
  final verifier = File(
    '${_repoRootDirectory().path}${Platform.pathSeparator}tool${Platform.pathSeparator}verify_m006_s14_release_closure.dart',
  );
  return Process.run(
    _dartExecutable(),
    ['run', verifier.path, ...args],
    workingDirectory: workingDirectory,
    runInShell: false,
  );
}

String _dartExecutable() {
  final resolvedExecutable = File(Platform.resolvedExecutable);
  if (resolvedExecutable.uri.pathSegments.last.startsWith('dart')) {
    return resolvedExecutable.path;
  }

  var ancestor = resolvedExecutable.parent;
  while (ancestor.parent.path != ancestor.path) {
    final candidate = File(
      '${ancestor.path}${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin${Platform.pathSeparator}dart${Platform.isWindows ? '.exe' : ''}',
    );
    if (candidate.existsSync()) {
      return candidate.path;
    }
    ancestor = ancestor.parent;
  }

  throw StateError(
    'Unable to resolve Dart executable from ${Platform.resolvedExecutable}',
  );
}

Future<Directory> _legacyLaunchTrapFixture() async {
  final fixture = await Directory.systemTemp.createTemp('m006_s14_no_args_');
  final verifier = File(
    '${fixture.path}${Platform.pathSeparator}tool${Platform.pathSeparator}verify_m006_s07_mentor_distribution.dart',
  );
  await verifier.parent.create(recursive: true);
  await verifier.writeAsString('''
import 'dart:io';

void main() {
  File('legacy-child-launched').writeAsStringSync('S07');
  print('LEGACY_CHILD_EXECUTED');
  print('All M006/S07 mentor + distribution verification steps passed.');
}
''');

  final runbook = File(
    '${fixture.path}${Platform.pathSeparator}docs${Platform.pathSeparator}archived${Platform.pathSeparator}runbooks${Platform.pathSeparator}m006-s07-mentor-distribution-closure.md',
  );
  await runbook.parent.create(recursive: true);
  await runbook.writeAsString('# legacy fixture\n');
  return fixture;
}
