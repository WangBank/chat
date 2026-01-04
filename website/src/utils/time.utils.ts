/**
 * 时间工具函数
 * 用于处理UTC时间和本地时间的转换
 */

/**
 * 将后端返回的时间字符串转换为Date对象
 * 后端返回的时间字符串格式：2026-01-04T05:51:31.498729（没有时区标识）
 * 后端存储的是UTC时间，但返回的字符串没有Z后缀，需要手动添加
 */
function parseBackendTime(timestamp: string | Date): Date {
  if (timestamp instanceof Date) {
    return timestamp;
  }
  
  // 如果字符串已经是ISO格式（带Z或时区），直接解析
  if (timestamp.includes('Z') || timestamp.includes('+') || timestamp.includes('-', 10)) {
    return new Date(timestamp);
  }
  
  // 如果字符串没有时区标识，假设是UTC时间，添加Z后缀
  // 格式：2026-01-04T05:51:31.498729 -> 2026-01-04T05:51:31.498729Z
  const utcString = timestamp.endsWith('Z') ? timestamp : timestamp + 'Z';
  return new Date(utcString);
}

/**
 * 格式化时间显示
 * 后端返回的是UTC时间字符串（没有时区标识），需要转换为本地时间显示
 */
export function formatTime(timestamp: string | Date): string {
  const date = parseBackendTime(timestamp);
  const now = new Date();
  
  // 计算时间差（毫秒），不受时区影响
  const diff = now.getTime() - date.getTime();
  const minutes = Math.floor(diff / 60000);

  if (minutes < 1) return '刚刚';
  if (minutes < 60) return `${minutes}分钟前`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)}小时前`;
  
  // 使用本地时间格式化日期
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * 格式化完整时间（用于历史记录等需要完整时间的场景）
 */
export function formatFullTime(timestamp: string | Date): string {
  const date = parseBackendTime(timestamp);
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

/**
 * 格式化日期（不包含时间）
 */
export function formatDate(timestamp: string | Date): string {
  const date = parseBackendTime(timestamp);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
}

