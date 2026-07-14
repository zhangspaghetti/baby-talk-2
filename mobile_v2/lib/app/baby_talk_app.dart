import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/ritual_room/presentation/screens/ritual_room_screen.dart';
import 'localization/generated/app_localizations.dart';
import 'providers/ritual_room_capability_provider.dart';
import 'providers/ritual_room_session_provider.dart';
import 'theme/baby_talk_theme.dart';

final class BabyTalkApp extends ConsumerStatefulWidget {
  const BabyTalkApp({super.key});

  @override
  ConsumerState<BabyTalkApp> createState() => _BabyTalkAppState();
}

final class _BabyTalkAppState extends ConsumerState<BabyTalkApp> {
  static const _ritualRoomId = 'shoes_on_room_v1';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () =>
          ref.read(ritualRoomSessionProvider.notifier).openRoom(_ritualRoomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ritualRoomSessionProvider);
    final capabilityMask = ref.watch(interactionCapabilityMaskProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Baby Talk',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: BabyTalkTheme.light,
      home: RitualRoomScreen(
        state: state,
        capabilityMask: capabilityMask,
        onReactionSelected: (selected) => ref
            .read(ritualRoomSessionProvider.notifier)
            .submitReaction(selected),
        onRetry: () => ref
            .read(ritualRoomSessionProvider.notifier)
            .reloadRoom(_ritualRoomId),
        onRetryPendingEvent: () =>
            ref.read(ritualRoomSessionProvider.notifier).retryPendingEvent(),
        onListen: () {},
        listenAdapterInjected: false,
      ),
    );
  }
}
