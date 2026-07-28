import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m2_12_release_matrix.dart' as verifier;

void main() {
  test('current repository has every automatable M2-12 evidence target', () {
    final report = verifier.scanM212ReleaseMatrix(projectRoot: _repoRootPath());
    expect(
      report.passes,
      isTrue,
      reason: verifier.renderM212ReleaseMatrixReport(report),
    );
  });

  test('missing target fails closed', () async {
    final root = await Directory.systemTemp.createTemp('m2_12_release_matrix_');
    addTearDown(() => root.delete(recursive: true));

    final report = verifier.scanM212ReleaseMatrix(projectRoot: root.path);

    expect(report.passes, isFalse);
    expect(
      report.missingEvidence.map((spec) => spec.id),
      contains('backend_discovery_contract'),
    );
  });
}

String _repoRootPath() {
  final current = Directory.current;
  if (Directory('${current.path}/mobile/lib').existsSync()) return current.path;
  return current.parent.path;
}
