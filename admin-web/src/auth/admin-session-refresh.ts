import { ApiError, authApi, toApiError, type AuthSession } from './auth-api';
import { clearStoredSession, loadStoredSession, persistStoredSession, type AuthBannerState } from './session-store';

let inFlightRefresh: Promise<AuthSession> | null = null;

export function refreshAdminSessionOnce(): Promise<AuthSession> {
  if (inFlightRefresh) {
    return inFlightRefresh;
  }

  const refreshToken = loadStoredSession()?.refreshToken;
  const refreshPromise = (
    refreshToken
      ? authApi.refresh(refreshToken)
      : Promise.reject<AuthSession>(new ApiError(401, 'admin_session_invalid', '管理员会话已失效，请重新登录。'))
  )
    .then((nextSession) => {
      persistStoredSession(nextSession);
      return nextSession;
    })
    .catch((error: unknown) => {
      const apiError = toApiError(error);
      clearStoredSession(toSessionResetBanner(apiError));
      throw apiError;
    })
    .finally(() => {
      inFlightRefresh = null;
    });

  inFlightRefresh = refreshPromise;
  return refreshPromise;
}

function toSessionResetBanner(error: ApiError): AuthBannerState {
  if (error.code === 'invalid_response_payload') {
    return {
      type: 'error',
      message: '管理员身份响应异常，已清理本地会话，请重新登录。',
      code: error.code,
    };
  }

  return {
    type: error.status === 401 ? 'warning' : 'error',
    message: error.message,
    code: error.code,
  };
}
