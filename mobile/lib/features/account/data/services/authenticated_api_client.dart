import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';

enum AuthenticatedApiClientFailureKind {
  missingCredentials,
  refreshTimeout,
  refreshNetwork,
  refreshMalformed,
  refreshFailed,
  sessionExpired,
  persistenceFailure,
}

class AuthenticatedApiClientException implements Exception {
  const AuthenticatedApiClientException({
    required this.kind,
    required this.phaseSuffix,
    required this.visibleMessage,
    this.correlationId,
  });

  const AuthenticatedApiClientException.missingCredentials()
    : this(
        kind: AuthenticatedApiClientFailureKind.missingCredentials,
        phaseSuffix: 'session_expired',
        visibleMessage: '登录已过期，请重新登录后再试。',
      );

  const AuthenticatedApiClientException.persistenceFailure()
    : this(
        kind: AuthenticatedApiClientFailureKind.persistenceFailure,
        phaseSuffix: 'session_persist_failed',
        visibleMessage: '登录状态保存失败，请重新登录后再试。',
      );

  final AuthenticatedApiClientFailureKind kind;
  final String phaseSuffix;
  final String visibleMessage;
  final String? correlationId;

  @override
  String toString() {
    return 'AuthenticatedApiClientException(kind: $kind, phaseSuffix: $phaseSuffix, visibleMessage: $visibleMessage)';
  }
}

class AuthenticatedApiCallResult<T> {
  const AuthenticatedApiCallResult({
    required this.value,
    required this.session,
  });

  final T value;
  final AccountSession session;
}

typedef PersistRefreshedSession =
    Future<AccountSession> Function(AccountSession refreshedSession);

class AuthenticatedApiClient {
  AuthenticatedApiClient({required AccountApiService apiService})
    : _apiService = apiService;

  final AccountApiService _apiService;

  Future<AccountSession>? _refreshFuture;
  String? _refreshTokenInFlight;

  Future<AuthenticatedApiCallResult<T>> execute<T>({
    required AccountSession session,
    required Future<T> Function(String accessToken) send,
    required PersistRefreshedSession persistRefreshedSession,
  }) async {
    if (!session.hasJwtTokens) {
      throw const AuthenticatedApiClientException.missingCredentials();
    }

    try {
      final value = await send(session.requireAccessToken);
      return AuthenticatedApiCallResult<T>(value: value, session: session);
    } on AccountApiException catch (error) {
      if (!error.isUnauthorized) {
        rethrow;
      }
    }

    final refreshedSession = await _refreshOrJoin(
      session: session,
      persistRefreshedSession: persistRefreshedSession,
    );

    try {
      final value = await send(refreshedSession.requireAccessToken);
      return AuthenticatedApiCallResult<T>(
        value: value,
        session: refreshedSession,
      );
    } on AccountApiException catch (error) {
      if (error.isUnauthorized) {
        throw AuthenticatedApiClientException(
          kind: AuthenticatedApiClientFailureKind.sessionExpired,
          phaseSuffix: 'session_expired',
          visibleMessage: _withCorrelationId(
            '登录已过期，请重新登录后再试。',
            error.correlationId,
          ),
          correlationId: error.correlationId,
        );
      }
      rethrow;
    }
  }

  Future<AccountSession> _refreshOrJoin({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
  }) {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw const AuthenticatedApiClientException.missingCredentials();
    }

    final inFlight = _refreshFuture;
    if (inFlight != null && _refreshTokenInFlight == refreshToken) {
      return inFlight;
    }

    final future = _performRefresh(
      session: session,
      persistRefreshedSession: persistRefreshedSession,
    );
    _refreshTokenInFlight = refreshToken;
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
        _refreshTokenInFlight = null;
      }
    });
  }

  Future<AccountSession> _performRefresh({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
  }) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw const AuthenticatedApiClientException.missingCredentials();
    }

    try {
      final refreshed = await _apiService.refreshSession(
        refreshToken: refreshToken,
      );
      final refreshedSession = AccountSession(
        accountId: refreshed.accountId,
        sessionId: refreshed.sessionId,
        maskedPhoneNumber: refreshed.maskedPhoneNumber,
        createdAt: refreshed.createdAt,
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
        tokenType: refreshed.tokenType,
        accessTokenExpiresAt: refreshed.accessTokenExpiresAt,
        refreshTokenExpiresAt: refreshed.refreshTokenExpiresAt,
      );
      return persistRefreshedSession(refreshedSession);
    } on AccountApiException catch (error) {
      throw _mapRefreshException(error);
    }
  }

  AuthenticatedApiClientException _mapRefreshException(
    AccountApiException error,
  ) {
    if (error.kind == AccountApiFailureKind.timeout) {
      return AuthenticatedApiClientException(
        kind: AuthenticatedApiClientFailureKind.refreshTimeout,
        phaseSuffix: 'refresh_timeout',
        visibleMessage: _withCorrelationId(
          '登录刷新超时，请重新登录后再试。',
          error.correlationId,
        ),
        correlationId: error.correlationId,
      );
    }
    if (error.kind == AccountApiFailureKind.network) {
      return AuthenticatedApiClientException(
        kind: AuthenticatedApiClientFailureKind.refreshNetwork,
        phaseSuffix: 'refresh_network',
        visibleMessage: _withCorrelationId(
          '登录刷新失败，请检查网络后重新登录。',
          error.correlationId,
        ),
        correlationId: error.correlationId,
      );
    }
    if (error.kind == AccountApiFailureKind.malformed) {
      return AuthenticatedApiClientException(
        kind: AuthenticatedApiClientFailureKind.refreshMalformed,
        phaseSuffix: 'refresh_malformed',
        visibleMessage: _withCorrelationId(
          '登录状态异常，请重新登录后再试。',
          error.correlationId,
        ),
        correlationId: error.correlationId,
      );
    }
    if (error.isUnauthorized) {
      return AuthenticatedApiClientException(
        kind: AuthenticatedApiClientFailureKind.sessionExpired,
        phaseSuffix: 'session_expired',
        visibleMessage: _withCorrelationId(
          '登录已过期，请重新登录后再试。',
          error.correlationId,
        ),
        correlationId: error.correlationId,
      );
    }
    return AuthenticatedApiClientException(
      kind: AuthenticatedApiClientFailureKind.refreshFailed,
      phaseSuffix: 'refresh_failed',
      visibleMessage: _withCorrelationId(
        '登录刷新失败，请重新登录后再试。',
        error.correlationId,
      ),
      correlationId: error.correlationId,
    );
  }

  String _withCorrelationId(String message, String? correlationId) {
    final trimmed = correlationId?.trim();
    if (trimmed == null ||
        !RegExp(r'^err_[A-Za-z0-9]{16,64}$').hasMatch(trimmed)) {
      return message;
    }
    return '$message 支持编号：$trimmed。';
  }
}
