// Disposable, seeded loopback API. testuser01 must be the configured administrator.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { HubConnectionBuilder, LogLevel } from '@microsoft/signalr';

const origin = new URL(process.env.ANNOUNCEMENT_TEST_ORIGIN);
assert.equal(origin.hostname, '127.0.0.1');
const password = process.env.ANNOUNCEMENT_TEST_PASSWORD;
assert.ok(password);
const feed = '/api/announcements';
const publisher = '/api/admin/announcements';
const transportOnly = process.argv.includes('--transport-only');

async function api(path, method = 'GET', token, body, status = 200) {
  const res = await fetch(new URL(path, origin), {
    method,
    headers: {
      ...(token && { Authorization: `Bearer ${token}` }),
      ...(body && { 'Content-Type': 'application/json' }),
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  assert.equal(res.status, status, `${method} ${path}`);
  if (status === 200) return (await res.json()).data;
}
const login = async username => (await api('/api/auth/login', 'POST', null, { username, password })).token;
const [admin, reader, other] = await Promise.all(['testuser01', 'testuser02', 'testuser03'].map(login));
const note = { title: 'Announcement ' + randomUUID(), body: 'Integration test' };
await api(feed, 'GET', null, null, 401);
await api(publisher, 'POST', reader, note, 403);
await api(feed + '?page=0', 'GET', reader, null, 400);
await api(feed + '?pageSize=51', 'GET', reader, null, 400);
const before = await api(feed, 'GET', reader);
for (const invalid of [{ title: ' ' }, { body: '' }, { title: 'x'.repeat(121) }, { body: 'x'.repeat(4001) }]) {
  await api(publisher, 'POST', admin, { ...note, ...invalid }, 400);
}

function connect(token) {
  const hub = new HubConnectionBuilder()
    .withUrl(new URL('/videocallhub', origin).href, { accessTokenFactory: () => token })
    .configureLogging(LogLevel.None).build();
  const events = { published: [], read: [] };
  hub.on('AnnouncementPublished', ({ id }) => events.published.push(id));
  hub.on('AnnouncementRead', ({ id }) => events.read.push(id));
  return { hub, events };
}
async function until(condition) {
  const deadline = Date.now() + 5000;
  while (!condition() && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 25));
  assert.ok(condition(), 'SignalR notification timeout');
}
async function start(client) {
  await client.hub.start();
  if (!transportOnly) await client.hub.invoke('Authenticate');
}
const [first, second, third] = [reader, reader, other].map(connect);
const clients = [first, second, third];
const publish = title => api(publisher, 'POST', admin, { ...note, title });
try {
  await Promise.all(clients.map(start));
  const firstPost = await publish(note.title);
  await until(() => clients.every(c => c.events.published.includes(firstPost.id)));
  const readPath = `${feed}/${firstPost.id}/read`;
  await Promise.all([api(readPath, 'PUT', reader), api(readPath, 'PUT', reader)]);
  await until(() => [first, second].every(c => c.events.read.includes(firstPost.id)));
  const sameAccount = await api(feed, 'GET', reader);
  const otherAccount = await api(feed, 'GET', other);
  assert.equal(sameAccount.items[0].is_read, true);
  assert.equal(otherAccount.items[0].is_read, false);
  assert.equal(sameAccount.unread_count, before.unread_count);

  await third.hub.stop();
  const secondPost = await publish(note.title + ' offline');
  await until(() => [first, second].every(c => c.events.published.includes(secondPost.id)));
  await start(third);
  const page1 = await api(feed + '?page=1&pageSize=1', 'GET', other);
  const page2 = await api(feed + '?page=2&pageSize=1', 'GET', other);
  assert.deepEqual(page1.items.map(a => a.id), [secondPost.id]);
  assert.deepEqual(page2.items.map(a => a.id), [firstPost.id]);
  assert.equal(page1.items[0].is_read, false);
  assert.equal(page1.unread_count, otherAccount.unread_count + 1);
  assert.equal(page1.total, before.total + 2);
  assert.ok(!third.events.read.includes(firstPost.id));
  assert.ok(!third.events.published.includes(secondPost.id));
  assert.ok([first, second].every(c => c.events.read.filter(id => id === firstPost.id).length === 1));
} finally {
  await Promise.all(clients.map(c => c.hub.stop()));
}
console.log('Announcements passed: authorization, payload limits, pagination, three live clients, account-isolated idempotent reads, offline catch-up.');
