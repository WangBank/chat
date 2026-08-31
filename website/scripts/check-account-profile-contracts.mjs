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
const chatPage = read('website/src/pages/ChatPage.tsx');
const avatarUtility = read('website/src/utils/avatar.ts');
const mobileProfilePage = read('flutter_client/lib/pages/profile_page.dart');
const webApiService = read('website/src/services/api.service.ts');
const webLoginPage = read('website/src/pages/LoginPage.tsx');
const webCaptchaModal = read('website/src/components/EmailCodeCaptchaModal.tsx');
const mobileLoginPage = read('flutter_client/lib/pages/login_page.dart');
const mobileApiService = read('flutter_client/lib/services/api_service.dart');
const mobileCaptchaDialog = read('flutter_client/lib/widgets/email_code_captcha_dialog.dart');

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
assert.match(settingsPage, /apiService\.requestPasswordChangeCode\(captcha\)/);
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
assert.match(settingsPage, /cropAvatarIfNeeded\(sourceFile\)/);
assert.match(chatPage, /cropAvatarIfNeeded\(file\)/);
assert.match(avatarUtility, /const MAX_AVATAR_BYTES = 100 \* 1024/);
assert.match(avatarUtility, /const sourceSize = Math\.min\(image\.naturalWidth, image\.naturalHeight\)/);
assert.match(avatarUtility, /canvasToJpeg\(canvas, quality\)/);
assert.match(avatarUtility, /blob\.size <= MAX_AVATAR_BYTES/);
assert.match(avatarUtility, /头像无法裁剪到 100KB 以内/);
assert.match(mobileProfilePage, /const maxBytes = 100 \* 1024/);
assert.match(mobileProfilePage, /final cropped = image\.copyCrop\(/);
assert.match(mobileProfilePage, /encoded\.length <= maxBytes/);
assert.match(mobileProfilePage, /头像无法裁剪到 100KB 以内/);

// Every client that can request an email code must obtain a short-lived,
// one-time pattern challenge first. The server verifies the challenge and
// rate-limits both challenge creation and actual email delivery.
assert.match(authController, /\[HttpPost\("email-code-captcha"\)\][\s\S]*?\[EnableRateLimiting\("EmailCodeChallenge"\)\]/);
assert.match(authController, /\[HttpPost\("registration-email-code"\)\][\s\S]*?\[EnableRateLimiting\("EmailCodeSend"\)\]/);
assert.match(authController, /\[HttpPost\("change-email-code"\)\][\s\S]*?\[Authorize\][\s\S]*?\[EnableRateLimiting\("EmailCodeSend"\)\]/);
assert.match(authController, /\[HttpPost\("change-password-code"\)\][\s\S]*?EmailCodeCaptchaVerificationDto captchaDto/);
assert.match(userService, /_emailCodeCaptchaService\.VerifyAsync\([\s\S]*?EmailVerificationPurpose\.Registration/s);
assert.match(userService, /_emailCodeCaptchaService\.VerifyAsync\([\s\S]*?EmailVerificationPurpose\.ChangeEmail/s);
assert.match(userService, /_emailCodeCaptchaService\.VerifyAsync\([\s\S]*?EmailVerificationPurpose\.ChangePassword/s);
assert.match(userService, /EnsureEmailCodeSendRateLimitAsync[\s\S]*?sentInLastMinute[\s\S]*?sentToday/s);
assert.match(webApiService, /createEmailCodeCaptcha[\s\S]*?\/api\/auth\/email-code-captcha/s);
assert.match(webLoginPage, /<EmailCodeCaptchaModal[\s\S]*?purpose="registration"/s);
assert.match(settingsPage, /<EmailCodeCaptchaModal[\s\S]*?captchaFlow/s);
assert.match(webCaptchaModal, /captcha_answer: selected/);
assert.match(mobileApiService, /Future<EmailCodeCaptchaChallenge> createEmailCodeCaptcha/);
assert.match(mobileLoginPage, /showEmailCodeCaptchaDialog\([\s\S]*?purpose: 'registration'/s);
assert.match(mobileProfilePage, /showEmailCodeCaptchaDialog\([\s\S]*?purpose: 'change_email'/s);
assert.match(mobileCaptchaDialog, /class EmailCodeCaptchaDialog[\s\S]*?captchaAnswer: List<int>\.from\(_selected\)/s);

console.log('Account, profile, avatar-size, and email-code captcha contracts passed.');
