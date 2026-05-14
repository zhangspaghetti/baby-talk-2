import axios from 'axios';

interface ErrorPayload {
  status?: number;
  code?: string;
  message?: string;
  details?: Record<string, unknown>;
}

export class ApiError extends Error {
  status: number;
  code: string;
  details: Record<string, unknown>;

  constructor(status: number, code: string, message: string, details: Record<string, unknown> = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) {
    return error;
  }

  if (axios.isAxiosError(error)) {
    if (error.code === 'ECONNABORTED') {
      return new ApiError(0, 'request_timeout', '请求超时，请重试。');
    }

    if (!error.response) {
      return new ApiError(0, 'network_error', '无法连接 admin-api。请确认 admin-api 已启动。');
    }

    const payload = isRecord(error.response.data) ? (error.response.data as ErrorPayload) : {};
    return new ApiError(
      payload.status ?? error.response.status,
      payload.code ?? 'request_failed',
      payload.message ?? `请求失败（HTTP ${error.response.status}）。`,
      payload.details ?? {},
    );
  }

  if (error instanceof Error) {
    return new ApiError(0, 'unexpected_error', error.message);
  }

  return new ApiError(0, 'unexpected_error', '发生未预期错误。');
}
