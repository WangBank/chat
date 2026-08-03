import { decryptConfig } from '../utils/encryption.utils';

// App configuration
export const APP_CONFIG = {
  // API base URL
  API_BASE_URL: import.meta.env.VITE_API_BASE_URL || 'http://common.wangbank.top:17101',
  
  // SignalR Hub URL
  SIGNALR_HUB_URL: import.meta.env.VITE_SIGNALR_HUB_URL || 'http://common.wangbank.top:17101/videocallhub',
  
  // App name
  APP_NAME: 'SimpleChat',
  
  // Version
  VERSION: import.meta.env.VITE_APP_VERSION || '1.0.0',
  
  // APK download URL
  APK_DOWNLOAD_URL: '/archives/andriod/app-release.apk',

  ADMIN_USERNAME: decryptConfig('YWRtaW4=')
};
