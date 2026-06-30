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
}
