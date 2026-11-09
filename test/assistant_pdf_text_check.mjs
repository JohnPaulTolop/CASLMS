import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../web/', import.meta.url));
const require = createRequire(join(process.env.CASLMS_PLAYWRIGHT_DIR || join(tmpdir(), 'caslms-preview-test-tools'), 'package.json'));
const { chromium } = require('playwright-core');
function pdfBytes() {
  const text = 'BT /F1 18 Tf 20 150 Td (Widgets build the mobile interface.) Tj ET\n';
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 320 240] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${Buffer.byteLength(text)} >>\nstream\n${text}endstream`,
  ];
  let document = '%PDF-1.7\n';
  const offsets = [];
  objects.forEach((object, index) => {
    offsets.push(Buffer.byteLength(document));
    document += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = Buffer.byteLength(document);
  document += `xref\n0 6\n0000000000 65535 f \n${offsets.map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('')}`;
  document += `trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return [...Buffer.from(document)];
}
const server = createServer(async (request, response) => {
  try {
    if (request.url === '/test-host') {
      response.setHeader('Content-Type', 'text/html');
      response.end('<script src="assistant-files.js"></script>'); return;
    }
    const path = resolve(root, `.${new URL(request.url, 'http://localhost').pathname}`);
    if (!path.startsWith(root.endsWith(sep) ? root : root + sep)) { response.writeHead(403).end(); return; }
    response.setHeader('Content-Type', ['.js', '.mjs'].includes(extname(path)) ? 'application/javascript' : 'application/octet-stream');
    response.end(await readFile(path));
  } catch { response.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ executablePath: process.env.CASLMS_EDGE_PATH || 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe', headless: true });
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${server.address().port}/test-host`);
  const text = await page.evaluate(bytes => globalThis.caslmsReadPdfText(new Uint8Array(bytes)), pdfBytes());
  assert.match(text, /Widgets build the mobile interface/);
  assert.match(text, /Page 1/);
  const rejected = await page.evaluate(async () => {
    try { await globalThis.caslmsReadPdfText(new Uint8Array([1, 2, 3])); return false; }
    catch { return true; }
  });
  assert.equal(rejected, true);
  console.log('Passed real-browser PDF text extraction and invalid PDF rejection.');
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
