import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';

class AccountRepository {
  AccountRepository({
    required AccountLocalStore localStore,
    required PracticeRepository practiceRepository,
  }) : _localStore = localStore,
       _practiceRepository = practiceRepository;

  final AccountLocalStore _localStore;
  final PracticeRepository _practiceRepository;

  Future<AccountLocalSnapshot> loadSnapshot() async {
    final snapshot = await _readSnapshotSafely();
    final syncSummary = await _readSyncSummarySafely();
    return _mergeSyncSummary(snapshot, syncSummary);
  }

  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    final now = DateTime.now().toUtc();
    final syncSummary = await _readSyncSummarySafely();
    final maskedPhoneNumber = _maskPhoneNumber(phoneNumber);
    final snapshot = AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: AccountSession(
        accountId: 'placeholder-account-${now.millisecondsSinceEpoch}',
        sessionId: 'placeholder-session-${now.microsecondsSinceEpoch}',
        maskedPhoneNumber: maskedPhoneNumber,
        createdAt: now,
      ),
      challenge: AccountChallengePlaceholder(
        maskedPhoneNumber: maskedPhoneNumber,
        codeLength: verificationCode.length,
        issuedAt: now,
      ),
      pendingSyncCount: syncSummary.pendingCount,
      syncedCount: syncSummary.syncedCount,
      failedCount: syncSummary.failedCount,
      lastSyncPhase: syncSummary.pendingCount > 0
          ? 'pending_local_upload'
          : 'awaiting_first_sync',
      lastVisibleError: syncSummary.failedCount > 0
          ? '仍有 ${syncSummary.failedCount} 条本地记录等待后续重试。'
          : null,
      lastSyncAt: syncSummary.lastEventAt,
    );
    await _localStore.write(snapshot);
    return snapshot;
  }

  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    final syncSummary = await _readSyncSummarySafely();
    final snapshot = AccountLocalSnapshot(
      consentState: revertToLocalOnly
          ? AccountConsentState.localOnly
          : AccountConsentState.signedOut,
      pendingSyncCount: syncSummary.pendingCount,
      syncedCount: syncSummary.syncedCount,
      failedCount: syncSummary.failedCount,
      lastSyncPhase: revertToLocalOnly ? 'local_only' : 'signed_out',
      lastVisibleError: syncSummary.failedCount > 0
          ? '仍有 ${syncSummary.failedCount} 条本地记录等待后续重试。'
          : null,
      lastSyncAt: syncSummary.lastEventAt,
    );
    await _localStore.write(snapshot);
    return snapshot;
  }

  Future<AccountLocalSnapshot> _readSnapshotSafely() async {
    try {
      return await _localStore.read();
    } on FormatException {
      return AccountLocalSnapshot.signedOut;
    }
  }

  Future<PracticeSyncSummary> _readSyncSummarySafely() async {
    try {
      return await _practiceRepository.getSyncSummary();
    } catch (_) {
      return const PracticeSyncSummary();
    }
  }

  AccountLocalSnapshot _mergeSyncSummary(
    AccountLocalSnapshot snapshot,
    PracticeSyncSummary syncSummary,
  ) {
    final phase = snapshot.isSignedIn
        ? (syncSummary.pendingCount > 0
              ? 'pending_local_upload'
              : 'awaiting_first_sync')
        : snapshot.consentState == AccountConsentState.localOnly
        ? 'local_only'
        : 'signed_out';
    return snapshot.copyWith(
      pendingSyncCount: syncSummary.pendingCount,
      syncedCount: syncSummary.syncedCount,
      failedCount: syncSummary.failedCount,
      lastSyncPhase: phase,
      clearLastVisibleError: syncSummary.failedCount == 0,
      lastVisibleError: syncSummary.failedCount > 0
          ? '仍有 ${syncSummary.failedCount} 条本地记录等待后续重试。'
          : null,
      clearLastSyncAt: syncSummary.lastEventAt == null,
      lastSyncAt: syncSummary.lastEventAt,
    );
  }

  String _maskPhoneNumber(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      return '***';
    }
    final prefix = digits.substring(0, 3);
    final suffix = digits.substring(digits.length - 4);
    return '$prefix****$suffix';
  }
}
