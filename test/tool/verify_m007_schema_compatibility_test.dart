import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m007_s06_docs_coherence.dart' as docs;

void main() {
  group('schema compatibility matrix fixture validator', () {
    test('accepts 25 audited migration rows and required V23 evidence', () {
      expect(
        docs.validateSchemaCompatibilityMatrixText(_validMatrix()),
        isEmpty,
      );
    });

    test('rejects generic workload anchors', () {
      final matrix = _validMatrix().replaceFirst(
        _migrationAnchors['V3']!,
        'unreleased app-api',
      );

      expect(
        docs.validateSchemaCompatibilityMatrixText(matrix),
        contains(contains('unreleased app-api')),
      );
    });

    test(
      'rejects migration rows without exact 40-character commit anchors',
      () {
        final matrix = _validMatrix().replaceFirst(
          _migrationAnchors['V3']!,
          '012766e7',
        );

        expect(
          docs.validateSchemaCompatibilityMatrixText(matrix),
          contains(contains('40-character commit')),
        );
      },
    );

    test('rejects a wrong 40-character migration commit anchor', () {
      final matrix = _validMatrix().replaceFirst(
        _migrationAnchors['V3']!,
        'ffffffffffffffffffffffffffffffffffffffff',
      );

      expect(
        docs.validateSchemaCompatibilityMatrixText(matrix),
        contains(contains(_migrationAnchors['V3']!)),
      );
    });

    test('rejects migration rows with missing or invalid status', () {
      final missing = _validMatrix().replaceFirst('| compatible |', '|  |');
      final invalid = _validMatrix().replaceFirst(
        '| compatible |',
        '| unknown |',
      );

      expect(
        docs.validateSchemaCompatibilityMatrixText(missing),
        contains(contains('status')),
      );
      expect(
        docs.validateSchemaCompatibilityMatrixText(invalid),
        contains(contains('status')),
      );
    });

    test('requires V23 to record N-1 write incompatibility', () {
      final matrix = _validMatrix().replaceFirst(
        '| incompatible |',
        '| compatible |',
      );

      expect(
        docs.validateSchemaCompatibilityMatrixText(matrix),
        contains(contains('V23')),
      );
    });

    test('requires exact audited N and N-1 workload anchors', () {
      final missingN = _validMatrix().replaceFirst(_nWorkload, '40bb9600');
      final missingNMinusOne = _validMatrix().replaceFirst(
        _nMinusOneWorkload,
        '3ee8bb77',
      );

      expect(
        docs.validateSchemaCompatibilityMatrixText(missingN),
        contains(contains(_nWorkload)),
      );
      expect(
        docs.validateSchemaCompatibilityMatrixText(missingNMinusOne),
        contains(contains(_nMinusOneWorkload)),
      );
    });

    test('requires exact V23 rollback warning', () {
      final matrix = _validMatrix().replaceFirst(_rollbackWarning, '');

      expect(
        docs.validateSchemaCompatibilityMatrixText(matrix),
        contains(contains('rollback')),
      );
    });

    test('requires exact V23 migration evidence method', () {
      final matrix = _validMatrix().replaceFirst(_evidenceMethod, 'otherTest');

      expect(
        docs.validateSchemaCompatibilityMatrixText(matrix),
        contains(contains(_evidenceMethod)),
      );
    });
  });
}

const _nWorkload = '40bb9600991f5c7a0cf73eb59658b97ce590383f';
const _nMinusOneWorkload = '3ee8bb7729f450a3a3e65b279cc76662ebc1b75e';
const _v23Commit = 'a13d45407f2143bfe67fe623674d9696c2b7cb3f';
const _evidenceMethod =
    'v23UpgradePreservesLegacyReactionRowsButRejectsNMinusOneWrites';
const _rollbackWarning =
    'After V23+, do not roll back to `$_nMinusOneWorkload` while reaction-event writes are possible.';

const _versions = <String>[
  'V3',
  'V4',
  'V5',
  'V6',
  'V7',
  'V8',
  'V9',
  'V10',
  'V11',
  'V12',
  'V13',
  'V14',
  'V15',
  'V16',
  'V17',
  'V18',
  'V19',
  'V20',
  'V21',
  'V22',
  'V22.1',
  'V23',
  'V24',
  'V25',
  'V26',
];

const _migrationAnchors = <String, String>{
  'V3': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V4': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V5': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V6': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V7': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V8': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V9': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V10': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V11': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V12': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V13': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V14': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V15': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V16': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V17': '1755f529706d8caf45715be5cb5cccfbcdc65a85',
  'V18': 'efddef2670c81a4483e3e504322c1bdce300076d',
  'V19': 'efddef2670c81a4483e3e504322c1bdce300076d',
  'V20': 'a61f66d39f2b98417fe20fe2ed7f7c5a56c29d98',
  'V21': 'a61f66d39f2b98417fe20fe2ed7f7c5a56c29d98',
  'V22': '347c623ca58be8e7300b48d844c933a6bd257bdc',
  'V22.1': '190d9a1d0b30710d39f88d069a826f9eccbc7f59',
  'V23': _v23Commit,
  'V24': '26a5c1f6696aba728ffe34afa233a2dd588c6dd8',
  'V25': 'ad05936ea58283fced9db67a21f9cde2c63ea1c1',
  'V26': '132ea115b3b8c693537aac1e690e84f5d0e18ac9',
};

String _validMatrix() {
  final rows = <String>[];
  for (final version in _versions) {
    final anchor = _migrationAnchors[version]!;
    final status = version == 'V23' ? 'incompatible' : 'compatible';
    final notes = version == 'V23'
        ? 'Legacy rows/read survive mapping; N-1 writes old values and fails under V23+.'
        : 'Additive migration evidence recorded.';
    rows.add(
      '| $version | `${version.replaceAll('.', '_')}__fixture.sql` | `$anchor` | $status | $notes |',
    );
  }

  return '''
# Schema Compatibility Matrix

No release tag or image digest exists; compatibility is audited by exact commits.

- Audited N workload: `$_nWorkload`
- Exact N-1/pre-V23 workload: `$_nMinusOneWorkload`
- V23 introducing workload/migration commit: `$_v23Commit`

| Schema Version | Migration File | Commit Anchor | Status | Evidence |
| --- | --- | --- | --- | --- |
${rows.join('\n')}

$_rollbackWarning

Evidence: `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/dbmigration/DbMigrationSmokeTest.java`, commit `012766e7`, method `$_evidenceMethod`.
''';
}
