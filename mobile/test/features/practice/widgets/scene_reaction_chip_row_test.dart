import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/widgets/scene_reaction_chip_row.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders the five canonical reaction chips', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SceneReactionChipRow(
          phraseId: 'p1',
          sceneTag: 'feeding',
          enabled: true,
          onSelected: null,
        ),
      ),
    );

    expect(find.text('配合'), findsOneWidget);
    expect(find.text('犹豫'), findsOneWidget);
    expect(find.text('不想'), findsOneWidget);
    expect(find.text('没反应'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
  });

  testWidgets('uses canonical wire values in chip keys', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SceneReactionChipRow(
          phraseId: 'p2',
          sceneTag: 'bath',
          enabled: true,
          onSelected: null,
        ),
      ),
    );

    expect(find.byKey(const Key('reaction-p2-cooperating')), findsOneWidget);
    expect(find.byKey(const Key('reaction-p2-hesitant')), findsOneWidget);
    expect(find.byKey(const Key('reaction-p2-resisting')), findsOneWidget);
    expect(find.byKey(const Key('reaction-p2-no_response')), findsOneWidget);
    expect(find.byKey(const Key('reaction-p2-other')), findsOneWidget);
  });

  testWidgets('点击芯片触发 onSelected', (tester) async {
    BabyReactionType? received;
    await tester.pumpWidget(
      _wrap(
        SceneReactionChipRow(
          phraseId: 'p3',
          sceneTag: 'diaper',
          enabled: true,
          onSelected: (type) => received = type,
        ),
      ),
    );

    await tester.tap(find.text('配合'));
    expect(received, BabyReactionType.cooperating);
  });

  testWidgets('选中态显示 checkmark 并设置 semantics selected', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SceneReactionChipRow(
          phraseId: 'p4',
          sceneTag: null,
          enabled: true,
          selectedType: BabyReactionType.cooperating,
          onSelected: null,
        ),
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final node = tester.getSemantics(find.text('配合'));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
  });
}
