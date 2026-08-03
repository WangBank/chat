import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const port = Number.parseInt(process.env.PORT || '8080', 10);
const root = path.join(path.dirname(fileURLToPath(import.meta.url)), 'dist');

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.gif', 'image/gif'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.js', 'application/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
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

async function sendFile(response, filePath) {
  const extension = path.extname(filePath).toLowerCase();
  const contentType = contentTypes.get(extension) || 'application/octet-stream';
  const body = await readFile(filePath);

  applySecurityHeaders(response);
  if (extension === '.html') {
    response.setHeader('Cache-Control', 'no-store');
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
