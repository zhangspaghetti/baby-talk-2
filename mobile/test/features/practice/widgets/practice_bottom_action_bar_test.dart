import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/widgets/practice_bottom_action_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('ready+idle 状态显示「说完了」「换一句」「结束」', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PracticeBottomActionBar(
          phase: PhraseInteractionPhase.ready,
          nextLoadStatus: NextPhraseLoadStatus.idle,
          onSave: () {},
          onSkipPhrase: () {},
          onEnd: () {},
          onSkipReaction: () {},
          onRetryNextPhrase: () {},
        ),
      ),
    );
    expect(find.text('说完了'), findsOneWidget);
    expect(find.text('换一句'), findsOneWidget);
    expect(find.text('结束'), findsOneWidget);
  });

  testWidgets('saved 状态显示「跳过，下一句」', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PracticeBottomActionBar(
          phase: PhraseInteractionPhase.saved,
          nextLoadStatus: NextPhraseLoadStatus.idle,
          onSave: () {},
          onSkipPhrase: () {},
          onEnd: () {},
          onSkipReaction: () {},
          onRetryNextPhrase: () {},
        ),
      ),
    );
    expect(find.text('跳过，下一句'), findsOneWidget);
  });

  testWidgets('loading 状态显示 spinner 和「下一句准备中」且按钮禁用', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PracticeBottomActionBar(
          phase: PhraseInteractionPhase.ready,
          nextLoadStatus: NextPhraseLoadStatus.loading,
          onSave: () {},
          onSkipPhrase: () {},
          onEnd: () {},
          onSkipReaction: () {},
          onRetryNextPhrase: () {},
        ),
      ),
    );
    expect(find.text('下一句准备中'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The FilledButton should be disabled (onPressed == null)
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('error 状态显示「换一句没准备好」和「重试」', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PracticeBottomActionBar(
          phase: PhraseInteractionPhase.ready,
          nextLoadStatus: NextPhraseLoadStatus.error,
          onSave: () {},
          onSkipPhrase: () {},
          onEnd: () {},
          onSkipReaction: () {},
          onRetryNextPhrase: () {},
        ),
      ),
    );
    expect(find.textContaining('换一句没准备好'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('点击「说完了」触发 onSave', (tester) async {
    bool called = false;
    await tester.pumpWidget(
      _wrap(
        PracticeBottomActionBar(
          phase: PhraseInteractionPhase.ready,
          nextLoadStatus: NextPhraseLoadStatus.idle,
          onSave: () => called = true,
          onSkipPhrase: () {},
          onEnd: () {},
          onSkipReaction: () {},
          onRetryNextPhrase: () {},
        ),
      ),
    );
    await tester.tap(find.text('说完了'));
    expect(called, isTrue);
  });
}
