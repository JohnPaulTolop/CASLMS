import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { materialUrl, previewFailure } from '../web/document-preview-policy.mjs';

const root = fileURLToPath(new URL('../web/', import.meta.url));
const source = 'https://jymjlterjhznsxrwpjqz.supabase.co/storage/v1/object/public/caslms-learning-materials/';
assert.equal(materialUrl(`${source}lecture.pdf?download=lecture.pdf#page=2`).href, `${source}lecture.pdf`);
for (const value of [null, 'javascript:alert(1)', 'https://evil.test/a.pdf',
  source.replace('supabase.co', 'supabase.co.evil.test') + 'a.pdf',
  source.replace('https://', 'https://user:pass@') + 'a.pdf',
  source.replace('caslms-learning-materials', 'private') + 'a.pdf',
  `${source}%2e%2e/private.pdf`, `${source}a%2fb.pdf`, `${source}a%5cb.pdf`, source]) {
  assert.equal(materialUrl(value), null, `Reject invalid storage destination: ${value}`);
}
assert.match(previewFailure({ status: 404 }), /no longer available/);
assert.match(previewFailure({ status: 403 }), /denied access/);
assert.match(previewFailure({ name: 'PasswordException' }), /password protected/);
assert.match(previewFailure({ name: 'InvalidPDFException' }), /damaged/);

if (process.argv.includes('--policy-only')) {
  console.log('Passed 15 PDF storage URL and error policy checks.');
  process.exit(0);
}

function fixturePdf() {
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 320 400] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 320 400] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  for (const [number, x] of [[1, 30], [2, 160]]) {
    const contents = `BT /F1 20 Tf 25 350 Td (CAS LMS page ${number}) Tj ET 0 0 0 rg ${x} 80 100 100 re f\n`;
    objects.push(`<< /Length ${Buffer.byteLength(contents)} >>\nstream\n${contents}endstream`);
  }
  let text = '%PDF-1.7\n';
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(Buffer.byteLength(text));
    text += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = Buffer.byteLength(text);
  text += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  text += offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('');
  text += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(text);
}

const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    if (pathname === '/test-host') {
      response.setHeader('Content-Type', 'text/html');
      response.end('<iframe title="PDF test" sandbox="allow-scripts allow-same-origin allow-downloads" style="width:100%;height:650px" src="/document-preview.html' +
        '#file=' + encodeURIComponent(source + 'lecture.pdf?download=lecture.pdf') + '"></iframe>');
      return;
    }
    const path = resolve(root, `.${pathname}`);
    if (!path.startsWith(root.endsWith(sep) ? root : root + sep)) {
      response.writeHead(403).end(); return;
    }
    const mime = { '.html': 'text/html', '.mjs': 'application/javascript', '.css': 'text/css', '.wasm': 'application/wasm' };
    response.setHeader('Content-Type', mime[extname(path)] || 'application/octet-stream');
    response.end(await readFile(path));
  } catch { response.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}`;
const runtime = process.env.CASLMS_PLAYWRIGHT_DIR || join(tmpdir(), 'caslms-preview-test-tools');
const require = createRequire(join(runtime, 'package.json'));
let browser;
try {
  const { chromium } = require('playwright-core');
  browser = await chromium.launch({
    executablePath: process.env.CASLMS_EDGE_PATH || 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    headless: true,
  });
  const context = await browser.newContext();
  const page = await context.newPage();
  const scriptErrors = [];
  page.on('pageerror', error => scriptErrors.push(error.message));
  let requestedSource = 0;
  await context.route('https://jymjlterjhznsxrwpjqz.supabase.co/**', async route => {
    requestedSource++;
    const path = new URL(route.request().url()).pathname;
    let status = 200, body = fixturePdf();
    if (path.endsWith('missing.pdf')) { status = 404; body = Buffer.from('Not found'); }
    if (path.endsWith('denied.pdf')) { status = 403; body = Buffer.from('Forbidden'); }
    if (path.endsWith('broken.pdf')) body = Buffer.from('not a PDF');
    await route.fulfill({ status, headers: {
      'content-type': 'application/octet-stream',
      'content-disposition': 'attachment; filename="lecture.pdf"',
      'access-control-allow-origin': '*',
    }, body });
  });
  await page.goto(`${base}/test-host`);
  const frame = page.frameLocator('iframe');
  await frame.locator('#page:not([hidden])').waitFor({ timeout: 30000 });
  assert.equal(await frame.locator('#page-label').textContent(), 'Page 1 of 2');
  assert.equal(await frame.locator('#previous').isDisabled(), true);
  const firstPixels = await frame.locator('#page').evaluate(canvas => canvas.toDataURL());
  assert.ok(firstPixels.length > 1000, 'Canvas must contain rendered PDF pixels');
  await frame.locator('#next').click();
  await frame.locator('#page:not([hidden])').waitFor();
  assert.equal(await frame.locator('#page-label').textContent(), 'Page 2 of 2');
  assert.equal(await frame.locator('#next').isDisabled(), true);
  assert.notEqual(await frame.locator('#page').evaluate(canvas => canvas.toDataURL()), firstPixels,
    'Next page must show different PDF content');
  const widthBefore = await frame.locator('#page').evaluate(canvas => canvas.clientWidth);
  await frame.locator('#zoom').selectOption('1.5');
  await frame.locator('#page:not([hidden])').waitFor();
  assert.ok(await frame.locator('#page').evaluate(canvas => canvas.clientWidth) > widthBefore,
    'Zoom must increase displayed page width');
  await frame.locator('#previous').click();
  await frame.locator('#page:not([hidden])').waitFor();
  assert.equal(await frame.locator('#page-label').textContent(), 'Page 1 of 2');
  for (const [file, text] of [['missing.pdf', /no longer available/],
    ['denied.pdf', /denied access/], ['broken.pdf', /damaged/]]) {
    await page.goto(`${base}/document-preview.html#file=${encodeURIComponent(source + file)}`);
    await page.locator('#retry:not([hidden])').waitFor();
    assert.match(await page.locator('#status').textContent(), text);
    assert.equal(await page.locator('#page').isHidden(), true);
    assert.equal(await page.locator('#original').isVisible(), true);
  }
  await page.goto(`${base}/document-preview.html#file=${encodeURIComponent(source + 'missing.pdf')}`);
  await page.locator('#retry:not([hidden])').waitFor();
  const beforeRetry = requestedSource;
  await page.locator('#retry').click();
  await page.waitForFunction(() => !document.getElementById('retry').hidden);
  assert.ok(requestedSource > beforeRetry, 'Retry fetches the source again');
  const beforeInvalid = requestedSource;
  await page.goto(`${base}/document-preview.html#file=https%3A%2F%2Fevil.test%2Fa.pdf`);
  await page.locator('#notice[role="alert"]').waitFor();
  assert.equal(await page.locator('#retry').isHidden(), true);
  assert.equal(requestedSource, beforeInvalid, 'Invalid destinations do not fetch a file');
  assert.deepEqual(scriptErrors, [], 'No uncaught viewer errors');
  console.log('Passed PDF storage policy and Edge browser checks: sandboxed rendering, attachment headers, pages, zoom, retry, missing/restricted/corrupt files and invalid destinations.');
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
