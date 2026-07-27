import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('care_path source stays behind the approved semantic firewall', () {
    final sourceRoot = Directory('lib/features/care_path');
    expect(sourceRoot.existsSync(), isTrue);

    final dartFiles =
        sourceRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList(growable: false)
          ..sort((left, right) => left.path.compareTo(right.path));
    expect(dartFiles, isNotEmpty);

    final blockedStructuralTerms = <String>[
      'Ritual Room',
      'ritual_room',
      'mobile_v2',
      '金币',
      '排行榜',
      '第 1 课',
      '答对',
      '答错',
      '正确率',
      'CareReactionType',
      'TodayScreen',
      'SceneScreen',
      'OneUtterance',
    ];

    final violations = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final term in blockedStructuralTerms) {
        if (source.contains(term)) {
          violations.add('${file.path}: $term');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'care_path must not import superseded product copy, UI screen names, '
          'or a parallel reaction contract.',
    );
  });

  test('T4 one-turn practice copy stays behind the framing firewall', () {
    final screenFile = File(
      'lib/features/practice/presentation/screens/practice_session_screen.dart',
    );
    expect(screenFile.existsSync(), isTrue);

    final sourceBlockedTerms = <String>[
      'practiceSessionNotifierProvider',
      'PracticeCompletionView',
      'PracticeBottomActionBar',
      'PhraseCard(',
      'session-progress',
      'practice-progress-text',
      'practice-completion-view',
      'practiceProgress',
    ];
    final source = screenFile.readAsStringSync();
    final sourceViolations = [
      for (final term in sourceBlockedTerms)
        if (source.contains(term)) term,
    ];
    expect(
      sourceViolations,
      isEmpty,
      reason:
          'T4 practice screen must stay on the one-utterance loop and not '
          'restore session/progress/completion framing.',
    );

    final arbFile = File('lib/l10n/app_zh.arb');
    expect(arbFile.existsSync(), isTrue);
    final arb = jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;
    final oneTurnKeys = <String>[
      'practiceOneTurnTitle',
      'practiceEntryUnavailable',
      'practiceInvalidParams',
      'practiceUnavailable',
      'homePracticeUnavailable',
      'practiceWhenToSay',
      'practiceListenOnce',
      'practiceSaid',
      'practiceAudioPlayedOnce',
      'practiceAudioMissingInline',
      'practiceAudioMissingSnack',
      'practiceAudioUnavailableInline',
      'practiceAudioUnavailableSnack',
      'practiceSavingTrace',
      'practiceReactionPrompt',
      'practiceNextSupportTitle',
      'practiceQuietFallback',
      'practiceGardenTraceTitle',
    ];
    final copyViolations = <String>[];
    for (final key in oneTurnKeys) {
      final value = arb[key];
      expect(value, isA<String>(), reason: 'Missing T4 copy key $key');
      final text = value! as String;
      for (final term in _blockedTermsIn(text)) {
        copyViolations.add('$key: "$text" contains $term');
      }
    }

    expect(
      copyViolations,
      isEmpty,
      reason:
          'T4 one-turn copy must avoid lesson/progress/session/completion/XP/'
          'streak/task framing.',
    );
  });

  test('M1 onboarding removes the legacy phrase loop and blocked copy', () {
    final onboardingRoot = Directory('lib/features/onboarding');
    expect(onboardingRoot.existsSync(), isTrue);

    final sourceFiles = <File>[
      ...onboardingRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      File('lib/app/app.dart'),
      File('lib/app/router/app_go_router.dart'),
      File('lib/app/router/app_route_contract.dart'),
    ]..sort((left, right) => left.path.compareTo(right.path));
    expect(sourceFiles.every((file) => file.existsSync()), isTrue);

    const blockedLegacySymbols = <String>[
      'OnboardingSessionNotifier',
      'ScenePhraseService',
      'BabyReaction.responded',
      'BabyReaction.noResponse',
      'PracticeRecord',
      'OnboardingNameScreen',
      'OnboardingSceneScreen',
      'OnboardingPracticeScreen',
      'OnboardingCompleteScreen',
      'OnboardingGardenWelcomeScreen',
      "context.push('/onboarding/",
    ];
    final sourceViolations = <String>[];
    for (final file in sourceFiles) {
      final source = file.readAsStringSync();
      for (final symbol in blockedLegacySymbols) {
        if (source.contains(symbol)) {
          sourceViolations.add('${file.path}: $symbol');
        }
      }
    }
    expect(
      sourceViolations,
      isEmpty,
      reason: 'M1 must expose one onboarding runtime and route surface.',
    );

    final arbFile = File('lib/l10n/app_zh.arb');
    expect(arbFile.existsSync(), isTrue);
    final arb = jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;
    const blockedOnboardingCopy = <String>[
      '练习',
      '课程',
      '任务',
      '完成',
      '正确',
      '错误',
      '积分',
      '金币',
      '排行榜',
      'XP',
      'streak',
      'lesson',
      'exercise',
      'progress',
      '1 of 3',
    ];
    final copyViolations = <String>[];
    for (final entry in arb.entries) {
      if (!entry.key.startsWith('onboarding') || entry.value is! String) {
        continue;
      }
      final text = entry.value! as String;
      for (final term in blockedOnboardingCopy) {
        if (_containsVisibleTerm(text, term)) {
          copyViolations.add('${entry.key}: "$text" contains $term');
        }
      }
    }
    expect(
      copyViolations,
      isEmpty,
      reason: 'M1 onboarding copy must avoid lesson, task, and reward framing.',
    );
  });
}

const _blockedVisibleTerms = [
  '练习',
  '课程',
  '进度',
  '完成',
  '第 N 句',
  'task',
  'XP',
  'streak',
  'lesson',
  'session',
  'progress',
  'completion',
];

Iterable<String> _blockedTermsIn(String text) sync* {
  for (final term in _blockedVisibleTerms) {
    if (term == '第 N 句') {
      if (RegExp(r'第\s*\d+\s*句').hasMatch(text)) {
        yield term;
      }
      continue;
    }
    if (_isAsciiTerm(term)) {
      if (RegExp(
        '(?<![A-Za-z0-9_])${RegExp.escape(term)}(?![A-Za-z0-9_])',
        caseSensitive: false,
      ).hasMatch(text)) {
        yield term;
      }
      continue;
    }
    if (text.contains(term)) {
      yield term;
    }
  }
}

bool _isAsciiTerm(String term) {
  return RegExp(r'^[A-Za-z0-9_]+$').hasMatch(term);
}

bool _containsVisibleTerm(String text, String term) {
  if (_isAsciiTerm(term) || term == '1 of 3') {
    return RegExp(
      '(?<![A-Za-z0-9_])${RegExp.escape(term)}(?![A-Za-z0-9_])',
      caseSensitive: false,
    ).hasMatch(text);
  }
  return text.contains(term);
}
