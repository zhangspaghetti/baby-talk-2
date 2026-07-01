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

    final blockedTerms = <String>[
      'Ritual Room',
      'ritual_room',
      'mobile_v2',
      'XP',
      '金币',
      '排行榜',
      '课程',
      '第 1 课',
      '答对',
      '答错',
      '正确率',
      'CareReactionType',
      'TodayScreen',
      'SceneScreen',
      'OneUtterance',
      'HomeScreen',
      'DiscoverScreen',
      'PracticeSessionScreen',
    ];

    final violations = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final term in blockedTerms) {
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
    final copyBlockedTerms = <String>[
      'XP',
      'streak',
      'task',
      'lesson',
      'session',
      'progress',
      '课程',
      '进度',
      '任务',
      '连胜',
      '第 1 /',
      '完成总结',
    ];
    final copyViolations = <String>[];
    for (final key in oneTurnKeys) {
      final value = arb[key];
      expect(value, isA<String>(), reason: 'Missing T4 copy key $key');
      final text = value! as String;
      for (final term in copyBlockedTerms) {
        if (text.contains(term)) {
          copyViolations.add('$key: $term');
        }
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
