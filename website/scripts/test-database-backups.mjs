// macOS/Linux: build backend/VideoCallAPI.csproj -c Release, then run with the
// PostgreSQL server and client executables on PATH. Always creates its own cluster.
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { once } from 'node:events';
import { closeSync, existsSync, mkdtempSync, openSync, readFileSync, readdirSync, rmSync, statSync, truncateSync } from 'node:fs';
import { createServer } from 'node:net';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const apiDll = fileURLToPath(new URL('../../backend/bin/Release/net10.0/VideoCallAPI.dll', import.meta.url));
assert.ok(existsSync(apiDll), 'Build the API in Release configuration first');
const root = mkdtempSync('/tmp/chat-backup-test-');
const data = join(root, 'data');
const archives = join(root, 'archives');
const dbName = 'backup_test';
const env = { PATH: process.env.PATH, LANG: 'C', PGUSER: 'tester', PGHOST: root, PGPORT: '5432' };
const run = (file, args) => execFileSync(file, args, { cwd: root, env, encoding: 'utf8' }).trim();
const sql = query => run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-At', '-d', dbName, '-c', query]);
const password = randomBytes(24).toString('hex');
let api;
let started = false;
try {
  run('initdb', ['-D', data, '-U', 'tester', '--auth-local=trust', '--auth-host=reject',
    '--no-locale', '--encoding=UTF8']);
  run('pg_ctl', ['-D', data, '-o', `-k ${root} -h '' -p 5432`, '-l', join(root, 'pg.log'), '-w', 'start']);
  started = true;
  run('createdb', [dbName]);
  const listener = createServer();
  listener.listen(0, '127.0.0.1');
  await once(listener, 'listening');
  const origin = `http://127.0.0.1:${listener.address().port}`;
  await new Promise(resolve => listener.close(resolve));
  const logPath = join(root, 'api.log');
  const log = openSync(logPath, 'w');
  api = spawn('dotnet', [apiDll, '--urls', origin], {
    cwd: root, stdio: ['ignore', log, log],
    env: { ...env, ASPNETCORE_CONTENTROOT: dirname(apiDll), ASPNETCORE_ENVIRONMENT: 'Production',
      ConnectionStrings__DefaultConnection: `Host=${root};Port=5432;Username=tester;Database=${dbName}`,
      DatabaseBackup__Directory: archives, DemoSeed__Enabled: 'true', DemoSeed__Password: password,
      Admin__Email: 'backup-admin@example.com', Jwt__SecretKey: randomBytes(40).toString('hex'),
      Security__UseHttpsRedirection: 'false' },
  });
  closeSync(log);
  for (let attempt = 0; !(await fetch(origin + '/health').catch(() => null))?.ok; attempt++) {
    if (attempt >= 150 || api.exitCode !== null) {
      throw new Error('Isolated test API failed to start:\n' + readFileSync(logPath, 'utf8').slice(-3500));
    }
    await delay(200);
  }
  async function request(path, token, method = 'GET', body) {
    return fetch(origin + path, { method, headers: {
      ...(token && { Authorization: 'Bearer ' + token }),
      ...(body && { 'Content-Type': 'application/json' }),
    }, body: JSON.stringify(body) });
  }
  async function success(responsePromise) {
    const response = await responsePromise;
    assert.equal(response.status, 200);
    return (await response.json()).data;
  }
  const login = username => success(request('/api/auth/login', null, 'POST', { username, password }));
  sql("UPDATE users SET email='backup-admin@example.com' WHERE username='testuser01'");
  const { token } = await login('testuser01');
  const { token: member } = await login('testuser02');
  const backups = '/api/admin/backups';
  const restore = (id, confirmed = id) => request(`${backups}/${id}/restore`, token, 'POST', { confirmBackupId: confirmed });
  assert.equal((await request(backups)).status, 401);
  assert.equal((await request(backups, member, 'POST')).status, 403);
  sql("CREATE TABLE sample(note text); INSERT INTO sample VALUES ('original'); CREATE ROLE backup_reader; GRANT SELECT ON sample TO backup_reader");
  const original = await success(request(backups, token, 'POST'));
  assert.equal(original.kind, 'manual');
  assert.ok(original.sizeBytes > 0);
  assert.deepEqual(await success(request(backups, token)), [original]);
  assert.equal((await restore(original.id, 'wrong')).status, 400);
  assert.equal((await request(`${backups}/${original.id}/restore`, member, 'POST', { confirmBackupId: original.id })).status, 403);
  sql("UPDATE sample SET note='changed'; REVOKE SELECT ON sample FROM backup_reader");
  const state = () => sql("SELECT note, has_table_privilege('backup_reader','sample','select') FROM sample");
  const safety = await success(restore(original.id));
  assert.equal(safety.kind, 'before-restore');
  assert.equal(state(), 'original|t');
  await success(restore(safety.id));
  assert.equal(state(), 'changed|f');
  sql(`INSERT INTO "__EFMigrationsHistory" ("MigrationId","ProductVersion") VALUES ('test_newer_schema','10')`);
  const before = await success(request(backups, token));
  assert.equal((await restore(original.id)).status, 409);
  assert.deepEqual(await success(request(backups, token)), before);
  assert.equal(state(), 'changed|f');
  sql(`DELETE FROM "__EFMigrationsHistory" WHERE "MigrationId"='test_newer_schema'`);
  const archive = join(archives, readdirSync(archives).find(path => path.endsWith(original.id + '.dump')));
  truncateSync(archive, Math.floor(statSync(archive).size * 0.8));
  assert.equal((await restore(original.id)).status, 500);
  assert.equal(state(), 'changed|f');
  console.log('Passed: authorization, backup, confirmation, data and ACL restore, safety backup, schema check, and corrupt archive rollback.');
} finally {
  if (api?.pid && api.exitCode === null && api.signalCode === null) {
    const exit = once(api, 'exit');
    api.kill();
    await exit;
  }
  if (started) run('pg_ctl', ['-D', data, '-m', 'fast', '-w', 'stop']);
  rmSync(root, { recursive: true });
}
