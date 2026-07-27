import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/domain/models/auth_continuation.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';

void main() {
  group('AuthContinuationStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('auth_continuation_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'save-onboarding continuation round-trips and expires fail-closed',
      () async {
        final store = AuthContinuationStore(
          directoryResolver: () async => tempDir,
        );
        final pending = AuthContinuation(
          schemaVersion: 1,
          intent: AuthContinuationIntent.saveOnboardingMemory,
          correlationId: 'auth_onboarding_123',
          createdAt: DateTime.utc(2026, 7, 23, 12),
          expiresAt: DateTime.utc(2026, 7, 23, 12, 15),
        );

        await store.write(pending);

        final available = await store.readResult(
          now: DateTime.utc(2026, 7, 23, 12, 5),
        );
        expect(available.status, AuthContinuationReadStatus.available);
        expect(available.continuation, pending);

        final expired = await store.readResult(
          now: DateTime.utc(2026, 7, 23, 12, 16),
        );
        expect(expired.status, AuthContinuationReadStatus.expired);
        expect(
          await store.read(now: DateTime.utc(2026, 7, 23, 12, 16)),
          isNull,
        );
        expect(
          File('${tempDir.path}/auth_continuation.json').existsSync(),
          isFalse,
        );
      },
    );

    test('corrupt continuation fails closed and is deleted', () async {
      final store = AuthContinuationStore(
        directoryResolver: () async => tempDir,
      );
      final file = File('${tempDir.path}/auth_continuation.json');
      await file.writeAsString('{"intent":"unknown"}');

      final result = await store.readResult(now: DateTime.utc(2026, 7, 23, 12));

      expect(result.status, AuthContinuationReadStatus.corrupt);
      expect(result.continuation, isNull);
      expect(file.existsSync(), isFalse);
    });

    test(
      'I/O read failure remains retryable and preserves continuation file',
      () async {
        final file = File('${tempDir.path}/auth_continuation.json');
        await file.writeAsString('retained after resolver failure');
        final store = AuthContinuationStore(
          directoryResolver: () async {
            throw const FileSystemException('application support unavailable');
          },
        );

        final result = await store.readResult(
          now: DateTime.utc(2026, 7, 23, 12),
        );

        expect(result.status, AuthContinuationReadStatus.ioFailure);
        expect(file.existsSync(), isTrue);
      },
    );

    test(
      'concurrent write and delete serialize their temporary file',
      () async {
        final store = AuthContinuationStore(
          directoryResolver: () async => tempDir,
        );
        final continuation = AuthContinuation(
          schemaVersion: 1,
          intent: AuthContinuationIntent.saveOnboardingMemory,
          correlationId: 'auth_onboarding_mutex',
          createdAt: DateTime.utc(2026, 7, 23, 12),
          expiresAt: DateTime.utc(2026, 7, 23, 12, 15),
        );

        await Future.wait(<Future<void>>[
          store.write(continuation),
          store.deleteIfExists(),
        ]);

        expect(
          File('${tempDir.path}/auth_continuation.json.tmp').existsSync(),
          isFalse,
        );
        expect(await store.read(now: DateTime.utc(2026, 7, 23, 12)), isNull);
      },
    );

    test(
      'coordinator refreshes pending onboarding intent and clears it',
      () async {
        final store = AuthContinuationStore(
          directoryResolver: () async => tempDir,
        );
        final coordinator = AuthContinuationCoordinator(
          store: store,
          clock: () => DateTime.utc(2026, 7, 23, 12),
          correlationIdGenerator: () => 'auth_onboarding_456',
        );

        final pending = await coordinator.beginSaveOnboardingMemory();

        expect(pending.intent, AuthContinuationIntent.saveOnboardingMemory);
        expect(pending.correlationId, 'auth_onboarding_456');
        expect(pending.expiresAt, DateTime.utc(2026, 7, 23, 12, 15));
        expect(await coordinator.readPending(), pending);
        await coordinator.clear();
        expect(await coordinator.readPending(), isNull);
        expect(
          (await store.readResult(now: DateTime.utc(2026, 7, 23, 12))).status,
          AuthContinuationReadStatus.notFound,
        );
      },
    );
  });
}
