import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/ritual_room_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewports = <Size>[
    Size(427, 952),
    Size(390, 844),
  ];

  for (final viewport in viewports) {
    final suffix = '${viewport.width.toInt()}x${viewport.height.toInt()}';

    testWidgets('ready collapsed $suffix', (tester) async {
      await pumpRitualRoomGolden(
        tester,
        viewport: viewport,
        state: ritualRoomReadyState(),
      );

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/ready_$suffix.png'),
      );
    });

    testWidgets('dock expanded $suffix', (tester) async {
      await pumpRitualRoomGolden(
        tester,
        viewport: viewport,
        state: ritualRoomReadyState(),
        expandDock: true,
      );

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/dock_expanded_$suffix.png'),
      );
    });

    testWidgets('submitting $suffix', (tester) async {
      await pumpRitualRoomGolden(
        tester,
        viewport: viewport,
        state: ritualRoomSubmittingState(),
        expandDock: true,
      );

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/submitting_$suffix.png'),
      );
    });

    testWidgets('revised $suffix', (tester) async {
      await pumpRitualRoomGolden(
        tester,
        viewport: viewport,
        state: ritualRoomRevisedState(),
        expandDock: true,
      );

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/revised_$suffix.png'),
      );
    });

    testWidgets('recoverable failure $suffix', (tester) async {
      await pumpRitualRoomGolden(
        tester,
        viewport: viewport,
        state: ritualRoomRecoverableFailureState(),
        expandDock: true,
      );

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/recoverable_failure_$suffix.png'),
      );
    });

    testWidgets('unknown outcome $suffix', (tester) async {
      await pumpRitualRoomGolden(
        tester,
        viewport: viewport,
        state: ritualRoomUnknownOutcomeState(),
        expandDock: true,
      );

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/unknown_outcome_$suffix.png'),
      );
    });

    testWidgets('audio unavailable $suffix', (tester) async {
      await pumpRitualRoomGolden(
        tester,
        viewport: viewport,
        state: ritualRoomAudioUnavailableState(),
      );

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/audio_unavailable_$suffix.png'),
      );
    });

    testWidgets('text scale 1.3 $suffix', (tester) async {
      await pumpRitualRoomGolden(
        tester,
        viewport: viewport,
        state: ritualRoomReadyState(),
        textScale: 1.3,
      );

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/text_scale_1_3_$suffix.png'),
      );
    });

    testWidgets('reduced motion final frame $suffix', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ritualRoomHarness(
          viewport: viewport,
          state: ritualRoomReadyState(),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        ritualRoomHarness(
          viewport: viewport,
          state: ritualRoomRevisedState(),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('ritual-room-root')),
        matchesGoldenFile('../../../goldens/ritual_room/reduced_motion_final_frame_$suffix.png'),
      );
    });
  }
}
