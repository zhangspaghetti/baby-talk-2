import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/care_entry/presentation/care_entry_providers.dart';
import 'package:mobile/features/care_entry/presentation/widgets/care_entry_entry_surface.dart';

class CareEntryOnboardingScreen extends ConsumerWidget {
  const CareEntryOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onboardingConversationControllerProvider);
    return CareEntryEntrySurface(
      controller: controller,
      onRetry: () =>
          unawaited(controller.initialize(localTime: DateTime.now())),
    );
  }
}
