/**
 * Encryption/decryption utility helpers
 * Uses Base64 for basic obfuscation (note: frontend code cannot truly hide secrets)
 * For production, prefer environment variables or backend configuration
 */

/**
 * Decode string (Base64)
 * Uses browser native APIs only, without Node.js Buffer
 */
export function decryptConfig(encryptedValue: string): string {
  try {
    // Use atob in browser environment
    if (typeof window !== 'undefined' && window.atob) {
      return decodeURIComponent(escape(window.atob(encryptedValue)));
    }
  } catch (e) {
    console.error('Failed to decrypt:', e);
    return encryptedValue;
  }
  
  // Fallback: return original value if unsupported
  return encryptedValue;
}

/**
 * Encode string (Base64) - only for generating encoded values, not runtime use
 */
export function encryptConfig(value: string): string {
  if (typeof window !== 'undefined' && window.btoa) {
    return window.btoa(unescape(encodeURIComponent(value)));
  }
  // Return original value if encoding is unavailable
  return value;
}
