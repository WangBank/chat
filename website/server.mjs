import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const port = Number.parseInt(process.env.PORT || '8080', 10);
const serverDirectory = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(serverDirectory, 'dist');
const apiProxyTarget = (process.env.API_PROXY_TARGET || 'http://api:17101').replace(/\/+$/, '');

// Android artifacts are synced into this directory by scripts/sync-android-release.ps1
// (see .github/workflows/sync-android-apk.yml). Serving them from this container keeps
// the download on the same domain as the website, which is reachable from mainland
// China, while GitHub Releases stays the source of truth and the fallback origin.
const downloadsRoot = path.resolve(
  process.env.DOWNLOADS_DIR || path.join(serverDirectory, 'downloads')
);
const apkFallbackBaseUrl = (
  process.env.APK_FALLBACK_BASE_URL ||
  'https://github.com/WangBank/chat/releases/latest/download'
).replace(/\/+$/, '');

const downloadRoutes = new Map([
  [
    '/download/android',
    {
      file: 'LoveChat-Android.apk',
      contentType: 'application/vnd.android.package-archive',
      downloadName: 'LoveChat-Android.apk',
      cacheControl: 'no-cache',
      fallbackUrl: `${apkFallbackBaseUrl}/LoveChat-Android.apk`
    }
  ],
  [
    '/download/android-version.json',
    {
      file: 'android-version.json',
      contentType: 'application/json; charset=utf-8',
      downloadName: null,
      cacheControl: 'no-store',
      fallbackUrl: `${apkFallbackBaseUrl}/android-version.json`
    }
  ]
]);

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.gif', 'image/gif'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.js', 'application/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.apk', 'application/vnd.android.package-archive'],
  ['.jpg', 'image/jpeg'],
  ['.jpeg', 'image/jpeg'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.webp', 'image/webp'],
  ['.woff', 'font/woff'],
  ['.woff2', 'font/woff2']
]);

function applySecurityHeaders(response) {
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Referrer-Policy', 'no-referrer');
}

function send(response, status, body, contentType = 'text/plain; charset=utf-8') {
  applySecurityHeaders(response);
  response.writeHead(status, { 'Content-Type': contentType });
  response.end(body);
}

function resolveRequestPath(requestUrl) {
  const url = new URL(requestUrl, 'http://localhost');
  const decodedPath = decodeURIComponent(url.pathname);
  const normalizedPath = path.normalize(decodedPath).replace(/^(\.\.[/\\])+/, '');
  return path.join(root, normalizedPath);
}

function shouldProxyMedia(requestUrl) {
  const { pathname } = new URL(requestUrl, 'http://localhost');
  return pathname.startsWith('/avatar/') || pathname.startsWith('/chat-files/');
}

async function proxyToApi(request, response) {
  const sourceUrl = new URL(request.url || '/', 'http://localhost');
  const targetUrl = new URL(`${sourceUrl.pathname}${sourceUrl.search}`, apiProxyTarget);

  const proxyResponse = await fetch(targetUrl, {
    method: request.method,
    headers: {
      Accept: request.headers.accept || '*/*',
      'User-Agent': request.headers['user-agent'] || 'foreverlove-chat-web'
    }
  });

  applySecurityHeaders(response);
  for (const header of ['cache-control', 'content-disposition', 'content-length', 'content-type', 'last-modified', 'etag']) {
    const value = proxyResponse.headers.get(header);
    if (value) {
      response.setHeader(header, value);
    }
  }

  response.writeHead(proxyResponse.status);
  if (request.method === 'HEAD') {
    response.end();
    return;
  }

  const body = Buffer.from(await proxyResponse.arrayBuffer());
  response.end(body);
}

function redirect(response, location) {
  applySecurityHeaders(response);
  response.writeHead(302, {
    Location: location,
    'Cache-Control': 'no-store'
  });
  response.end();
}

function parseRangeHeader(header, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(String(header || '').trim());
  if (!match) {
    return null;
  }

  const [, startText, endText] = match;
  if (startText === '' && endText === '') {
    return null;
  }

  let start;
  let end;
  if (startText === '') {
    const suffixLength = Number.parseInt(endText, 10);
    if (!Number.isFinite(suffixLength) || suffixLength <= 0) {
      return null;
    }
    start = Math.max(0, size - suffixLength);
    end = size - 1;
  }
  else {
    start = Number.parseInt(startText, 10);
    end = endText === '' ? size - 1 : Number.parseInt(endText, 10);
  }

  if (!Number.isFinite(start) || !Number.isFinite(end) || start > end || start >= size) {
    return null;
  }

  return { start, end: Math.min(end, size - 1) };
}

async function sendDownload(request, response, route) {
  const filePath = path.join(downloadsRoot, route.file);
  let fileStat;
  try {
    fileStat = await stat(filePath);
    if (!fileStat.isFile()) {
      throw new Error('not a file');
    }
  }
  catch {
    // Nothing synced yet (or the file was removed): keep downloads working by
    // sending the client to the GitHub release instead of returning 404.
    redirect(response, route.fallbackUrl);
    return;
  }

  const etag = `"${fileStat.size}-${Math.round(fileStat.mtimeMs)}"`;
  applySecurityHeaders(response);
  response.setHeader('Content-Type', route.contentType);
  response.setHeader('Cache-Control', route.cacheControl);
  response.setHeader('Accept-Ranges', 'bytes');
  response.setHeader('ETag', etag);
  response.setHeader('Last-Modified', fileStat.mtime.toUTCString());
  if (route.downloadName) {
    response.setHeader('Content-Disposition', `attachment; filename="${route.downloadName}"`);
  }

  if (request.headers['if-none-match'] === etag) {
    response.writeHead(304);
    response.end();
    return;
  }

  const range = request.headers.range ? parseRangeHeader(request.headers.range, fileStat.size) : null;
  if (request.headers.range && !range) {
    response.writeHead(416, { 'Content-Range': `bytes */${fileStat.size}` });
    response.end();
    return;
  }

  if (range) {
    response.writeHead(206, {
      'Content-Range': `bytes ${range.start}-${range.end}/${fileStat.size}`,
      'Content-Length': String(range.end - range.start + 1)
    });
    if (request.method === 'HEAD') {
      response.end();
      return;
    }
    createReadStream(filePath, { start: range.start, end: range.end }).pipe(response);
    return;
  }

  response.writeHead(200, { 'Content-Length': String(fileStat.size) });
  if (request.method === 'HEAD') {
    response.end();
    return;
  }
  createReadStream(filePath).pipe(response);
}

async function sendFile(response, filePath) {
  const extension = path.extname(filePath).toLowerCase();
  const contentType = contentTypes.get(extension) || 'application/octet-stream';
  const body = await readFile(filePath);

  applySecurityHeaders(response);
  if (extension === '.html') {
    response.setHeader('Cache-Control', 'no-store');
  }
  if (extension === '.apk') {
    response.setHeader('Content-Disposition', 'attachment; filename="LoveChat-Android.apk"');
  }
  if (['.css', '.js', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp', '.woff', '.woff2'].includes(extension)) {
    response.setHeader('Cache-Control', 'public, max-age=2592000, immutable');
  }

  response.writeHead(200, { 'Content-Type': contentType });
  response.end(body);
}

createServer(async (request, response) => {
  if (request.url === '/health') {
    send(response, 200, 'ok\n');
    return;
  }

  const requestPathname = new URL(request.url || '/', 'http://localhost').pathname;
  const downloadRoute = downloadRoutes.get(requestPathname);
  if (downloadRoute && (request.method === 'GET' || request.method === 'HEAD')) {
    try {
      await sendDownload(request, response, downloadRoute);
    }
    catch {
      send(response, 500, 'server error\n');
    }
    return;
  }

  if ((request.method === 'GET' || request.method === 'HEAD') && shouldProxyMedia(request.url || '/')) {
    try {
      await proxyToApi(request, response);
    }
    catch {
      send(response, 502, 'bad gateway\n');
    }
    return;
  }

  try {
    let filePath = resolveRequestPath(request.url || '/');
    const fileStat = await stat(filePath);
    if (fileStat.isDirectory()) {
      filePath = path.join(filePath, 'index.html');
    }

    await sendFile(response, filePath);
  }
  catch (error) {
    const requestPath = new URL(request.url || '/', 'http://localhost').pathname;
    if (path.extname(requestPath)) {
      send(response, 404, 'not found\n');
      return;
    }

    try {
      await sendFile(response, path.join(root, 'index.html'));
    }
    catch {
      send(response, 500, 'server error\n');
    }
  }
}).listen(port, '0.0.0.0', () => {
  console.log(`Website listening on http://0.0.0.0:${port}`);
});
