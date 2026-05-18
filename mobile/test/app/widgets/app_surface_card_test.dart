import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';

void main() {
  testWidgets('REFACTOR-015 AppSurfaceCard preserves surface defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: const Scaffold(
          body: AppSurfaceCard(
            key: Key('surface-card-under-test'),
            child: Text('Shared surface'),
          ),
        ),
      ),
    );

    final card = find.byKey(const Key('surface-card-under-test'));
    final container = tester.widget<Container>(
      find.descendant(of: card, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    final borderRadius = decoration.borderRadius as BorderRadius;
    final colors = BabyTalkColors.light();

    expect(
      container.constraints,
      const BoxConstraints.tightFor(width: double.infinity),
    );
    expect(
      container.padding,
      const EdgeInsets.all(AppLayoutConstants.spacingLg),
    );
    expect(decoration.color, colors.bgSurface);
    expect(borderRadius.topLeft.x, AppLayoutConstants.largeRadius);
    expect(decoration.border, Border.all(color: colors.outlineSoft));
    expect(decoration.boxShadow, colors.warmShadowSm);
    expect(find.text('Shared surface'), findsOneWidget);
  });
}
