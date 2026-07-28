import 'dart:io';

const m212ReleaseMatrixSuccessMarker =
    'M2-12 automatable release matrix is present.';

const m212ReleaseMatrixUsage =
    'Usage: dart tool/verify_m2_12_release_matrix.dart [--help]';

const m212RequiredEvidence = <M212EvidenceSpec>[
  M212EvidenceSpec(
    'backend_discovery_contract',
    'Backend discovery contract',
    'backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryControllerTest.java',
  ),
  M212EvidenceSpec(
    'backend_bundle_state',
    'Backend six-utterance bundle and state constraints',
    'backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/GeneratedCareMomentBundleTest.java',
  ),
  M212EvidenceSpec(
    'backend_idempotency_owner',
    'Backend clientRequestId, exact reuse, and owner isolation',
    'backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java',
  ),
  M212EvidenceSpec(
    'backend_concurrency',
    'Backend Testcontainers concurrency',
    'backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentConcurrencyTest.java',
  ),
  M212EvidenceSpec(
    'backend_generated_tts',
    'Backend generated TTS owner, content, and utterance checks',
    'backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/audio/GeneratedUtteranceAudioServiceTest.java',
  ),
  M212EvidenceSpec(
    'backend_generated_tts_http',
    'Backend authenticated generated-audio HTTP endpoint E2E',
    'backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GeneratedUtteranceAudioHttpIntegrationTest.java',
  ),
  M212EvidenceSpec(
    'backend_audio_no_persistence',
    'Backend generated audio no-persistence verifier',
    'tool/verify_practice_generation_privacy.py',
  ),
  M212EvidenceSpec(
    'mobile_domain_data',
    'Mobile DTO, mapper, API, and repository contracts',
    'mobile/test/features/custom_scene/custom_scene_repository_test.dart',
  ),
  M212EvidenceSpec(
    'mobile_draft_continuation',
    'Mobile draft and exactly-once authentication continuation',
    'mobile/test/features/custom_scene/custom_scene_draft_continuation_test.dart',
  ),
  M212EvidenceSpec(
    'mobile_submission_state',
    'Mobile request state machine and unknown outcome reconciliation',
    'mobile/test/features/custom_scene/custom_scene_submission_controller_test.dart',
  ),
  M212EvidenceSpec(
    'mobile_today_scene',
    'Mobile Today and Scene entry/input widgets',
    'mobile/test/features/custom_scene/custom_scene_input_screen_test.dart',
  ),
  M212EvidenceSpec(
    'mobile_formal_care_turn',
    'Generated formal Care Turn, canonical reaction, Garden, and Today',
    'mobile/test/features/practice/generated/generated_practice_content_registry_test.dart',
  ),
  M212EvidenceSpec(
    'mobile_audio_memory',
    'Generated audio cache and late-playback cancellation',
    'mobile/test/features/care_path/presentation/care_audio_playback_controller_test.dart',
  ),
  M212EvidenceSpec(
    'mobile_audio_lifecycle',
    'Generated audio lifecycle clearing',
    'mobile/test/app/local_sensitive_data_clearance_registry_test.dart',
  ),
  M212EvidenceSpec(
    'mobile_r4',
    'Mobile R4 release budget policy',
    'mobile/test/tool/r4_release_gate_policy_test.dart',
  ),
  M212EvidenceSpec(
    'm211_privacy_lifecycle',
    'M2-11 privacy, architecture, and lifecycle gate',
    'tool/verify_m2_11_custom_scene_gates.dart',
  ),
  M212EvidenceSpec(
    'release_runner',
    'Repeatable M2-12 release runner',
    'scripts/verify-m2-12-release.ps1',
  ),
];

class M212EvidenceSpec {
  const M212EvidenceSpec(this.id, this.label, this.path);

  final String id;
  final String label;
  final String path;
}

class M212ReleaseMatrixReport {
  const M212ReleaseMatrixReport({required this.missingEvidence});

  final List<M212EvidenceSpec> missingEvidence;

  bool get passes => missingEvidence.isEmpty;
}

M212ReleaseMatrixReport scanM212ReleaseMatrix({String? projectRoot}) {
  final root = _normalize(projectRoot ?? Directory.current.path);
  return M212ReleaseMatrixReport(
    missingEvidence: m212RequiredEvidence
        .where((spec) => !File('$root/${spec.path}').existsSync())
        .toList(growable: false),
  );
}

String renderM212ReleaseMatrixReport(M212ReleaseMatrixReport report) {
  final buffer = StringBuffer()
    ..writeln(
      'm2_12_automatable_matrix_status=${report.passes ? 'pass' : 'fail'}',
    )
    ..writeln('required_evidence=${m212RequiredEvidence.length}')
    ..writeln('missing_evidence=${report.missingEvidence.length}');
  for (final spec in report.missingEvidence) {
    buffer.writeln('  missing ${spec.id} ${spec.path}');
  }
  return buffer.toString();
}

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(m212ReleaseMatrixUsage);
    return;
  }
  if (args.isNotEmpty) {
    stderr.writeln(m212ReleaseMatrixUsage);
    exit(64);
  }
  final report = scanM212ReleaseMatrix();
  stdout.write(renderM212ReleaseMatrixReport(report));
  if (!report.passes) exit(1);
  stdout.writeln(m212ReleaseMatrixSuccessMarker);
}

String _normalize(String value) => value.replaceAll('\\', '/');
