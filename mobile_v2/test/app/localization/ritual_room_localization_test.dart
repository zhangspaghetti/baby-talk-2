import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/baby_talk_app.dart';
import 'package:mobile_v2/app/localization/generated/app_localizations.dart';

void main() {
  test('generated Ritual Room chrome exposes the exact Chinese copy', () async {
    final copy = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(copy.listen, '听一下');
    expect(copy.pause, '暂停');
    expect(copy.playSentenceSemantics, '播放这句话');
    expect(copy.pauseSentenceSemantics, '暂停播放');
    expect(copy.loadingAudioSemantics, '正在加载语音');
    expect(copy.audioUnavailable, '暂时听不了，你也可以直接照着说。');
    expect(copy.contextEntry, '想让这句话更贴近一点吗？');
    expect(copy.contextEntryHint, '轻触告诉我');
    expect(copy.contextPrompt, '宝宝现在怎么了？');
    expect(copy.contextPromptHint, '选一个最接近的就好');
    expect(copy.collapseContext, '收起');
    expect(copy.retry, '再试一次');
    expect(copy.adjustingUtterance, '正在让这句话更贴近一点…');
    expect(copy.recoverableFailure, '这次没有换好，刚才那句话还可以继续用。');
    expect(copy.unknownOutcome, '刚才的调整还没有确认。');
    expect(copy.loadingSentence, '正在准备这句话…');
    expect(copy.loadFailure, '这个小声音暂时没准备好。稍后再打开一次。');
  });

  test(
    'generated Ritual Room semantics interpolate their placeholders',
    () async {
      final copy = await AppLocalizations.delegate.load(const Locale('zh'));

      expect(copy.timingSemantics('出门前'), '说这句话的时机：出门前');
      expect(
        copy.adjustedSentenceSemantics('Let’s put your shoes on.'),
        '说法已调整：Let’s put your shoes on.',
      );
    },
  );

  testWidgets('BabyTalkApp wires generated localization into MaterialApp', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BabyTalkApp()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.localizationsDelegates, AppLocalizations.localizationsDelegates);
    expect(app.supportedLocales, AppLocalizations.supportedLocales);
    expect(app.supportedLocales, contains(const Locale('zh')));
  });
}
