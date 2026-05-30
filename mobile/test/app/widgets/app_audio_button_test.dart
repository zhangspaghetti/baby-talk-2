import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_audio_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.build(),
    home: Scaffold(body: child),
  );

  testWidgets('AppAudioButton 渲染语义/图标/最小触达，buttonKey 落在可点区', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      host(
        AppAudioButton(
          buttonKey: const Key('play-x1'),
          semanticsLabel: '播放发音',
          icon: Icons.volume_up_outlined,
          onTap: () => tapped++,
        ),
      ),
    );

    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(find.text('播放中'), findsNothing);

    final box = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(AppAudioButton),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(box.constraints.minHeight, AppLayoutConstants.minTouchTarget);

    await tester.tap(find.byKey(const Key('play-x1')));
    expect(tapped, 1);
  });

  testWidgets('AppAudioButton 播放中显示「播放中」文案', (tester) async {
    await tester.pumpWidget(
      host(
        const AppAudioButton(
          semanticsLabel: '播放发音',
          icon: Icons.graphic_eq_rounded,
          isPlaying: true,
        ),
      ),
    );

    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(find.text('播放中'), findsOneWidget);
  });

  testWidgets('AppAudioButton onTap 为 null 时不可点', (tester) async {
    await tester.pumpWidget(
      host(
        const AppAudioButton(
          buttonKey: Key('disabled'),
          semanticsLabel: '播放发音',
          icon: Icons.volume_up_outlined,
          onTap: null,
        ),
      ),
    );

    final inkWell = tester.widget<InkWell>(find.byKey(const Key('disabled')));
    expect(inkWell.onTap, isNull);
  });
}
