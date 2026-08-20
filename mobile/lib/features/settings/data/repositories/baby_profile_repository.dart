import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';

typedef BabyProfileAccountSnapshotLoader =
    Future<AccountLocalSnapshot> Function();

class BabyProfileProjection {
  const BabyProfileProjection({
    required this.accountId,
    required this.babyProfileId,
    required this.babyName,
    required this.ageRange,
    required this.parentGoal,
    required this.onboardingState,
    required this.onboardingCompletedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String accountId;
  final String babyProfileId;
  final String? babyName;
  final String ageRange;
  final String? parentGoal;
  final String onboardingState;
  final DateTime? onboardingCompletedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Account-scoped profile gateway. It deliberately owns no local cache: the
/// settings repository is only the offline projection of the last confirmed
/// account profile.
class BabyProfileRepository {
  BabyProfileRepository({
    required AccountApiService apiService,
    required AuthenticatedApiClient authenticatedApiClient,
    required BabyProfileAccountSnapshotLoader accountSnapshotLoader,
    required PersistRefreshedSession persistRefreshedSession,
  }) : _apiService = apiService,
       _authenticatedApiClient = authenticatedApiClient,
       _accountSnapshotLoader = accountSnapshotLoader,
       _persistRefreshedSession = persistRefreshedSession;

  final AccountApiService _apiService;
  final AuthenticatedApiClient _authenticatedApiClient;
  final BabyProfileAccountSnapshotLoader _accountSnapshotLoader;
  final PersistRefreshedSession _persistRefreshedSession;

  Future<String?> currentAccountId() async {
    final session = await _eligibleSession();
    return session?.accountId;
  }

  Future<BabyProfileProjection?> load() async {
    final session = await _eligibleSession();
    if (session == null) {
      return null;
    }
    try {
      final result = await _authenticatedApiClient.execute(
        session: session,
        send: (accessToken) =>
            _apiService.getBabyProfile(accessToken: accessToken),
        persistRefreshedSession: _persistRefreshedSession,
      );
      return _projection(session.accountId, result.value);
    } on AccountApiException catch (error) {
      if (error.statusCode == 404 &&
          error.code == 'onboarding_profile_not_found') {
        return null;
      }
      rethrow;
    }
  }

  Future<BabyProfileProjection> save({
    required String ageRange,
    required String onboardingState,
    String? babyName,
    String? parentGoal,
    int? expectedVersion,
    DateTime? completedAt,
    String? clientTraceId,
  }) async {
    final session = await _eligibleSession();
    if (session == null) {
      throw const AccountApiException(
        kind: AccountApiFailureKind.http,
        statusCode: 401,
        code: 'invalid_session',
        message: '当前账号会话不可用。',
      );
    }
    final result = await _authenticatedApiClient.execute(
      session: session,
      send: (accessToken) => _apiService.putBabyProfile(
        accessToken: accessToken,
        expectedVersion: expectedVersion,
        babyName: babyName,
        ageRange: ageRange,
        parentGoal: parentGoal,
        onboardingState: onboardingState,
        completedAt: completedAt,
        clientTraceId: clientTraceId,
      ),
      persistRefreshedSession: _persistRefreshedSession,
    );
    return _projection(result.session.accountId, result.value);
  }

  Future<AccountSession?> _eligibleSession() async {
    final snapshot = await _accountSnapshotLoader();
    final session = snapshot.session;
    if (session == null ||
        !session.hasJwtTokens ||
        snapshot.consentState == AccountConsentState.localOnly ||
        snapshot.consentState == AccountConsentState.signedOut ||
        snapshot.consentState == AccountConsentState.revoked ||
        snapshot.consentState == AccountConsentState.deleted) {
      return null;
    }
    return session;
  }

  BabyProfileProjection _projection(
    String accountId,
    AccountBabyProfileResponse response,
  ) {
    return BabyProfileProjection(
      accountId: accountId,
      babyProfileId: response.babyProfileId,
      babyName: response.babyName,
      ageRange: response.ageRange,
      parentGoal: response.parentGoal,
      onboardingState: response.onboardingState,
      onboardingCompletedAt: response.onboardingCompletedAt,
      version: response.version,
      createdAt: response.createdAt,
      updatedAt: response.updatedAt,
    );
  }
}
