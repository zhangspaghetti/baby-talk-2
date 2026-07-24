import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/account_entry_post_sign_in.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';

void main() {
  group('resolveAccountEntryPostSignInAction', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('account_entry_action_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns signed-in result action without consuming pending intent', () async {
      final coordinator = AuthContinuationCoordinator(
        store: AuthContinuationStore(directoryResolver: () async => tempDir),
        clock: () => DateTime.utc(2026, 7, 23, 12),
        correlationIdGenerator: () => 'account_entry_post_sign_in',
      );
      await coordinator.beginSaveOnboardingMemory();

      expect(
        await resolveAccountEntryPostSignInAction(coordinator),
        AccountEntryPostSignInAction.returnSignedInResult,
      );
      expect(await coordinator.readPending(), isNotNull);
    });

    test('keeps account entry open when no continuation is pending', () async {
      final coordinator = AuthContinuationCoordinator(
        store: AuthContinuationStore(directoryResolver: () async => tempDir),
        clock: () => DateTime.utc(2026, 7, 23, 12),
      );

      expect(
        await resolveAccountEntryPostSignInAction(coordinator),
        AccountEntryPostSignInAction.showSuccessToast,
      );
    });
  });
}
