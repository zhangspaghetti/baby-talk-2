import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/care_entry/presentation/care_entry_providers.dart';
import 'package:mobile/features/care_entry/presentation/widgets/care_entry_entry_surface.dart';

class CareEntryOnboardingScreen extends ConsumerWidget {
  const CareEntryOnboardingScreen({
    super.key,
    this.onDeferred,
    this.onContinueCareTurn,
    this.onToday,
    this.onGarden,
  });

  final VoidCallback? onDeferred;
  final ValueChanged<OnboardingCareTurnHandoff>? onContinueCareTurn;
  final VoidCallback? onToday;
  final VoidCallback? onGarden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onboardingConversationControllerProvider);
    return CareEntryEntrySurface(
      controller: controller,
      audioControllerFactory: () => AudioplayersCareEntryAudioPlayer(
        guestAudioPlayer: ref.read(guestOnboardingAudioPlayerFactoryProvider)(),
      ),
      onRetry: () =>
          unawaited(controller.initialize(localTime: DateTime.now())),
      onDefer: () async {
        if (await controller.defer()) onDeferred?.call();
      },
      onExit: onDeferred,
      onContinueCareTurn: onContinueCareTurn,
      onToday: onToday,
      onGarden: onGarden,
    );
  }
}
