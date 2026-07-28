import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m2_12_release_matrix.dart' as verifier;

void main() {
  group('M2-12 parsed Android UAT closure evidence', () {
    test('complete PASS fixture has one consistent final candidate tuple', () {
      final report = verifier.scanM212ReleaseMatrix(
        projectRoot: _repoRootPath(),
        uatRecordsPath: File(_fixturePath()).parent.path,
      );

      expect(
        report.passes,
        isTrue,
        reason: verifier.renderM212ReleaseMatrixReport(report),
      );
    });

    for (final fixture in <_FixtureCase>[
      _FixtureCase('missing_field', 'missing required field', (records) {
        records.first.remove('executor');
      }),
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
        ],
        workingDirectory: _repoRootPath(),
        runInShell: false,
      );
      final output = '${result.stdout}\n${result.stderr}';

      expect(result.exitCode, isNonZero, reason: output);
      expect(output, contains('record verdict must be PASS'));
      expect(output, contains('M2-12 UAT closure matrix failed'));
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

String _repoRootPath() {
  final current = Directory.current;
  if (Directory(
    '${current.path}${Platform.pathSeparator}mobile${Platform.pathSeparator}lib',
  ).existsSync()) {
    return current.path;
  }
  return current.parent.path;
}
