import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m2_12_release_matrix.dart' as verifier;

void main() {
  group('M2-12 parsed Android UAT closure evidence', () {
    test('schema and template publish the current custom-scene contract', () {
      final schema =
          jsonDecode(
                File(
                  '${_repoRootPath()}${Platform.pathSeparator}docs${Platform.pathSeparator}uat${Platform.pathSeparator}m2${Platform.pathSeparator}m2-uat-record.schema.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final template =
          jsonDecode(
                File(
                  '${_repoRootPath()}${Platform.pathSeparator}docs${Platform.pathSeparator}uat${Platform.pathSeparator}m2${Platform.pathSeparator}m2-uat-record.template.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final recordProperties =
          (schema[r'$defs'] as Map<String, dynamic>)['record']
              as Map<String, dynamic>;
      final properties = recordProperties['properties'] as Map<String, dynamic>;
      final inputMode = properties['input_mode'] as Map<String, dynamic>;
      final scenarioLabel =
          properties['scenario_label'] as Map<String, dynamic>;

      const expected = <String>[
        'shoes',
        'bath',
        'water',
        'teeth',
        'tidying',
        'sleep',
      ];
      expect((properties['schema_version'] as Map<String, dynamic>)['enum'], [
        'm2_android_uat_v1',
        'm2_android_uat_v2',
      ]);
      final versionRules = recordProperties['allOf'] as List<dynamic>;
      final v2Rule = versionRules.last as Map<String, dynamic>;
      final v2Then = v2Rule['then'] as Map<String, dynamic>;
      expect(v2Then['required'], ['input_mode', 'scenario_label']);
      expect((v2Then['not'] as Map<String, dynamic>)['required'], [
        'canonical_scene',
      ]);
      expect(inputMode['const'], 'custom_scene');
      expect(scenarioLabel['enum'], expected);
      expect(template['approved_scenario_labels'], expected);
      final templateRecord =
          template['record_template'] as Map<String, dynamic>;
      final prerequisites = templateRecord['prerequisites'] as List<dynamic>;
      expect(
        prerequisites.any(
          (value) =>
              value is Map<String, dynamic> &&
              value['id'] == 'approved_custom_scene_scenario' &&
              value['status'] == 'NOT_RUN',
        ),
        isTrue,
      );
      expect(
        (templateRecord['steps'] as List<dynamic>).first['action'],
        'submit_custom_scene',
      );
      expect(expected, isNot(contains('unknown')));
    });

    test('manifest-bound custom-scene sleep record is closure-ready', () {
      final report = verifier.scanM212ReleaseMatrix(
        projectRoot: _repoRootPath(),
        uatRecordsPath: File(_fixturePath()).parent.path,
        candidateManifestPath: _manifestFixturePath(),
      );

      expect(
        report.passes,
        isTrue,
        reason: verifier.renderM212ReleaseMatrixReport(report),
      );
    });

    test(
      'legacy canonical-scene-only records cannot satisfy closure',
      () async {
        final recordsPath = await _mutatedFixture(_downgradeRecordsToV1);
        addTearDown(() => recordsPath.parent.delete(recursive: true));

        final report = verifier.scanM212ReleaseMatrix(
          projectRoot: _repoRootPath(),
          uatRecordsPath: recordsPath.parent.path,
          candidateManifestPath: _manifestFixturePath(),
        );

        expect(report.passes, isFalse);
        expect(
          verifier.renderM212ReleaseMatrixReport(report),
          contains('current closure requires m2_android_uat_v2'),
        );
      },
    );

    for (final fixture in <_FixtureCase>[
      _FixtureCase('missing_input_mode', 'missing required field: input_mode', (
        records,
      ) {
        records.first.remove('input_mode');
      }),
      _FixtureCase('wrong_input_mode', 'input_mode must be custom_scene', (
        records,
      ) {
        records.first['input_mode'] = 'canonical_scene';
      }),
      _FixtureCase(
        'unknown_scenario_label',
        'scenario must be an approved controlled label',
        (records) {
          records.first['scenario_label'] = 'unknown';
        },
      ),
    ]) {
      test('${fixture.name} fixture fails closed', () async {
        final recordsPath = await _mutatedFixture(fixture.mutate);
        addTearDown(() => recordsPath.parent.delete(recursive: true));
        final report = verifier.scanM212ReleaseMatrix(
          projectRoot: _repoRootPath(),
          uatRecordsPath: recordsPath.parent.path,
          candidateManifestPath: _manifestFixturePath(),
        );

        expect(report.passes, isFalse);
        expect(
          verifier.renderM212ReleaseMatrixReport(report),
          contains(fixture.expectedDiagnostic),
        );
      });
    }

    for (final fixture in <_FixtureCase>[
      _FixtureCase('missing_field', 'missing required field', (records) {
        records.first.remove('executor');
      }),
      _FixtureCase(
        'missing_manifest_reference',
        'missing required field: candidate_manifest',
        (records) {
          records.first.remove('candidate_manifest');
        },
      ),
      _FixtureCase('identity_mismatch', 'candidate identity mismatch', (
        records,
      ) {
        records[1]['candidate']['mobile_source_sha'] =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      }),
      _FixtureCase('non_final_status', 'record status must be FINAL', (
        records,
      ) {
        records.first['status'] = 'IN_PROGRESS';
      }),
      _FixtureCase('not_run', 'record verdict must be PASS', (records) {
        records.first['verdict'] = 'NOT_RUN';
      }),
      _FixtureCase('fail', 'record verdict must be PASS', (records) {
        records.first['verdict'] = 'FAIL';
      }),
      _FixtureCase('blocked', 'record verdict must be PASS', (records) {
        records.first['verdict'] = 'BLOCKED';
      }),
      _FixtureCase('privacy_violation', 'privacy declaration is not safe', (
        records,
      ) {
        records.first['privacy']['raw_content_stored'] = true;
      }),
      _FixtureCase('duplicate_case', 'duplicate required UAT case', (records) {
        records.add(Map<String, dynamic>.from(records.first));
      }),
      _FixtureCase('incomplete_cases', 'missing required UAT case', (records) {
        records.removeLast();
      }),
      _FixtureCase('open_defect', 'open defect', (records) {
        records.first['defects'] = <Object?>[
          <String, Object?>{
            'id': 'DEF-42',
            'status': 'OPEN',
            'retest_outcome': 'NOT_RUN',
          },
        ];
        records.first['retest_outcome'] = 'NOT_RUN';
      }),
      _FixtureCase('inferred_talkback', 'human TalkBack evidence is required', (
        records,
      ) {
        records.last['accessibility']['method'] = 'ADB_HIERARCHY';
      }),
    ]) {
      test('${fixture.name} fixture fails closed', () async {
        final recordsPath = await _mutatedFixture(fixture.mutate);
        addTearDown(() => recordsPath.parent.delete(recursive: true));
        final report = verifier.scanM212ReleaseMatrix(
          projectRoot: _repoRootPath(),
          uatRecordsPath: recordsPath.parent.path,
          candidateManifestPath: _manifestFixturePath(),
        );

        expect(report.passes, isFalse);
        expect(
          verifier.renderM212ReleaseMatrixReport(report),
          contains(fixture.expectedDiagnostic),
        );
      });
    }

    for (final prohibitedField in <String>[
      'raw_prompt',
      'provider_payload',
      'utterance_body',
      'credential',
      'token',
      'account_id',
      'device_id',
      'raw_error',
      'private_evidence',
    ]) {
      test('$prohibitedField cannot enter an UAT record', () async {
        final recordsPath = await _mutatedFixture((records) {
          records.first[prohibitedField] = 'prohibited_metadata';
        });
        addTearDown(() => recordsPath.parent.delete(recursive: true));

        final report = verifier.scanM212ReleaseMatrix(
          projectRoot: _repoRootPath(),
          uatRecordsPath: recordsPath.parent.path,
          candidateManifestPath: _manifestFixturePath(),
        );

        expect(report.passes, isFalse);
        expect(
          verifier.renderM212ReleaseMatrixReport(report),
          contains('unapproved record field is forbidden'),
        );
      });
    }

    test('release runner returns closure failure for BLOCKED UAT', () async {
      final recordsPath = await _mutatedFixture((records) {
        records.first['verdict'] = 'BLOCKED';
      });
      addTearDown(() => recordsPath.parent.delete(recursive: true));
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          '${_repoRootPath()}${Platform.pathSeparator}scripts${Platform.pathSeparator}verify-m2-12-release.ps1',
          '-UatOnly',
          '-UatRecordsPath',
          recordsPath.parent.path,
          '-CandidateManifestPath',
          _manifestFixturePath(),
        ],
        workingDirectory: _repoRootPath(),
        runInShell: false,
      );
      final output = '${result.stdout}\n${result.stderr}';

      expect(result.exitCode, isNonZero, reason: output);
      expect(output, contains('record verdict must be PASS'));
      expect(output, contains('M2-12 UAT closure matrix failed'));
    });

    test('self-consistent non-frozen candidate tuple fails closed', () async {
      final recordsPath = await _mutatedFixture((records) {
        for (final record in records) {
          record['candidate']['mobile_source_sha'] =
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        }
      });
      addTearDown(() => recordsPath.parent.delete(recursive: true));

      final report = verifier.scanM212ReleaseMatrix(
        projectRoot: _repoRootPath(),
        uatRecordsPath: recordsPath.parent.path,
        candidateManifestPath: _manifestFixturePath(),
      );

      expect(report.passes, isFalse);
      expect(
        verifier.renderM212ReleaseMatrixReport(report),
        contains('candidate does not match frozen manifest'),
      );
    });

    test('missing manifest fails closed', () {
      final report = verifier.scanM212ReleaseMatrix(
        projectRoot: _repoRootPath(),
        uatRecordsPath: File(_fixturePath()).parent.path,
        candidateManifestPath: '${_fixturePath()}.missing',
      );

      expect(report.passes, isFalse);
      expect(
        verifier.renderM212ReleaseMatrixReport(report),
        contains('frozen candidate manifest is missing'),
      );
    });

    test('wrong manifest reference fails closed', () async {
      final recordsPath = await _mutatedFixture((records) {
        for (final record in records) {
          record['candidate_manifest']['sha256'] =
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        }
      });
      addTearDown(() => recordsPath.parent.delete(recursive: true));

      final report = verifier.scanM212ReleaseMatrix(
        projectRoot: _repoRootPath(),
        uatRecordsPath: recordsPath.parent.path,
        candidateManifestPath: _manifestFixturePath(),
      );

      expect(report.passes, isFalse);
      expect(
        verifier.renderM212ReleaseMatrixReport(report),
        contains('record does not reference supplied manifest bytes'),
      );
    });

    test('tampered manifest fails closed', () async {
      final root = await Directory.systemTemp.createTemp(
        'm2_12_manifest_fixture_',
      );
      addTearDown(() => root.delete(recursive: true));
      final manifest =
          jsonDecode(await File(_manifestFixturePath()).readAsString())
              as Map<String, dynamic>;
      manifest['candidate']['backend_source_sha'] =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
      final tampered = File(
        '${root.path}${Platform.pathSeparator}candidate-manifest.json',
      );
      await tampered.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );

      final report = verifier.scanM212ReleaseMatrix(
        projectRoot: _repoRootPath(),
        uatRecordsPath: File(_fixturePath()).parent.path,
        candidateManifestPath: tampered.path,
      );

      expect(report.passes, isFalse);
      expect(
        verifier.renderM212ReleaseMatrixReport(report),
        contains('record does not reference supplied manifest bytes'),
      );
    });
  });
}

class _FixtureCase {
  const _FixtureCase(this.name, this.expectedDiagnostic, this.mutate);

  final String name;
  final String expectedDiagnostic;
  final void Function(List<dynamic> records) mutate;
}

String _fixturePath() =>
    '${_repoRootPath()}${Platform.pathSeparator}test${Platform.pathSeparator}fixtures${Platform.pathSeparator}m2_12_release_matrix${Platform.pathSeparator}complete_pass${Platform.pathSeparator}records.json';

String _manifestFixturePath() =>
    '${File(_fixturePath()).parent.parent.path}${Platform.pathSeparator}candidate-manifest.json';

Future<File> _mutatedFixture(
  void Function(List<dynamic> records) mutate,
) async {
  final root = await Directory.systemTemp.createTemp('m2_12_uat_fixture_');
  final records =
      jsonDecode(await File(_fixturePath()).readAsString()) as List<dynamic>;
  mutate(records);
  final file = File('${root.path}${Platform.pathSeparator}records.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(records));
  return file;
}

void _downgradeRecordsToV1(List<dynamic> records) {
  for (final value in records) {
    final record = value as Map<String, dynamic>;
    final scenario = record.remove('scenario_label');
    record.remove('input_mode');
    record['schema_version'] = 'm2_android_uat_v1';
    record['canonical_scene'] = scenario;
  }
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
