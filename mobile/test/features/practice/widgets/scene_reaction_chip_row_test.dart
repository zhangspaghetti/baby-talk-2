import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/widgets/scene_reaction_chip_row.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('feeding 场景显示「吃了一口」而不是「认真听了」', (tester) async {
    await tester.pumpWidget(_wrap(
      SceneReactionChipRow(
        phraseId: 'p1',
        sceneTag: 'feeding',
        enabled: true,
        onSelected: null,
      ),
    ));
    expect(find.text('吃了一口'), findsOneWidget);
    expect(find.text('认真听了'), findsNothing);
  });

  testWidgets('bedtime 场景显示「安静了」', (tester) async {
    await tester.pumpWidget(_wrap(
      SceneReactionChipRow(
        phraseId: 'p2',
        sceneTag: 'bedtime',
        enabled: true,
        onSelected: null,
      ),
    ));
    expect(find.text('安静了'), findsOneWidget);
  });

  testWidgets('默认场景显示「认真听了」', (tester) async {
    await tester.pumpWidget(_wrap(
      SceneReactionChipRow(
        phraseId: 'p3',
        sceneTag: null,
        enabled: true,
        onSelected: null,
      ),
    ));
    expect(find.text('认真听了'), findsOneWidget);
  });

  testWidgets('三个芯片全部渲染', (tester) async {
    await tester.pumpWidget(_wrap(
      SceneReactionChipRow(
        phraseId: 'p4',
        sceneTag: 'bath',
        enabled: true,
        onSelected: null,
      ),
    ));
    expect(find.text('有回应'), findsOneWidget);
    expect(find.text('配合了'), findsOneWidget);
    expect(find.text('没反应'), findsOneWidget);
  });

  testWidgets('点击芯片触发 onSelected', (tester) async {
    BabyReactionType? received;
    await tester.pumpWidget(_wrap(
      SceneReactionChipRow(
        phraseId: 'p5',
        sceneTag: 'diaper',
        enabled: true,
        onSelected: (type) => received = type,
      ),
    ));
    await tester.tap(find.text('有回应'));
    expect(received, BabyReactionType.engaged);
  });

  testWidgets('选中态显示 checkmark 并设置 semantics selected', (tester) async {
    await tester.pumpWidget(_wrap(
      SceneReactionChipRow(
        phraseId: 'p6',
        sceneTag: null,
        enabled: true,
        selectedType: BabyReactionType.calm,
        onSelected: null,
      ),
    ));
    // Checkmark icon present for selected chip
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // Semantics label with selected=true
    final node = tester.getSemantics(find.text('认真听了'));
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
  });
}
