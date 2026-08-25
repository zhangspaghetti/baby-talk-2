import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_input_screen.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_route_args.dart';

void main() {
  testWidgets('custom-scene input exposes labeled controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: const CustomSceneInputScreen(
          routeArgs: CustomSceneRouteArgs(
            entrySource: CustomSceneEntrySource.scene,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel('此刻发生了什么？'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '隐私说明：请不要填写姓名、电话、地址或其他私密信息。',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('帮我准备一句'), findsOneWidget);
      expect(find.bySemanticsLabel('查看已有场景'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
