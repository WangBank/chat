import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..', '..');
const read = (relativePath) => readFileSync(resolve(repositoryRoot, relativePath), 'utf8');

const authController = read('backend/Controllers/AuthController.cs');
const userService = read('backend/Services/ServiceImplementations.cs');
const qqAuthService = read('backend/Services/QQAuthService.cs');
const settingsPage = read('website/src/pages/SettingsPage.tsx');
const mobileProfilePage = read('flutter_client/lib/pages/profile_page.dart');

// A signed-in web user must be able to choose either current-password or
// verified-email-code authentication for a password change.
assert.match(authController, /\[HttpPost\("change-password"\)\]\s*\[Authorize\]/s);
assert.match(authController, /\[HttpPost\("change-password-code"\)\]\s*\[Authorize\]/s);
assert.match(
  userService,
  /if \(!string\.IsNullOrWhiteSpace\(changePasswordDto\.old_password\)\)[\s\S]*?BCrypt\.Net\.BCrypt\.Verify\(changePasswordDto\.old_password, user\.password_hash\)[\s\S]*?else[\s\S]*?GetValidEmailVerificationCodeAsync\([\s\S]*?EmailVerificationPurpose\.ChangePassword/s,
);
assert.match(
  settingsPage,
  /<Radio value="old_password">旧密码<\/Radio>[\s\S]*?<Radio value="email_code" disabled=\{!authStore\.user\?\.email_verified\}/s,
);
assert.match(settingsPage, /apiService\.requestPasswordChangeCode\(\)/);
assert.match(settingsPage, /apiService\.changePassword\([\s\S]*?old_password:[\s\S]*?verification_code:/s);

// QQ data is only allowed to fill missing local profile data, never overwrite
// the birthday, location, avatar, or gender a user already supplied.
assert.match(qqAuthService, /ApplyQQProfile\(user, profile, overwriteLocalProfile: false\)/);
assert.match(
  qqAuthService,
  /private static bool ShouldApplyQQProfileField[\s\S]*?!string\.IsNullOrWhiteSpace\(qqValue\)[\s\S]*?\(overwriteLocalProfile \|\| string\.IsNullOrWhiteSpace\(currentValue\)\)/s,
);
assert.match(qqAuthService, /ShouldApplyQQProfileField\(overwriteLocalProfile, user\.gender, qqGender\)/);
assert.match(qqAuthService, /ShouldApplyQQProfileField\(overwriteLocalProfile, user\.birthday, qqBirthday\)/);
assert.match(qqAuthService, /ShouldApplyQQProfileField\(overwriteLocalProfile, user\.region, qqCity\)/);
assert.match(qqAuthService, /string\.IsNullOrWhiteSpace\(user\.avatar_path\)/);

// Both web and mobile reduce any oversized avatar to a square JPEG under the
// 100 KiB limit before upload, with a clear error if that cannot be achieved.
assert.match(settingsPage, /const maxAvatarBytes = 100 \* 1024/);
assert.match(settingsPage, /const sourceSize = Math\.min\(image\.naturalWidth, image\.naturalHeight\)/);
assert.match(settingsPage, /canvasToJpeg\(canvas, quality\)/);
assert.match(settingsPage, /blob\.size <= maxAvatarBytes/);
assert.match(settingsPage, /头像无法裁剪到 100KB 以内/);
assert.match(mobileProfilePage, /const maxBytes = 100 \* 1024/);
assert.match(mobileProfilePage, /final cropped = image\.copyCrop\(/);
assert.match(mobileProfilePage, /encoded\.length <= maxBytes/);
assert.match(mobileProfilePage, /头像无法裁剪到 100KB 以内/);

console.log('Account, QQ profile, and avatar-size contracts passed.');
