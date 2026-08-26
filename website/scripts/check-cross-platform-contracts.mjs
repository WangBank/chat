import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..', '..');
const read = (relativePath) => readFileSync(resolve(repositoryRoot, relativePath), 'utf8');

const backendWebRtc = read('backend/Models/WebRTCModels.cs');
const webSignalR = read('website/src/services/signalr.service.ts');
const webWebRtc = read('website/src/services/webrtc.service.ts');
const flutterSignalR = read('flutter_client/lib/services/signalr_service.dart');
const chatPage = read('website/src/pages/ChatPage.tsx');
const program = read('backend/Program.cs');
const userModel = read('backend/Models/DatabaseModels.cs');
const migration = read('backend/Migrations/20260826082007_AddEmailVerificationStatus.cs');

assert.match(
  backendWebRtc,
  /enum WebRTCMessageType\s*\{\s*Offer,\s*Answer,\s*IceCandidate,/s,
  'Backend WebRTC enum must remain zero-based Offer/Answer/ICE.',
);
assert.match(webSignalR, /Offer:\s*0/, 'Web must send Offer as 0.');
assert.match(webSignalR, /Answer:\s*1/, 'Web must send Answer as 1.');
assert.match(webSignalR, /IceCandidate:\s*2/, 'Web must send ICE as 2.');
assert.match(webWebRtc, /WebRTCMessageType\.Offer/);
assert.match(webWebRtc, /WebRTCMessageType\.Answer/);
assert.match(webWebRtc, /WebRTCMessageType\.IceCandidate/);
assert.match(flutterSignalR, /case 'Offer':\s*return 0/);
assert.match(flutterSignalR, /case 'Answer':\s*return 1/);
assert.match(flutterSignalR, /case 'IceCandidate':\s*return 2/);

assert.match(chatPage, /formatVoiceFileName[\s\S]*\.weba/);
assert.match(program, /\["\.weba"\]\s*=\s*"audio\/webm"/);
assert.match(program, /\["\.m4a"\]\s*=\s*"audio\/mp4"/);

assert.match(userModel, /DateTime\?\s+email_verified_at/);
assert.match(migration, /name:\s*"email_verified_at"/);

console.log('Cross-platform protocol and media contracts passed.');
