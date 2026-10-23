import { materialUrl, previewFailure } from './document-preview-policy.mjs';

const byId = id => document.getElementById(id);
const viewer = byId('viewer');
const canvas = byId('page');
const notice = byId('notice');
const status = byId('status');
const spinner = byId('spinner');
const previous = byId('previous');
const next = byId('next');
const zoom = byId('zoom');
const retry = byId('retry');
const label = byId('page-label');
const original = byId('original');
const source = materialUrl(new URLSearchParams(location.hash.slice(1)).get('file'));
let loadingTask, pdf, renderingTask, pdfLibrary, resizeTimer;
let currentPage = 1;
let busy = false;
let generation = 0;

function controls() {
  previous.disabled = busy || !pdf || currentPage <= 1;
  next.disabled = busy || !pdf || currentPage >= pdf.numPages;
  zoom.disabled = busy || !pdf;
  label.textContent = pdf ? `Page ${currentPage} of ${pdf.numPages}` : 'PDF preview';
}

function message(text, failed = false) {
  notice.hidden = false;
  canvas.hidden = true;
  status.textContent = text;
  notice.setAttribute('role', failed ? 'alert' : 'status');
  spinner.hidden = failed;
  retry.hidden = !failed || !source;
}

async function renderPage() {
  if (!pdf || busy) return;
  const activeGeneration = generation;
  busy = true;
  controls();
  message(`Loading page ${currentPage}…`);
  try {
    const page = await pdf.getPage(currentPage);
    if (activeGeneration !== generation) return;
    const natural = page.getViewport({ scale: 1 });
    const fit = Math.max(100, viewer.clientWidth - 34) / natural.width;
    const viewport = page.getViewport({ scale: fit * Number(zoom.value) });
    // Bound bitmap memory even for oversized pages or high pixel densities.
    const density = Math.min(window.devicePixelRatio || 1, 2,
      Math.sqrt(6_000_000 / (viewport.width * viewport.height)));
    canvas.width = Math.max(1, Math.floor(viewport.width * density));
    canvas.height = Math.max(1, Math.floor(viewport.height * density));
    canvas.style.width = `${Math.floor(viewport.width)}px`;
    canvas.style.height = `${Math.floor(viewport.height)}px`;
    canvas.setAttribute('aria-label', `PDF page ${currentPage} of ${pdf.numPages}`);
    renderingTask = page.render({ canvasContext: canvas.getContext('2d'), viewport,
      transform: density === 1 ? null : [density, 0, 0, density, 0, 0] });
    await renderingTask.promise;
    if (activeGeneration !== generation) return;
    notice.hidden = true;
    canvas.hidden = false;
    viewer.scrollTop = 0;
    page.cleanup();
  } catch (error) {
    if (activeGeneration === generation && error?.name !== 'RenderingCancelledException') {
      message(previewFailure(error), true);
    }
  } finally {
    if (activeGeneration === generation) { busy = false; controls(); }
  }
}

async function load() {
  const activeGeneration = ++generation;
  renderingTask?.cancel();
  const oldTask = loadingTask;
  loadingTask = null;
  pdf = null;
  busy = true;
  controls();
  message('Loading PDF preview…');
  let timeout;
  try {
    if (oldTask) await oldTask.destroy();
    pdfLibrary ??= await import('./vendor/pdfjs/build/pdf.min.mjs');
    if (activeGeneration !== generation) return;
    pdfLibrary.GlobalWorkerOptions.workerSrc = new URL('./vendor/pdfjs/build/pdf.worker.min.mjs', import.meta.url).href;
    loadingTask = pdfLibrary.getDocument({
      url: source.href,
      cMapUrl: new URL('./vendor/pdfjs/cmaps/', import.meta.url).href,
      cMapPacked: true,
      standardFontDataUrl: new URL('./vendor/pdfjs/standard_fonts/', import.meta.url).href,
      wasmUrl: new URL('./vendor/pdfjs/wasm/', import.meta.url).href,
      isEvalSupported: false,
    });
    loadingTask.onProgress = ({ loaded, total }) => {
      if (activeGeneration === generation && retry.hidden) {
        status.textContent = total > 0
          ? `Loading PDF… ${Math.min(100, Math.round(loaded / total * 100))}%`
          : 'Loading PDF preview…';
      }
    };
    const timedOut = new Promise((_, reject) => {
      timeout = setTimeout(() => reject(new Error('Preview timeout')), 30_000);
    });
    pdf = await Promise.race([loadingTask.promise, timedOut]);
    clearTimeout(timeout);
    if (activeGeneration !== generation) return;
    currentPage = 1;
    busy = false;
    await renderPage();
  } catch (error) {
    if (activeGeneration !== generation) return;
    await loadingTask?.destroy().catch(() => {});
    loadingTask = null;
    pdf = null;
    busy = false;
    controls();
    message(previewFailure(error), true);
  } finally {
    clearTimeout(timeout);
  }
}

previous.addEventListener('click', () => { if (!previous.disabled) { currentPage--; void renderPage(); } });
next.addEventListener('click', () => { if (!next.disabled) { currentPage++; void renderPage(); } });
zoom.addEventListener('change', () => void renderPage());
retry.addEventListener('click', () => void load());
viewer.addEventListener('keydown', event => {
  if (event.target !== viewer) return;
  if (event.key === 'ArrowLeft' && !previous.disabled) { event.preventDefault(); previous.click(); }
  if (event.key === 'ArrowRight' && !next.disabled) { event.preventDefault(); next.click(); }
});
const resizeObserver = new ResizeObserver(() => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => { if (pdf && !busy) void renderPage(); }, 150);
});
resizeObserver.observe(viewer);
window.addEventListener('pagehide', () => {
  generation++;
  clearTimeout(resizeTimer);
  resizeObserver.disconnect();
  renderingTask?.cancel();
  void loadingTask?.destroy();
});

if (source) {
  original.href = source.href;
  original.hidden = false;
  void load();
} else {
  message('This record does not contain a valid learning-material storage URL.', true);
}
