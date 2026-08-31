export const serviceMaintenanceMessage = '服务正在维护，请稍后重试';

type ErrorPayload = {
  message?: unknown;
  detail?: unknown;
  title?: unknown;
  errors?: unknown;
};

type ErrorLike = {
  response?: {
    status?: number;
    data?: unknown;
  };
  message?: unknown;
  code?: unknown;
};

function flatten(value: unknown): string[] {
  if (typeof value === 'string') {
    const text = value.trim();
    return text ? [text] : [];
  }
  if (Array.isArray(value)) return value.flatMap(flatten);
  if (value && typeof value === 'object') {
    return Object.values(value).flatMap(flatten);
  }
  return [];
}

function uniqueMessages(messages: string[]) {
  return [...new Set(messages.map((message) => message.trim()).filter(Boolean))];
}

export function getApiErrorMessage(error: unknown, fallback = '请求失败') {
  const apiError = (error ?? {}) as ErrorLike;
  const responseData = apiError.response?.data as ErrorPayload | undefined;
  const responseMessages = responseData && typeof responseData === 'object'
    ? uniqueMessages([
        ...flatten(responseData.message),
        ...flatten(responseData.detail),
        ...flatten(responseData.errors),
        ...flatten(responseData.title),
      ])
    : [];

  if (responseMessages.length > 0) return responseMessages.join('\n');

  const status = apiError.response?.status;
  const rawMessage = typeof apiError.message === 'string' ? apiError.message.trim() : '';
  const isNetworkFailure = !apiError.response && (
    apiError.code === 'ERR_NETWORK' ||
    apiError.code === 'ECONNABORTED' ||
    apiError.code === 'ETIMEDOUT' ||
    rawMessage.toLowerCase() === 'network error' ||
    rawMessage.toLowerCase().includes('timeout')
  );
  if (isNetworkFailure || status === 408 || (status !== undefined && status >= 500)) {
    return serviceMaintenanceMessage;
  }

  if (status !== undefined && status >= 400 && rawMessage.toLowerCase().startsWith('request failed with status code')) {
    return fallback;
  }

  if (rawMessage) return rawMessage;

  return fallback;
}
