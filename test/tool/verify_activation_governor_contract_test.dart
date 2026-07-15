import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

    test(
      'keeps Explore open for ideas examples routes future expansion and expert explanation',
      () async {
        final tempDir = await _createProjectWithMobileV2Boundary(
          'activation-governor-open-explore-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final report = verifier.scanActivationGovernorContract(
          projectRoot: tempDir.path,
          contractCases: _openExploreSurfaceCases,
        );

        expect(report.hasBlockingViolations, isFalse);
        expect(report.violations, isEmpty);
        expect(report.evaluatedCaseCount, _openExploreSurfaceCases.length);
      },
    );

    test(
      'rejects action-now activation CTAs without Governor decision across surfaces',
      () async {
        final tempDir = await _createProjectWithMobileV2Boundary(
          'activation-governor-surface-activation-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final report = verifier.scanActivationGovernorContract(
          projectRoot: tempDir.path,
          contractCases: _activationCtaWithoutGovernorCases,
        );

        expect(report.hasBlockingViolations, isTrue);
        expect(
          report.violations
              .where(
                (violation) =>
                    violation.type ==
                    verifier
                        .ActivationGovernorContractViolationType
                        .activationIntent,
              )
              .map((violation) => violation.caseId)
              .toSet(),
          _activationCtaWithoutGovernorCases
              .map((contractCase) => contractCase.id)
              .toSet(),
        );
        expect(
          report.violations.map((violation) => violation.caseId).toSet(),
          _activationCtaWithoutGovernorCases
              .map((contractCase) => contractCase.id)
              .toSet(),
        );
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
      'limits weak signals to prompts and review opportunities',
      () async {
        final tempDir = await _createProjectWithMobileV2Boundary(
          'activation-governor-weak-signal-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final report = verifier.scanActivationGovernorContract(
          projectRoot: tempDir.path,
          contractCases: _weakSignalCases,
        );

        expect(report.hasBlockingViolations, isTrue);
        expect(
          report.violations
              .where(
                (violation) =>
                    violation.type ==
                    verifier.ActivationGovernorContractViolationType.weakSignal,
              )
              .map((violation) => violation.caseId)
              .toSet(),
          containsAll({
            'weak-signal-familiar',
            'weak-signal-resting',
            'weak-signal-belongs-to-family',
            'weak-signal-active',
            'weak-signal-suggested-familiar',
          }),
        );
        expect(
          report.violations.map((violation) => violation.caseId),
          isNot(contains('weak-signal-review-prompt')),
        );
      },
    );

    test(
      'accepts only low-pressure non-scoring parent confirmed Garden transitions',
      () async {
        final tempDir = await _createProjectWithMobileV2Boundary(
          'activation-governor-parent-confirmation-',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final report = verifier.scanActivationGovernorContract(
          projectRoot: tempDir.path,
          contractCases: _parentConfirmationCases,
        );

        expect(report.hasBlockingViolations, isTrue);
        expect(
          report.violations.map((violation) => violation.caseId),
          containsAll([
            'familiar-pressure-copy',
            'resting-pressure-copy',
            'belongs-to-family-pressure-copy',
            'missing-low-pressure-question',
          ]),
        );
        expect(
          report.violations.map((violation) => violation.caseId),
          isNot(
            containsAll([
              'familiar-low-pressure',
              'resting-low-pressure',
              'belongs-to-family-low-pressure',
            ]),
          ),
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
      final rootSource = File('tool/verify_activation_governor_contract.dart');
      final source = (rootSource.existsSync()
            ? rootSource
            : File('../tool/verify_activation_governor_contract.dart'))
          .readAsStringSync();

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

const _openExploreSurfaceCases = <verifier.ActivationGovernorContractCase>[
  verifier.ActivationGovernorContractCase(
    id: 'explore-ideas',
    description: 'Explore can show ideas without action-now activation intent',
    surface: 'explore',
    producer: 'Explore',
    consumer: 'Parent',
    decisionSource: 'Explore',
    text: '看看这个说法，这里只是一些可以了解的声音想法。',
    gardenAction: 'show_candidate',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Explore ideas are not activation',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'explore-examples',
    description: 'Examples remain open when they do not ask for family action',
    surface: 'explore',
    producer: 'ExpertContent',
    consumer: 'Parent',
    decisionSource: 'Explore',
    text: '这里有几个例子，可以先读一读。',
    gardenAction: 'show_example',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Example copy is allowed when not action-now',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'explore-routes',
    description: 'Route exploration is not activation',
    surface: 'explore',
    producer: 'PackGraph',
    consumer: 'Parent',
    decisionSource: 'Explore',
    text: '了解这个场景，看看以后可以怎么走。',
    gardenAction: 'show_route',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Route exploration stays open',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'explore-future-expansion',
    description: 'Future expansion copy can remain open',
    surface: 'explore',
    producer: 'Explore',
    consumer: 'Parent',
    decisionSource: 'Explore',
    text: '以后也可以试试类似的声音。',
    gardenAction: 'show_future_expansion',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Future expansion is not today activation',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'explore-expert-explanation',
    description: 'Expert explanation can explain without activating',
    surface: 'expert',
    producer: 'ExpertContent',
    consumer: 'Parent',
    decisionSource: 'Explore',
    text: '小禾解释为什么这类声音适合换鞋场景。',
    gardenAction: 'show_explanation',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Expert explanation is not activation',
  ),
];

const _activationCtaWithoutGovernorCases =
    <verifier.ActivationGovernorContractCase>[
      verifier.ActivationGovernorContractCase(
        id: 'home-today-try',
        description: 'Home asks parent to try a candidate today',
        surface: 'home',
        producer: 'Home',
        consumer: 'Parent',
        decisionSource: 'Home',
        text: '今天试试这个声音。',
        gardenAction: 'show_candidate',
        hasGovernorDecision: false,
        hasParentIntent: false,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: false,
        expectedReason: 'Home activation CTA needs Governor decision',
      ),
      verifier.ActivationGovernorContractCase(
        id: 'onboarding-add-sound',
        description: 'Onboarding asks to add a new family sound',
        surface: 'onboarding',
        producer: 'Onboarding',
        consumer: 'Parent',
        decisionSource: 'Onboarding',
        text: '加一个新声音到你们家的日常。',
        gardenAction: 'show_candidate',
        hasGovernorDecision: false,
        hasParentIntent: false,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: false,
        expectedReason: 'Onboarding activation CTA needs Governor decision',
      ),
      verifier.ActivationGovernorContractCase(
        id: 'garden-start-micro-ritual',
        description: 'Garden starts a micro-ritual without Governor',
        surface: 'garden',
        producer: 'Garden',
        consumer: 'Parent',
        decisionSource: 'Garden',
        text: '开始这个 micro-ritual。',
        gardenAction: 'show_candidate',
        hasGovernorDecision: false,
        hasParentIntent: false,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: false,
        expectedReason: 'Garden activation CTA needs Governor decision',
      ),
      verifier.ActivationGovernorContractCase(
        id: 'runtime-say-during-routine',
        description: 'Runtime tells the parent to say the sound now',
        surface: 'runtime',
        producer: 'Runtime',
        consumer: 'Parent',
        decisionSource: 'Runtime',
        text: '睡前就说这句。',
        gardenAction: 'show_candidate',
        hasGovernorDecision: false,
        hasParentIntent: false,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: false,
        expectedReason: 'Runtime action-now copy needs Governor decision',
      ),
      verifier.ActivationGovernorContractCase(
        id: 'reminder-try-now',
        description: 'Reminder copy implies immediate activation',
        surface: 'reminder',
        producer: 'Reminder',
        consumer: 'Parent',
        decisionSource: 'Reminder',
        text: '现在试这一句。',
        gardenAction: 'show_candidate',
        hasGovernorDecision: false,
        hasParentIntent: false,
        requiresGovernorDecision: true,
        requiresParentConfirmation: false,
        weakSignalOnly: false,
        expectedPass: false,
        expectedReason: 'Reminder activation copy needs Governor decision',
      ),
    ];

const _weakSignalCases = <verifier.ActivationGovernorContractCase>[
  verifier.ActivationGovernorContractCase(
    id: 'weak-signal-review-prompt',
    description: 'Weak signals may surface a review prompt only',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'GardenReviewPrompt',
    text: '要不要看看这句现在适不适合？',
    gardenAction: 'prompt_review',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: true,
    expectedPass: true,
    expectedReason: 'Weak signals may prompt review',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'weak-signal-familiar',
    description: 'Weak signals cannot mark familiar',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'WeakSignal',
    text: 'Repeated opens show this is familiar.',
    gardenAction: 'set_familiar',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: true,
    expectedPass: false,
    expectedReason: 'Weak signals cannot write familiar truth',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'weak-signal-resting',
    description: 'Weak signals cannot mark resting',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'WeakSignal',
    text: 'No recent use means this should rest.',
    gardenAction: 'set_resting',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: true,
    expectedPass: false,
    expectedReason: 'Weak signals cannot write resting truth',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'weak-signal-belongs-to-family',
    description: 'Weak signals cannot mark belongs_to_family',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'WeakSignal',
    text: 'Routine returns prove this belongs to the family.',
    gardenAction: 'set_belongs_to_family',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: true,
    expectedPass: false,
    expectedReason: 'Weak signals cannot write belongs_to_family truth',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'weak-signal-active',
    description: 'Weak signals cannot activate a candidate',
    surface: 'home',
    producer: 'Home',
    consumer: 'Parent',
    decisionSource: 'WeakSignal',
    text: 'Views show readiness, set active.',
    gardenAction: 'set_active',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: true,
    requiresParentConfirmation: false,
    weakSignalOnly: true,
    expectedPass: false,
    expectedReason: 'Weak signals cannot activate',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'weak-signal-suggested-familiar',
    description: 'Weak signals cannot create truth-like suggested familiar',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'WeakSignal',
    text: 'Almost familiar from repeated card opens.',
    gardenAction: 'suggested_familiar',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: true,
    expectedPass: false,
    expectedReason: 'Truth-like suggested familiar is not allowed',
  ),
];

const _parentConfirmationCases = <verifier.ActivationGovernorContractCase>[
  verifier.ActivationGovernorContractCase(
    id: 'familiar-low-pressure',
    description: 'Parent confirms familiar with low-pressure language',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'ParentConfirmation',
    text: '这句最近会自然冒出来吗？',
    gardenAction: 'set_familiar',
    hasGovernorDecision: false,
    hasParentIntent: true,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Low-pressure familiar confirmation is allowed',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'resting-low-pressure',
    description: 'Parent confirms resting with low-pressure language',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'ParentConfirmation',
    text: '要不要先放一边？',
    gardenAction: 'set_resting',
    hasGovernorDecision: false,
    hasParentIntent: true,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Low-pressure resting confirmation is allowed',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'belongs-to-family-low-pressure',
    description: 'Parent confirms belongs_to_family with low-pressure language',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'ParentConfirmation',
    text: '这句是不是已经属于你们家了？',
    gardenAction: 'set_belongs_to_family',
    hasGovernorDecision: false,
    hasParentIntent: true,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Low-pressure family confirmation is allowed',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'familiar-pressure-copy',
    description: 'Familiar confirmation cannot use checklist pressure',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'ParentConfirmation',
    text: '连续完成三天就打卡成长，确认后解锁奖励。',
    gardenAction: 'set_familiar',
    hasGovernorDecision: false,
    hasParentIntent: true,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: false,
    expectedPass: false,
    expectedReason: 'Pressure language is banned',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'resting-pressure-copy',
    description: 'Resting confirmation cannot punish inactivity',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'ParentConfirmation',
    text: '没完成就降进度条，把这句惩罚性休眠。',
    gardenAction: 'set_resting',
    hasGovernorDecision: false,
    hasParentIntent: true,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: false,
    expectedPass: false,
    expectedReason: 'Resting cannot be framed as punishment',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'belongs-to-family-pressure-copy',
    description: 'Family transfer cannot use scoring language',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'ParentConfirmation',
    text: '得分满了，完成度达到 100%，已经属于你们家。',
    gardenAction: 'set_belongs_to_family',
    hasGovernorDecision: false,
    hasParentIntent: true,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: false,
    expectedPass: false,
    expectedReason: 'Family transfer cannot use score or completion pressure',
  ),
  verifier.ActivationGovernorContractCase(
    id: 'missing-low-pressure-question',
    description: 'Parent confirmation needs a low-pressure confirmation prompt',
    surface: 'garden',
    producer: 'Garden',
    consumer: 'Parent',
    decisionSource: 'ParentConfirmation',
    text: 'Parent tapped yes.',
    gardenAction: 'set_familiar',
    hasGovernorDecision: false,
    hasParentIntent: true,
    requiresGovernorDecision: false,
    requiresParentConfirmation: true,
    weakSignalOnly: false,
    expectedPass: false,
    expectedReason: 'Parent confirmation requires low-pressure copy',
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
