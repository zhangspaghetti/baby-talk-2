import 'dart:io';

import 'package:test/test.dart';

import '../../tool/verify_activation_governor_contract.dart' as verifier;

void main() {
  group('M010-P40 activation governor contract scan', () {
    test('fails closed when mobile_v2/lib is missing', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'activation-governor-missing-boundary-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final report = verifier.scanActivationGovernorContract(
        projectRoot: tempDir.path,
        contractCases: _passingExploreCases,
      );

      expect(report.hasBlockingViolations, isTrue);
      expect(
        report.countByType(
          verifier.ActivationGovernorContractViolationType.missingBoundary,
        ),
        1,
      );
      expect(
        verifier.renderActivationGovernorContractReport(report),
        contains('activation_governor_contract_status=fail'),
      );
    });

    test('fails closed when contract cases are empty', () async {
      final tempDir = await _createProjectWithMobileV2Boundary(
        'activation-governor-empty-cases-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final report = verifier.scanActivationGovernorContract(
        projectRoot: tempDir.path,
        contractCases: const [],
      );

      expect(report.hasBlockingViolations, isTrue);
      expect(
        report.countByType(
          verifier.ActivationGovernorContractViolationType.contractFixture,
        ),
        1,
      );
      expect(
        report.violations.single.reason,
        contains('typed Activation Governor contract cases are required'),
      );
    });

    test(
      'passes positive Explore candidate cases without Governor decisions',
      () async {
        final tempDir = await _createProjectWithMobileV2Boundary(
          'activation-governor-explore-pass-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final report = verifier.scanActivationGovernorContract(
          projectRoot: tempDir.path,
          contractCases: _passingExploreCases,
        );

        expect(report.hasBlockingViolations, isFalse);
        expect(report.violations, isEmpty);
        expect(report.evaluatedCaseCount, _passingExploreCases.length);
      },
    );

    test('fails Pack or Graph direct activation shortcuts', () async {
      final tempDir = await _createProjectWithMobileV2Boundary(
        'activation-governor-pack-bypass-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final report = verifier.scanActivationGovernorContract(
        projectRoot: tempDir.path,
        contractCases: const [
          verifier.ActivationGovernorContractCase(
            id: 'pack-direct-active',
            description: 'Pack match directly creates active routine',
            surface: 'strategy-pack',
            producer: 'PackGraph',
            consumer: 'Runtime',
            decisionSource: 'PackGraph',
            text: 'Matched this routine, start this micro-ritual today.',
            gardenAction: 'set_active',
            hasGovernorDecision: false,
            hasParentIntent: true,
            requiresGovernorDecision: true,
            requiresParentConfirmation: false,
            weakSignalOnly: false,
            expectedPass: false,
            expectedReason: 'Pack/Graph cannot create active micro-rituals',
          ),
        ],
      );

      expect(report.hasBlockingViolations, isTrue);
      expect(
        report.violations.map((violation) => violation.type),
        contains(verifier.ActivationGovernorContractViolationType.authority),
      );
      expect(
        report.violations.map((violation) => violation.caseId),
        contains('pack-direct-active'),
      );
    });

    test('fails Runtime self-governance but passes decision consumption', () async {
      final tempDir = await _createProjectWithMobileV2Boundary(
        'activation-governor-runtime-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final report = verifier.scanActivationGovernorContract(
        projectRoot: tempDir.path,
        contractCases: const [
          verifier.ActivationGovernorContractCase(
            id: 'runtime-self-governs',
            description: 'Runtime decides activation policy by itself',
            surface: 'runtime-agent',
            producer: 'Runtime',
            consumer: 'Parent',
            decisionSource: 'Runtime',
            text: 'I decided this is ready; say this during shoes today.',
            gardenAction: 'set_active',
            hasGovernorDecision: false,
            hasParentIntent: true,
            requiresGovernorDecision: true,
            requiresParentConfirmation: false,
            weakSignalOnly: false,
            expectedPass: false,
            expectedReason: 'Runtime cannot self-govern activation',
          ),
          verifier.ActivationGovernorContractCase(
            id: 'runtime-consumes-governor',
            description: 'Runtime applies existing allow_activation',
            surface: 'runtime-agent',
            producer: 'Runtime',
            consumer: 'Parent',
            decisionSource: 'ActivationGovernor',
            text: 'Use the existing allow_activation decision for this sound.',
            gardenAction: 'present_active',
            hasGovernorDecision: true,
            hasParentIntent: true,
            requiresGovernorDecision: true,
            requiresParentConfirmation: false,
            weakSignalOnly: false,
            expectedPass: true,
            expectedReason: 'Runtime may consume an existing Governor decision',
          ),
        ],
      );

      expect(report.hasBlockingViolations, isTrue);
      expect(
        report.violations.map((violation) => violation.caseId),
        contains('runtime-self-governs'),
      );
      expect(
        report.violations.map((violation) => violation.caseId),
        isNot(contains('runtime-consumes-governor')),
      );
    });

    test(
      'allows Garden presentation or parent confirmation and rejects policy ownership',
      () async {
        final tempDir = await _createProjectWithMobileV2Boundary(
          'activation-governor-garden-policy-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final report = verifier.scanActivationGovernorContract(
          projectRoot: tempDir.path,
          contractCases: const [
            verifier.ActivationGovernorContractCase(
              id: 'garden-presents-state',
              description: 'Garden presents existing memory state',
              surface: 'garden',
              producer: 'Garden',
              consumer: 'Parent',
              decisionSource: 'ActivationGovernor',
              text: 'This sound is active; does it still fit your routine?',
              gardenAction: 'present_state',
              hasGovernorDecision: true,
              hasParentIntent: false,
              requiresGovernorDecision: false,
              requiresParentConfirmation: false,
              weakSignalOnly: false,
              expectedPass: true,
              expectedReason: 'Garden may present state',
            ),
            verifier.ActivationGovernorContractCase(
              id: 'garden-confirms-familiar',
              description: 'Garden collects low-pressure parent confirmation',
              surface: 'garden',
              producer: 'Garden',
              consumer: 'Parent',
              decisionSource: 'ParentConfirmation',
              text: 'Does this sound feel natural in your family lately?',
              gardenAction: 'set_familiar',
              hasGovernorDecision: false,
              hasParentIntent: true,
              requiresGovernorDecision: false,
              requiresParentConfirmation: true,
              weakSignalOnly: false,
              expectedPass: true,
              expectedReason: 'Garden may write familiar after confirmation',
            ),
            verifier.ActivationGovernorContractCase(
              id: 'garden-owns-policy',
              description: 'Garden decides activation policy',
              surface: 'garden',
              producer: 'Garden',
              consumer: 'Runtime',
              decisionSource: 'Garden',
              text: 'Garden policy says add this sound today.',
              gardenAction: 'activation_policy',
              hasGovernorDecision: false,
              hasParentIntent: true,
              requiresGovernorDecision: true,
              requiresParentConfirmation: false,
              weakSignalOnly: false,
              expectedPass: false,
              expectedReason: 'Garden cannot own activation policy',
            ),
          ],
        );

        expect(report.hasBlockingViolations, isTrue);
        expect(
          report.violations.map((violation) => violation.caseId),
          contains('garden-owns-policy'),
        );
        expect(
          report.violations.map((violation) => violation.caseId),
          isNot(contains('garden-presents-state')),
        );
        expect(
          report.violations.map((violation) => violation.caseId),
          isNot(contains('garden-confirms-familiar')),
        );
      },
    );

    test(
      'candidate to active requires parent intent and Governor allow_activation',
      () async {
        final tempDir = await _createProjectWithMobileV2Boundary(
          'activation-governor-candidate-active-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final report = verifier.scanActivationGovernorContract(
          projectRoot: tempDir.path,
          contractCases: const [
            verifier.ActivationGovernorContractCase(
              id: 'candidate-active-without-parent',
              description: 'Governor decision without parent readiness',
              surface: 'home',
              producer: 'ActivationGovernor',
              consumer: 'Home',
              decisionSource: 'ActivationGovernor',
              text: 'allow_activation is present for this candidate.',
              gardenAction: 'set_active',
              hasGovernorDecision: true,
              hasParentIntent: false,
              requiresGovernorDecision: true,
              requiresParentConfirmation: false,
              weakSignalOnly: false,
              expectedPass: false,
              expectedReason: 'active requires parent intent',
            ),
            verifier.ActivationGovernorContractCase(
              id: 'candidate-active-without-governor',
              description: 'Parent is ready but Governor is absent',
              surface: 'onboarding',
              producer: 'Onboarding',
              consumer: 'Parent',
              decisionSource: 'Onboarding',
              text: 'Parent is ready, start this micro-ritual today.',
              gardenAction: 'set_active',
              hasGovernorDecision: false,
              hasParentIntent: true,
              requiresGovernorDecision: true,
              requiresParentConfirmation: false,
              weakSignalOnly: false,
              expectedPass: false,
              expectedReason: 'active requires Governor allow_activation',
            ),
            verifier.ActivationGovernorContractCase(
              id: 'candidate-active-governed',
              description: 'Parent readiness plus Governor allow_activation',
              surface: 'home',
              producer: 'ActivationGovernor',
              consumer: 'Home',
              decisionSource: 'ActivationGovernor',
              text: 'Parent chose this sound and Governor returned allow_activation.',
              gardenAction: 'set_active',
              hasGovernorDecision: true,
              hasParentIntent: true,
              requiresGovernorDecision: true,
              requiresParentConfirmation: false,
              weakSignalOnly: false,
              expectedPass: true,
              expectedReason: 'candidate can become active when governed',
            ),
          ],
        );

        expect(report.hasBlockingViolations, isTrue);
        expect(
          report.violations.map((violation) => violation.caseId),
          containsAll([
            'candidate-active-without-parent',
            'candidate-active-without-governor',
          ]),
        );
        expect(
          report.violations.map((violation) => violation.caseId),
          isNot(contains('candidate-active-governed')),
        );
      },
    );

    test('CLI parses help and unknown arguments without scanning', () {
      final help = verifier.ActivationGovernorContractCliOptions.parse(const [
        '--help',
      ]);
      final unknown = verifier.ActivationGovernorContractCliOptions.parse(
        const ['--repo-wide'],
      );

      expect(help.showHelp, isTrue);
      expect(help.usageError, isNull);
      expect(unknown.usageError, contains('Unknown argument'));
    });

    test('does not scan repo-wide deprecated or reference material', () async {
      final tempDir = await _createProjectWithMobileV2Boundary(
        'activation-governor-scan-scope-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeProjectFile(
        tempDir,
        'docs/reference_activation_copy.md',
        'Reference-only note: start this micro-ritual today.',
      );
      await _writeProjectFile(
        tempDir,
        'mobile/lib/features/garden/old_growth_reference.dart',
        'const oldCopy = "GardenGrowth streak reward";',
      );

      final report = verifier.scanActivationGovernorContract(
        projectRoot: tempDir.path,
        contractCases: _passingExploreCases,
      );

      expect(report.hasBlockingViolations, isFalse);
      expect(report.scannedRuntimeFileCount, 1);
      expect(report.violations, isEmpty);
    });

    test('keeps contract fixtures typed in Dart without JSON or YAML paths', () {
      final source = File(
        'tool/verify_activation_governor_contract.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('.json')));
      expect(source, isNot(contains('.yaml')));
      expect(source, isNot(contains('.yml')));
      expect(source, isNot(contains('jsonDecode')));
      expect(source, isNot(contains('loadFixture')));
      expect(source, contains('ActivationGovernorContractCase'));
    });
  });
}

const _passingExploreCases = <verifier.ActivationGovernorContractCase>[
  verifier.ActivationGovernorContractCase(
    id: 'explore-route-idea',
    description: 'Explore can show route ideas without activation intent',
    surface: 'explore',
    producer: 'PackGraph',
    consumer: 'Parent',
    decisionSource: 'Explore',
    text: 'Here are gentle bath-time sound ideas to read later.',
    gardenAction: 'show_candidate',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Explore candidate generation is not activation',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'expert-example-only',
    description: 'Expert explanation stays open without family action now',
    surface: 'expert',
    producer: 'ExpertContent',
    consumer: 'Parent',
    decisionSource: 'Explore',
    text: 'Example opener: Shoes on. This is only an explanation.',
    gardenAction: 'show_example',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Examples may stay open when not action-now',
  ),
];

Future<Directory> _createProjectWithMobileV2Boundary(String prefix) async {
  final tempDir = await Directory.systemTemp.createTemp(prefix);
  await _writeProjectFile(
    tempDir,
    'mobile_v2/lib/vnext_semantic_boundary.dart',
    '''
const familyEnglishMicroRitualUnit = 'Family English Micro-ritual';
const activationCandidateBoundary = 'Candidate matching is not activation';
''',
  );
  return tempDir;
}

Future<void> _writeProjectFile(
  Directory projectRoot,
  String relativePath,
  String content,
) async {
  final targetFile = File('${projectRoot.path}/$relativePath');
  await targetFile.parent.create(recursive: true);
  await targetFile.writeAsString(content);
}
