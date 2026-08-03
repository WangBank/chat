import { decryptConfig } from '../utils/encryption.utils';

const trimTrailingSlash = (value: string) => value.replace(/\/+$/, '');

const getCurrentOrigin = () => {
  if (typeof window === 'undefined') return undefined;
  return window.location.origin;
};

const shouldUseCurrentOrigin = (configuredUrl: URL) => {
  if (typeof window === 'undefined') return false;
  return window.location.hostname === 'chat.wangbank.top' &&
    configuredUrl.hostname !== window.location.hostname;
};

const resolveApiBaseUrl = () => {
  const configuredValue = import.meta.env.VITE_API_BASE_URL?.trim();
  const currentOrigin = getCurrentOrigin();

  if (!configuredValue) {
    return currentOrigin || 'https://chat.wangbank.top';
  }

  try {
    const configuredUrl = new URL(configuredValue, currentOrigin || 'https://chat.wangbank.top');
    if (shouldUseCurrentOrigin(configuredUrl) && currentOrigin) {
      return currentOrigin;
    }
    return trimTrailingSlash(configuredUrl.toString());
  } catch {
    return currentOrigin || 'https://chat.wangbank.top';
  }
};

const resolveSignalRHubUrl = () => {
  const configuredValue = import.meta.env.VITE_SIGNALR_HUB_URL?.trim();
  const currentOrigin = getCurrentOrigin();

  if (!configuredValue) {
    return `${currentOrigin || 'https://chat.wangbank.top'}/videocallhub`;
  }

  try {
    const configuredUrl = new URL(configuredValue, currentOrigin || 'https://chat.wangbank.top');
    if (shouldUseCurrentOrigin(configuredUrl) && currentOrigin) {
      return `${currentOrigin}/videocallhub`;
    }
    return trimTrailingSlash(configuredUrl.toString());
  } catch {
    return `${currentOrigin || 'https://chat.wangbank.top'}/videocallhub`;
  }
};

// App configuration
export const APP_CONFIG = {
  // API base URL
  API_BASE_URL: resolveApiBaseUrl(),
  
  // SignalR Hub URL
  SIGNALR_HUB_URL: resolveSignalRHubUrl(),
  
  // App name
  APP_NAME: 'SimpleChat',
  
  // Version
  VERSION: import.meta.env.VITE_APP_VERSION || '1.0.0',
  
  // APK download URL
  APK_DOWNLOAD_URL: '/archives/andriod/app-release.apk',

  ADMIN_USERNAME: decryptConfig('YWRtaW4=')
};
