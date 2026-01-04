import { decryptConfig } from '../utils/encryption.utils';

// 应用配置
export const APP_CONFIG = {
  // API基础URL
  API_BASE_URL: import.meta.env.VITE_API_BASE_URL || 'http://common.wangbank.top:7001',
  
  // SignalR Hub URL
  SIGNALR_HUB_URL: import.meta.env.VITE_SIGNALR_HUB_URL || 'http://common.wangbank.top:7001/videocallhub',
  
  // 应用名称
  APP_NAME: '简聊',
  
  // 版本号
  VERSION: '1.0.0',
  
  // APK下载地址
  APK_DOWNLOAD_URL: '/archives/andriod/app-release.apk',

  ADMIN_USERNAME: decryptConfig('YWRtaW4=')
};
