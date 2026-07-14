import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T3 Today/Scene copy firewall', () {
    test(
      'targeted Home, Discover, and shell visible copy does not leak old framing',
      () {
        const sourcePaths = [
          'lib/features/practice/presentation/screens/home_screen.dart',
          'lib/features/shell/presentation/app_shell_screen.dart',
          'lib/features/shell/presentation/screens/discover_screen.dart',
        ];

        final violations = <String>[];
        for (final path in sourcePaths) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: '$path should exist');
          final lines = file.readAsLinesSync();
          for (var index = 0; index < lines.length; index += 1) {
            final line = lines[index];
            for (final visibleText in _visibleSourceTextFromLine(line)) {
              for (final term in _blockedTermsIn(visibleText)) {
                violations.add(
                  '$path:${index + 1}: "$visibleText" contains $term',
                );
              }
            }
          }
        }

        expect(violations, isEmpty);
      },
    );

    test('targeted l10n keys use Today/Scene wording', () {
      final raw = File('lib/l10n/app_zh.arb').readAsStringSync();
      final messages = jsonDecode(raw) as Map<String, dynamic>;
      final targetedValues = {
        for (final key in _targetedL10nKeys) key: messages[key] as String?,
      };

      expect(targetedValues['shellHome'], '今天');
      expect(targetedValues['shellDiscover'], '场景');
      expect(targetedValues['shellHomeName'], '{name} 的今天');
      expect(targetedValues['discoverPracticeThis'], '现在说一句');
      expect(targetedValues['discoverTrustSubtitle'], '照护场景');

      final missingKeys = targetedValues.entries
          .where((entry) => entry.value == null)
          .map((entry) => entry.key)
          .toList();
      expect(missingKeys, isEmpty);

      final violations = <String>[];
      for (final entry in targetedValues.entries) {
        final value = entry.value;
        if (value == null) {
          continue;
        }
        for (final term in _blockedTermsIn(value)) {
          violations.add('${entry.key}: "$value" contains $term');
        }
      }

      expect(violations, isEmpty);
    });

    test('does not introduce T4 or reaction/storage vocabulary', () {
      const sourcePaths = [
        'lib/features/practice/presentation/screens/home_screen.dart',
        'lib/features/shell/presentation/app_shell_screen.dart',
        'lib/features/shell/presentation/screens/discover_screen.dart',
      ];
      const blockedScopeTerms = [
        'class TodayScreen',
        'class SceneScreen',
        'CareReactionType',
        '@Collection',
      ];

      final violations = <String>[];
      for (final path in sourcePaths) {
        final source = File(path).readAsStringSync();
        for (final term in blockedScopeTerms) {
          if (source.contains(term)) {
            violations.add('$path: $term');
          }
        }
      }

      expect(violations, isEmpty);
    });
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

const _targetedL10nKeys = [
  'shellHome',
  'shellDiscover',
  'shellHomeName',
  'shellDiscoverTooltip',
  'shellPractice',
  'shellPracticeName',
  'discoverSearchHint',
  'discoverLoadingCatalog',
  'discoverLoadingNote',
  'discoverEmptyNote',
  'discoverInvalidCardError',
  'discoverPracticeThis',
  'discoverSearchEmpty',
  'discoverSceneEmpty',
  'discoverPracticePhraseHint',
  'discoverTrustSubtitle',
  'homeTodaySceneSemantics',
  'homeContinuityUnavailable',
  'homeContinuationRecent',
  'homeContinuationNextIncomplete',
  'homeContinuationStarter',
  'homeContinuationSafeFallback',
  'homeStartPractice',
  'homeContinuePractice',
  'homeNextAlternative',
];

Iterable<String> _visibleSourceTextFromLine(String line) sync* {
  if (_isCommentLine(line)) {
    return;
  }
  if (line.contains('.replaceAll(')) {
    final literals = _singleQuotedLiterals(line).toList(growable: false);
    if (literals.length >= 2) {
      yield literals[1];
    }
    return;
  }

  if (!_looksLikeVisibleWidgetLine(line)) {
    return;
  }
  yield* _singleQuotedLiterals(line);
  yield* _doubleQuotedLiterals(line);
}

bool _isCommentLine(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//') || trimmed.startsWith('///');
}

bool _looksLikeVisibleWidgetLine(String line) {
  return line.contains('Text(') ||
      line.contains('SnackBar(') ||
      line.contains('Semantics(') ||
      line.contains('label:') ||
      line.contains('tooltip:') ||
      line.contains('hintText:') ||
      line.contains('message:') ||
      line.contains('title:');
}

Iterable<String> _singleQuotedLiterals(String line) sync* {
  for (final match in RegExp(
    "'([^'\\\\]*(?:\\\\.[^'\\\\]*)*)'",
  ).allMatches(line)) {
    yield match.group(1)!;
  }
}

Iterable<String> _doubleQuotedLiterals(String line) sync* {
  for (final match in RegExp(
    '"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"',
  ).allMatches(line)) {
    yield match.group(1)!;
  }
}

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
