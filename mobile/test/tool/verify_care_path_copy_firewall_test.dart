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
