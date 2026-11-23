// Run against a disposable local API seeded with DemoSeed and testuser01 as admin.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { HubConnectionBuilder, LogLevel } from '@microsoft/signalr';

const origin = new URL(process.env.OPERATION_LOG_TEST_ORIGIN);
assert.equal(origin.hostname, '127.0.0.1');
const password = process.env.OPERATION_LOG_TEST_PASSWORD;
assert.ok(password, 'Provide the password of the disposable DemoSeed accounts');
const marker = randomUUID();
const endpoint = '/api/admin/operation-logs';

async function request(path, token, body) {
  return fetch(new URL(path, origin), {
    method: body === undefined ? 'GET' : 'POST',
    headers: {
      ...(token && { Authorization: `Bearer ${token}` }),
      ...(body && { 'Content-Type': 'application/json' }),
    },
    body: JSON.stringify(body),
  });
}

async function login(username) {
  const res = await request('/api/auth/login', null, { username, password });
  assert.equal(res.status, 200);
  return (await res.json()).data;
}

const admin = await login('testuser01');
async function list(search = '') {
  const res = await request(endpoint + search, admin.token);
  assert.equal(res.status, 200);
  return (await res.json()).data;
}
const baseline = (await list('?pageSize=1')).items[0]?.id ?? 0;
const member = await login('testuser02');
assert.equal((await request(endpoint)).status, 401);
assert.equal((await request(endpoint, member.token)).status, 403);
assert.equal((await request(endpoint + '?page=0', admin.token)).status, 400);

assert.equal((await request('/api/auth/login', null, { username: marker, password: marker })).status, 400);
assert.equal((await request('/api/chat/send', member.token, {
  receiver_id: admin.user.id, content: marker, type: 0,
})).status, 200);
assert.equal((await request('/api/admin/announcements', member.token, {
  title: marker, body: marker,
})).status, 403);

const hub = new HubConnectionBuilder()
  .withUrl(new URL('/videocallhub', origin).href, { accessTokenFactory: () => member.token })
  .configureLogging(LogLevel.None).build();
hub.on('CallError', () => {});
hub.on('CallInitiated', () => {});
hub.on('CallEnded', () => {});
let callId;
hub.on('CallInitiated', event => { callId = event.call_id; });
await hub.start();
try {
  await hub.invoke('JoinCall', marker);
  await hub.invoke('InitiateCall', { receiver_id: admin.user.id, call_type: 0 });
  assert.ok(callId);
  await hub.invoke('EndCall', callId);
} finally {
  await hub.stop();
}

const current = (await list('?pageSize=100')).items.filter(l => l.id > baseline);
const has = (operation, source, success, userId, statusCode) =>
  current.some(l => l.operation === operation && l.source === source &&
    l.success === success && l.userId === userId && l.statusCode === statusCode);
assert.ok(has('账号登录', 'HTTP', true, member.user.id, 200));
assert.ok(has('账号登录', 'HTTP', false, null, 400));
assert.ok(has('发送私聊消息', 'HTTP', true, member.user.id, 200));
assert.ok(has('发布系统公告', 'HTTP', false, member.user.id, 403));
assert.ok(has('加入通话', 'SignalR', false, member.user.id, null));
assert.ok(has('发起通话', 'SignalR', true, member.user.id, null));
assert.ok(has('结束通话', 'SignalR', true, member.user.id, null));
assert.ok(current.every(l => !l.userId || l.username));
assert.ok(current.every(l => Number.isFinite(Date.parse(l.createdAt))));
for (const secret of [marker, password, member.token, admin.token]) {
  assert.ok(!JSON.stringify(current).includes(secret));
}
const failures = await list(`?userId=${member.user.id}&success=false&page=1&pageSize=1`);
const older = await list(`?userId=${member.user.id}&success=false&page=2&pageSize=1`);
assert.ok(failures.total >= 2);
assert.equal(failures.items.length, 1);
assert.equal(older.items.length, 1);
assert.ok(failures.items[0].id > older.items[0].id);
assert.ok([failures.items[0], older.items[0]].every(l => !l.success && l.userId === member.user.id));
console.log('Operation logs passed: actors, credentials redaction, HTTP and SignalR outcomes, admin authorization and pagination.');
