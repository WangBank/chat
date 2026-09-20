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

// Android APK download. In production the website container serves the APK that
// CI synced from the GitHub Release (`/download/android`), so the download stays
// on a domain that is reachable from mainland China; when the synced file is
// missing the server redirects to the GitHub Release. Override with
// VITE_APK_DOWNLOAD_URL when hosting the APK somewhere else.
const GITHUB_APK_DOWNLOAD_URL =
  'https://github.com/WangBank/chat/releases/latest/download/LoveChat-Android.apk';

const resolveApkDownloadUrl = () => {
  const configuredValue = import.meta.env.VITE_APK_DOWNLOAD_URL?.trim();
  if (configuredValue) {
    return trimTrailingSlash(configuredValue);
  }
  if (import.meta.env.DEV) {
    return GITHUB_APK_DOWNLOAD_URL;
  }
  return '/download/android';
};

const parseAdminEmails = (): string[] => {
  const configuredValue = (import.meta.env.VITE_ADMIN_EMAILS as string | undefined)?.trim();
  if (!configuredValue) return [];

  return configuredValue
    .split(/[,\n;\s]+/)
    .map((email: string) => email.trim().toLowerCase())
    .filter(Boolean);
};

// App configuration
export const APP_CONFIG = {
  // API base URL
  API_BASE_URL: resolveApiBaseUrl(),
  
  // SignalR Hub URL
  SIGNALR_HUB_URL: resolveSignalRHubUrl(),
  
  // App name
  APP_NAME: 'Love Chat',
  
  // Version
  VERSION: import.meta.env.VITE_APP_VERSION || '1.0.0',
  
  // APK download URL (same-origin synced copy, GitHub Release as server-side fallback)
  APK_DOWNLOAD_URL: resolveApkDownloadUrl(),

  ADMIN_EMAILS: parseAdminEmails()
};
