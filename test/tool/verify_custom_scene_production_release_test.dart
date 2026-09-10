import 'dart:io';

import 'package:test/test.dart';

import '../../tool/verify_m2_13_closure_candidate.dart' as closure;
import '../../tool/verify_custom_scene_production_release.dart' as verifier;

void main() {
  test('current repository passes independent production default gate', () {
    final report = verifier.scanCustomSceneProductionReleaseGate(
      projectRoot: _repoRootPath(),
    );

    expect(
      report.passes,
      isTrue,
      reason: verifier.renderCustomSceneProductionReleaseGateReport(report),
    );
  });

  test('formal M2-13 privacy closure invokes independent production gate', () {
    final privacyGate = closure.m213ClosureGates.singleWhere(
      (gate) => gate.id == 'privacy',
    );

    expect(
      privacyGate.commands.any(
        (command) => command.arguments.contains(
          'tool/verify_custom_scene_production_release.dart',
        ),
      ),
      isTrue,
    );
  });

  test('rejects a false mobile default', () async {
    final root = await _createFixture(
      mobileFeatureFlag: _mobileFeatureFlag.replaceFirst('true', 'false'),
    );
    addTearDown(() => root.delete(recursive: true));

    final report = verifier.scanCustomSceneProductionReleaseGate(
      projectRoot: root.path,
    );

    expect(report.passes, isFalse);
    expect(
      report.violations.map((value) => value.rule),
      contains('mobile_default_enabled'),
    );
  });

  test('rejects a non-agentic production provider mode', () async {
    final root = await _createFixture(
      productionValues: _productionValues.replaceFirst('agentic', 'disabled'),
    );
    addTearDown(() => root.delete(recursive: true));

    final report = verifier.scanCustomSceneProductionReleaseGate(
      projectRoot: root.path,
    );

    expect(report.passes, isFalse);
    expect(
      report.violations.map((value) => value.rule),
      contains('production_helm_profile'),
    );
  });

  test('rejects a missing complete custom-scene route', () async {
    final root = await _createFixture(
      productionValues: _productionValues.replaceFirst(
        '  custom-scene-repair: [dashscope-qwen]\n',
        '  custom-scene-repair: []\n',
      ),
    );
    addTearDown(() => root.delete(recursive: true));

    final report = verifier.scanCustomSceneProductionReleaseGate(
      projectRoot: root.path,
    );

    expect(report.passes, isFalse);
    expect(
      report.violations.map((value) => value.rule),
      contains('production_helm_profile'),
    );
  });

  test('rejects runtime template that disables agentic custom scene', () async {
    final root = await _createFixture(
      practiceAiTemplate: _practiceAiTemplate.replaceFirst(
        'enabled: {{ eq \$providerMode "agentic" }}',
        'enabled: false',
      ),
    );
    addTearDown(() => root.delete(recursive: true));

    final report = verifier.scanCustomSceneProductionReleaseGate(
      projectRoot: root.path,
    );

    expect(report.passes, isFalse);
    expect(
      report.violations.map((value) => value.rule),
      contains('backend_runtime_enabled'),
    );
  });

  test('rejects release workflow that explicitly disables entry', () async {
    final root = await _createFixture(
      mobileBuildWorkflow:
          '$_mobileBuildWorkflow\n'
          '  --dart-define=BABY_TALK_CUSTOM_SCENE_ENABLED=false\n',
    );
    addTearDown(() => root.delete(recursive: true));

    final report = verifier.scanCustomSceneProductionReleaseGate(
      projectRoot: root.path,
    );

    expect(report.passes, isFalse);
    expect(
      report.violations.map((value) => value.rule),
      contains('mobile_release_build'),
    );
  });
}

Future<Directory> _createFixture({
  String mobileFeatureFlag = _mobileFeatureFlag,
  String productionValues = _productionValues,
  String practiceAiTemplate = _practiceAiTemplate,
  String mobileBuildWorkflow = _mobileBuildWorkflow,
}) async {
  final root = await Directory.systemTemp.createTemp(
    'custom_scene_production_release_gate_',
  );
  await _write(root, verifierPath, mobileFeatureFlag);
  await _write(root, productionValuesPath, productionValues);
  await _write(root, practiceAiTemplatePath, practiceAiTemplate);
  await _write(root, mobileBuildWorkflowPath, mobileBuildWorkflow);
  return root;
}

Future<void> _write(Directory root, String relativePath, String source) async {
  final file = File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(source);
}

String _repoRootPath() {
  final current = Directory.current;
  if (Directory(
    '${current.path}${Platform.pathSeparator}mobile',
  ).existsSync()) {
    return current.path;
  }
  return current.parent.path;
}

const verifierPath =
    'mobile/lib/features/custom_scene/application/custom_scene_feature_flag.dart';
const productionValuesPath = 'deploy/helm/babytalk-app/values-production.yaml';
const practiceAiTemplatePath =
    'deploy/helm/babytalk-app/templates/practice-ai-configmap.yaml';
const mobileBuildWorkflowPath = '.github/workflows/mobile-build.yml';

const _mobileFeatureFlag = '''
const customSceneFeatureEnabledByDefault = bool.fromEnvironment(
  'BABY_TALK_CUSTOM_SCENE_ENABLED',
  defaultValue: true,
);
''';

const _productionValues = '''
practiceAi:
  providerMode: agentic
  routingPolicyVersion: custom-scene-routing-v1
  providers:
    dashscope-qwen:
      type: openai-compatible
      model: qwen3.6-flash
  capabilities:
    custom-scene-generator: [dashscope-qwen]
    custom-scene-quality-judge: [dashscope-qwen]
    custom-scene-repair: [dashscope-qwen]
  secret:
    existingSecret: babytalk-practice-ai
    rolloutVersion: "1"
config:
  key: value
''';

const _practiceAiTemplate =
    '            enabled: {{ eq \$providerMode "agentic" }}\n';

const _mobileBuildWorkflow = '''
run: flutter build apk --release
run: flutter build appbundle --release
''';
