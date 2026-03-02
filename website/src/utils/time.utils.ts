/**
 * Time utility helpers
 * Handles conversion between UTC time and local time
 */

/**
 * Convert backend timestamp string into Date
 * Backend format: 2026-01-04T05:51:31.498729 (without timezone marker)
 * Backend stores UTC, so append Z suffix if missing
 */
function parseBackendTime(timestamp: string | Date): Date {
  if (timestamp instanceof Date) {
    return timestamp;
  }
  
  // Parse directly if timestamp already contains timezone info
  if (timestamp.includes('Z') || timestamp.includes('+') || timestamp.includes('-', 10)) {
    return new Date(timestamp);
  }
  
  // If timezone is missing, assume UTC and append Z suffix
  const utcString = timestamp.endsWith('Z') ? timestamp : timestamp + 'Z';
  return new Date(utcString);
}

/**
 * Format relative display time
 * Backend returns UTC timestamp string without timezone marker
 */
export function formatTime(timestamp: string | Date): string {
  const date = parseBackendTime(timestamp);
  const now = new Date();
  
  // Compute difference in milliseconds (timezone independent)
  const diff = now.getTime() - date.getTime();
  const minutes = Math.floor(diff / 60000);

  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes}m ago`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)}h ago`;
  
  // Format using local time
  return date.toLocaleString('en-US', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * Format full timestamp (for chat history and similar views)
 */
export function formatFullTime(timestamp: string | Date): string {
  const date = parseBackendTime(timestamp);
  return date.toLocaleString('en-US', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

/**
 * Format date only (without time)
 */
export function formatDate(timestamp: string | Date): string {
  const date = parseBackendTime(timestamp);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
}

