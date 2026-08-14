import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/care_entry/data/bundled_care_entry_registry.dart';
import 'package:mobile/features/care_entry/data/file_onboarding_conversation_repository.dart';
import 'package:mobile/features/care_entry/data/guest_onboarding_audio_api.dart';
import 'package:mobile/features/care_entry/data/guest_onboarding_conversation_api.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:mobile/features/care_entry/presentation/onboarding_conversation_controller.dart';

final careEntryRegistryProvider = Provider<CareEntryRegistry>((ref) {
  return BundledCareEntryRegistry(bundle: rootBundle);
});

final onboardingConversationRepositoryProvider =
    Provider<OnboardingConversationRepository>((ref) {
      return FileOnboardingConversationRepository();
    });

final guestOnboardingConversationGatewayProvider =
    Provider<GuestOnboardingConversationGateway>((ref) {
      return GuestOnboardingConversationApi(
        audioCapabilities: ref.watch(guestAudioCapabilityVaultProvider),
      );
    });

final guestAudioCapabilityVaultProvider = Provider<GuestAudioCapabilityVault>((
  ref,
) {
  final vault = GuestAudioCapabilityVault();
  ref.onDispose(vault.clear);
  return vault;
});

final guestOnboardingAudioPlayerFactoryProvider =
    Provider<GuestOnboardingAudioPlayer Function()>((ref) {
      final capabilities = ref.watch(guestAudioCapabilityVaultProvider);
      return () => GuestOnboardingAudioApi(capabilities: capabilities);
    });

final onboardingInstallationIdLoaderProvider =
    Provider<OnboardingInstallationIdLoader?>((ref) => null);

final onboardingConversationControllerProvider =
    ChangeNotifierProvider.autoDispose<OnboardingConversationController>(
      (ref) {
        final controller = OnboardingConversationController(
          registry: ref.watch(careEntryRegistryProvider),
          repository: ref.watch(onboardingConversationRepositoryProvider),
          scheduler: const TimerOnboardingDelayScheduler(),
          clock: DateTime.now,
          idGenerator: _newOnboardingId,
          conversationGateway: ref.watch(
            guestOnboardingConversationGatewayProvider,
          ),
          installationIdLoader: ref.watch(
            onboardingInstallationIdLoaderProvider,
          ),
        );
        unawaited(controller.initialize(localTime: DateTime.now()));
        return controller;
      },
      dependencies: [
        onboardingConversationRepositoryProvider,
        guestOnboardingConversationGatewayProvider,
        onboardingInstallationIdLoaderProvider,
      ],
    );

String _newOnboardingId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
