import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/verify_activation_governor_contract.dart' as verifier;

void main() {
  group('activation governor surface contract fixtures', () {
    test('allows Explore-only surface copy without Governor decisions', () async {
      final report = await _scanSurfaceFixture(
        'features/explore/open_route_examples.dart',
        '''
class OpenRouteExamples {
  final String routeCopy = '看看这个说法，这里有几个例子，以后也可以试试类似的声音。';
  final String expertCopy = '小禾解释这个场景为什么适合轻轻加入英语。';
}
''',
      );

      expect(report.hasBlockingViolations, isFalse);
      expect(report.violations, isEmpty);
    });

    for (final fixture in _activationIntentFixtures) {
      test('rejects ${fixture.name} activation copy without Governor', () async {
        final report = await _scanSurfaceFixture(fixture.path, fixture.content);

        expect(report.hasBlockingViolations, isTrue);
        expect(
          report.violations.any(
            (violation) =>
                violation.type ==
                verifier.ActivationGovernorContractViolationType.sourceScan,
          ),
          isTrue,
          reason: '${fixture.name} should be blocked by the source scanner',
        );
      });
    }

    test('rejects suspicious authority names outside allowed boundaries', () async {
      final report = await _scanSurfaceFixture(
        'features/garden/unsafe_authority_names.dart',
        '''
class UnsafeAuthorityNames {
  void markFamiliar() {}
  void setActive() {}
  void activationPolicy() {}
}
''',
      );

      expect(report.hasBlockingViolations, isTrue);
      expect(
        report.violations
            .where((violation) => violation.term != null)
            .map((violation) => violation.term)
            .toSet(),
        containsAll({'markFamiliar', 'setActive', 'activationPolicy'}),
      );
    });

    test(
      'allows suspicious names when scoped to Governor or parent confirmation boundaries',
      () async {
        final report = await _scanSurfaceFixture(
          'features/garden/safe_authority_names.dart',
          '''
class ActivationGovernorDecisionBoundary {
  void setActiveWithActivationGovernorAllowActivation() {}
}

class GardenParentConfirmationBoundary {
  void markFamiliarAfterParentConfirmation() {}
}
''',
        );

        expect(report.hasBlockingViolations, isFalse);
        expect(report.violations, isEmpty);
      },
    );

    test('rejects Garden pressure copy in runtime surface fixtures', () async {
      final report = await _scanSurfaceFixture(
        'features/garden/pressure_memory_copy.dart',
        '''
class PressureMemoryCopy {
  final String copy = '连续完成后打卡成长，解锁奖励并提高得分进度条。';
}
''',
      );

      expect(report.hasBlockingViolations, isTrue);
      expect(
        report.violations.any(
          (violation) =>
              violation.type ==
              verifier.ActivationGovernorContractViolationType.sourceScan,
        ),
        isTrue,
      );
    });
  });
}

const _activationIntentFixtures = <_SurfaceFixture>[
  _SurfaceFixture(
    name: 'Home',
    path: 'features/home/today_card.dart',
    content: '''
class TodayCard {
  final String copy = '今天试试这个声音。';
}
''',
  ),
  _SurfaceFixture(
    name: 'Onboarding',
    path: 'features/onboarding/first_sound.dart',
    content: '''
class FirstSound {
  final String copy = '加一个新声音到你们家的日常。';
}
''',
  ),
  _SurfaceFixture(
    name: 'Garden',
    path: 'features/garden/start_micro_ritual.dart',
    content: '''
class StartMicroRitual {
  final String copy = '开始这个 micro-ritual。';
}
''',
  ),
  _SurfaceFixture(
    name: 'Runtime',
    path: 'features/runtime/runtime_nudge.dart',
    content: '''
class RuntimeNudge {
  final String copy = '睡前就说这句。';
}
''',
  ),
  _SurfaceFixture(
    name: 'Reminder',
    path: 'features/reminder/push_like_copy.dart',
    content: '''
class PushLikeCopy {
  final String copy = '现在试这一句。';
}
''',
  ),
];

Future<verifier.ActivationGovernorContractReport> _scanSurfaceFixture(
  String runtimePath,
  String content,
) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'activation-governor-surface-contract-',
  );
  addTearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  final targetFile = File('${tempDir.path}/mobile_v2/lib/$runtimePath');
  await targetFile.parent.create(recursive: true);
  await targetFile.writeAsString(content);

  return verifier.scanActivationGovernorContract(
    projectRoot: tempDir.path,
    contractCases: _surfaceContractCases,
  );
}

const _surfaceContractCases = <verifier.ActivationGovernorContractCase>[
  verifier.ActivationGovernorContractCase(
    id: 'surface-open-explore-proof',
    description: 'Surface fixture scan uses a passing Explore contract case',
    surface: 'explore',
    producer: 'Explore',
    consumer: 'Parent',
    decisionSource: 'Explore',
    text: '这里有几个例子，可以先看看。',
    gardenAction: 'show_example',
    hasGovernorDecision: false,
    hasParentIntent: false,
    requiresGovernorDecision: false,
    requiresParentConfirmation: false,
    weakSignalOnly: false,
    expectedPass: true,
    expectedReason: 'Surface fixtures should be evaluated by source scan rules',
  ),
];

class _SurfaceFixture {
  const _SurfaceFixture({
    required this.name,
    required this.path,
    required this.content,
  });

  final String name;
  final String path;
  final String content;
}
