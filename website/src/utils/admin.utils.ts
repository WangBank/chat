import { APP_CONFIG } from '../config/app.config';

export interface AdminComparableUser {
  email?: string | null;
}

export function normalizeEmail(value?: string | null) {
  return (value || '').trim().toLowerCase();
}

export function isAdminEmail(email?: string | null) {
  const normalizedEmail = normalizeEmail(email);
  return Boolean(normalizedEmail) && APP_CONFIG.ADMIN_EMAILS.some((adminEmail) => normalizeEmail(adminEmail) === normalizedEmail);
}

export function isAdminUser(user?: AdminComparableUser | null) {
  return isAdminEmail(user?.email);
}
