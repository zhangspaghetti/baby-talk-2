import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/domain/models/auth_continuation.dart';

class AuthContinuationCoordinator {
  AuthContinuationCoordinator({
    required AuthContinuationStore store,
    DateTime Function()? clock,
    String Function()? correlationIdGenerator,
    this.ttl = const Duration(minutes: 15),
  }) : _store = store,
       _clock = clock ?? DateTime.now,
       _correlationIdGenerator = correlationIdGenerator ?? _defaultId;

  final AuthContinuationStore _store;
  final DateTime Function() _clock;
  final String Function() _correlationIdGenerator;
  final Duration ttl;

  Future<AuthContinuation> beginSaveOnboardingMemory() async {
    final createdAt = _clock().toUtc();
    final continuation = AuthContinuation(
      schemaVersion: AuthContinuation.currentSchemaVersion,
      intent: AuthContinuationIntent.saveOnboardingMemory,
      correlationId: _correlationIdGenerator(),
      createdAt: createdAt,
      expiresAt: createdAt.add(ttl),
    );
    await _store.write(continuation);
    return continuation;
  }

  Future<AuthContinuation?> readPending() {
    return _store.read(now: _clock().toUtc());
  }

  Future<AuthContinuationReadResult> readPendingResult() {
    return _store.readResult(now: _clock().toUtc());
  }

  Future<void> clear() => _store.deleteIfExists();

  static String _defaultId() {
    return 'auth_onboarding_${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }
}
