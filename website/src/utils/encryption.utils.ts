/**
 * 加密/解密工具函数
 * 使用Base64编码进行基本混淆（注意：前端代码无法真正隐藏，这只是基本混淆）
 * 生产环境建议使用环境变量或后端配置
 */

/**
 * 解码字符串（Base64解码）
 * 仅使用浏览器原生API，不依赖Node.js Buffer
 */
export function decryptConfig(encryptedValue: string): string {
  try {
    // 浏览器环境使用atob
    if (typeof window !== 'undefined' && window.atob) {
      return decodeURIComponent(escape(window.atob(encryptedValue)));
    }
  } catch (e) {
    console.error('解密失败:', e);
    return encryptedValue;
  }
  
  // fallback：如果环境不支持，返回原值
  return encryptedValue;
}

/**
 * 编码字符串（Base64编码）- 仅用于生成加密值，不在运行时使用
 */
export function encryptConfig(value: string): string {
  if (typeof window !== 'undefined' && window.btoa) {
    return window.btoa(unescape(encodeURIComponent(value)));
  }
  // 如果无法编码，返回原值
  return value;
}
