import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..', '..');
const read = (relativePath) => readFileSync(resolve(repositoryRoot, relativePath), 'utf8');

const webSignalR = read('website/src/services/signalr.service.ts');
const webWebRtc = read('website/src/services/webrtc.service.ts');
const flutterSignalR = read('flutter_client/lib/services/signalr_service.dart');
const flutterWebRtc = read('flutter_client/lib/services/webrtc_video_service.dart');
const flutterCallPage = read('flutter_client/lib/pages/video_call_page.dart');
const callsController = read('backend/Controllers/CallsController.cs');
const liveKitTokenService = read('backend/Services/LiveKitTokenService.cs');
const callService = read('backend/Services/CallService.cs');
const callHistoryModel = read('backend/Models/DatabaseModels.cs');
const dbContext = read('backend/Data/VideoCallDbContext.cs');
const webPackage = read('website/package.json');
const flutterPubspec = read('flutter_client/pubspec.yaml');
const chatPage = read('website/src/pages/ChatPage.tsx');
const program = read('backend/Program.cs');
const userModel = read('backend/Models/DatabaseModels.cs');
const migration = read('backend/Migrations/20260826082007_AddEmailVerificationStatus.cs');
const webServer = read('website/server.mjs');
const webAppConfig = read('website/src/config/app.config.ts');
const flutterAppConfig = read('flutter_client/lib/config/app_config.dart');
const flutterUpdateService = read('flutter_client/lib/services/app_update_service.dart');
const apkSyncScript = read('scripts/sync-android-release.ps1');
const apkSyncWorkflow = read('.github/workflows/sync-android-apk.yml');
const composeFile = read('docker-compose.yml');
const liveKitConfig = read('livekit.yaml');

// LiveKit owns SDP, ICE, reconnection and SFU forwarding. SignalR stays on the
// business-control plane, so no client may retain the retired hand-rolled media
// protocol.
assert.match(callsController, /HttpPost\("\{callId\}\/livekit-token"\)/);
assert.match(callsController, /call\.Status != CallStatus\.Answered/);
assert.match(liveKitTokenService, /roomJoin = true/);
assert.match(liveKitTokenService, /canPublish = true/);
assert.match(liveKitTokenService, /canSubscribe = true/);
assert.match(callService, /var callId = Guid\.NewGuid\(\)\.ToString\(\);/);
assert.match(callService, /call_id = callId/);
assert.match(callService, /call_id = history\.call_id \?\? history\.id\.ToString\(\)/);
assert.match(callHistoryModel, /string\?\s+call_id/);
assert.match(dbContext, /HasIndex\(e => e\.call_id\)\s*\.IsUnique\(\)/s);
assert.match(webPackage, /"livekit-client"/);
assert.match(flutterPubspec, /livekit_client:/);
assert.match(webWebRtc, /import \{ Room, RoomEvent \} from 'livekit-client'/);
assert.match(webWebRtc, /room\.connect\(response\.data\.url, response\.data\.token\)/);
assert.match(webWebRtc, /RoomEvent\.TrackSubscribed/);
assert.match(flutterWebRtc, /package:livekit_client\/livekit_client\.dart/);
assert.match(flutterWebRtc, /await room\.connect\(connection\.url, connection\.token\)/);
assert.match(flutterCallPage, /VideoTrackRenderer\(track, fit: VideoViewFit\.cover\)/);
assert.doesNotMatch(webSignalR, /WebRTCMessage|SendWebRTCMessage/);
assert.doesNotMatch(flutterSignalR, /WebRTCMessage|SendWebRTCMessage|SfuAnswer|SendSfu/);
assert.doesNotMatch(program, /webrtc-config|BuildWebRtcIceServers|WebRtc:Turn/);
for (const obsoletePath of [
  'backend/Models/WebRTCModels.cs',
  'backend/Services/IWebRTCService.cs',
  'backend/Services/WebRTCService.cs',
  'backend/Services/ISfuMediaService.cs',
  'backend/Services/SfuMediaService.cs',
]) {
  assert.equal(existsSync(resolve(repositoryRoot, obsoletePath)), false, `${obsoletePath} must be removed.`);
}
assert.match(composeFile, /livekit\/livekit-server:v1\.13\.11/);
assert.match(composeFile, /LIVEKIT_RTC_PORT_MIN/);
assert.match(liveKitConfig, /port_range_start: 50000/);
assert.match(liveKitConfig, /max_participants: 2/);

assert.match(chatPage, /formatVoiceFileName[\s\S]*\.weba/);
assert.match(program, /\["\.weba"\]\s*=\s*"audio\/webm"/);
assert.match(program, /\["\.m4a"\]\s*=\s*"audio\/mp4"/);

assert.match(userModel, /DateTime\?\s+email_verified_at/);
assert.match(migration, /name:\s*"email_verified_at"/);

// Android APK download contract: GitHub Releases stays the source of truth, the
// website container republishes the same file on the product domain, and every
// client points at that domain with the GitHub Release as fallback.
assert.match(
  webServer,
  /'\/download\/android'/,
  'Website server must serve /download/android from the synced downloads directory.',
);
assert.match(
  webServer,
  /'\/download\/android-version\.json'/,
  'Website server must serve /download/android-version.json from the synced downloads directory.',
);
assert.match(
  webServer,
  /process\.env\.APK_FALLBACK_BASE_URL/,
  'Website server must keep a configurable GitHub fallback for missing APK files.',
);
assert.match(
  webAppConfig,
  /return '\/download\/android';/,
  'Web production build must download the APK from the same origin.',
);
assert.match(
  flutterAppConfig,
  /defaultValue:\s*\n?\s*'https:\/\/chat\.wangbank\.top\/download\/android-version\.json'/,
  'Flutter default update manifest must point at the product domain.',
);
assert.match(
  flutterAppConfig,
  /updateManifestFallbackUrl/,
  'Flutter must keep the GitHub manifest as fallback.',
);
assert.match(
  flutterUpdateService,
  /json\['mirrors'\]/,
  'Flutter update service must read the manifest mirrors list.',
);
assert.match(
  flutterUpdateService,
  /for \(final url in manifest\.downloadUrls\)/,
  'Flutter update service must retry the download through every mirror.',
);
assert.match(
  apkSyncScript,
  /\$manifest\.apkUrl = "\$publicBase\/download\/android"/,
  'Sync script must rewrite apkUrl to the product domain.',
);
assert.match(
  apkSyncWorkflow,
  /self-hosted, Windows, X64, local-docker/,
  'APK sync workflow must run on the deployment host runner.',
);
assert.match(
  composeFile,
  /target: \/app\/downloads/,
  'Website container must mount the synced downloads directory.',
);

console.log('Cross-platform protocol and media contracts passed.');
