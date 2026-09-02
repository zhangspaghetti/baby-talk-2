import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_m2_11_custom_scene_gates.dart' as verifier;

void main() {
  test('current repository passes M2-11 custom-scene gates', () {
    final report = verifier.scanM211CustomSceneGates(
      projectRoot: _repoRootPath(),
    );
    expect(
      report.violations,
      isEmpty,
      reason: verifier.renderM211CustomSceneGateReport(report),
    );
  });

  for (final fixture in <_FixtureCase>[
    const _FixtureCase(
      'raw_scene_telemetry',
      'mobile/lib/features/custom_scene/application/unsafe.dart',
      'raw_scene_telemetry',
    ),
    const _FixtureCase(
      'mobile_owner_hmac',
      'mobile/lib/features/custom_scene/domain/unsafe.dart',
      'mobile_owner_hmac',
    ),
    const _FixtureCase(
      'generated_audio_file',
      'mobile/lib/features/care_path/data/audio/unsafe.dart',
      'generated_audio_persistence',
    ),
    const _FixtureCase(
      'ui_banned_semantic',
      'mobile/lib/features/custom_scene/presentation/unsafe.dart',
      'custom_scene_ui_semantics',
    ),
    const _FixtureCase(
      'ui_dio',
      'mobile/lib/features/custom_scene/presentation/unsafe.dart',
      'ui_data_dependency',
    ),
  ]) {
    test('negative fixture ${fixture.name} fails closed', () async {
      final root = await _createPassingFixtureRoot();
      addTearDown(() => root.delete(recursive: true));
      final target = File('${root.path}/${fixture.targetPath}');
      await target.parent.create(recursive: true);
      await target.writeAsString(await _fixtureText(fixture.name));

      final report = verifier.scanM211CustomSceneGates(projectRoot: root.path);
      expect(
        report.violations.map((violation) => violation.rule),
        contains(fixture.rule),
      );
    });
  }
}

class _FixtureCase {
  const _FixtureCase(this.name, this.targetPath, this.rule);

  final String name;
  final String targetPath;
  final String rule;
}

Future<Directory> _createPassingFixtureRoot() async {
  final root = await Directory.systemTemp.createTemp(
    'm2_11_custom_scene_gate_',
  );
  await _write(
    root,
    'mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart',
    '''
LocalSensitiveDataClearanceTrigger.logoutSessionOnly
LocalSensitiveDataTarget.customSceneDraft
LocalSensitiveDataTarget.generatedCareMoments
LocalSensitiveDataTarget.generatedAudioMemory
LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed
LocalSensitiveDataTarget.customSceneDraft
LocalSensitiveDataTarget.generatedCareMoments
LocalSensitiveDataTarget.generatedAudioMemory
LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed
LocalSensitiveDataTarget.customSceneDraft
LocalSensitiveDataTarget.generatedCareMoments
LocalSensitiveDataTarget.generatedAudioMemory
''',
  );
  await _write(
    root,
    'mobile/lib/features/account/presentation/account_notifier.dart',
    'LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed',
  );
  await _write(
    root,
    'backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/FakeSceneContentGenerator.java',
    '@Profile({"dev", "test"})',
  );
  await _write(
    root,
    'backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/audio/GeneratedSpeechSynthesisConfiguration.java',
    'anyMatch("dev"::equals)\\nfake generated speech provider is restricted to the dev profile',
  );
  return root;
}

Future<void> _write(Directory root, String relativePath, String value) async {
  final file = File('${root.path}/$relativePath');
  await file.parent.create(recursive: true);
  await file.writeAsString(value);
}

Future<String> _fixtureText(String name) {
  return File(
    '${_repoRootPath()}/test/fixtures/m2_11_custom_scene_gates/negative/$name.txt',
  ).readAsString();
}

String _repoRootPath() {
  final current = Directory.current;
  if (Directory('${current.path}/mobile/lib').existsSync()) return current.path;
  return current.parent.path;
}
