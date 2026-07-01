import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T3 Today/Scene copy firewall', () {
    test(
      'targeted Home, Discover, and shell source does not leak old framing',
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
            for (final term in _blockedVisibleTerms) {
              if (!line.contains(term)) {
                continue;
              }
              if (_isAllowedAdapterLine(line, term)) {
                continue;
              }
              violations.add('$path:${index + 1}: $term');
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
        for (final term in _blockedVisibleTerms) {
          if (value.contains(term)) {
            violations.add('${entry.key}: $term');
          }
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

const _blockedVisibleTerms = ['练习', '课程', '学习进度', '完成任务', '短语', '1 of N'];

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
];

bool _isAllowedAdapterLine(String line, String term) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//') || trimmed.startsWith('///')) {
    return true;
  }
  return line.contains(".replaceAll('$term'");
}
