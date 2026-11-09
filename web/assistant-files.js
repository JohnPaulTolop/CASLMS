// Text extraction stays in the browser; only selected excerpts enter a question.
globalThis.caslmsReadPdfText = async function (bytes) {
  const library = await import('./vendor/pdfjs/build/pdf.min.mjs');
  library.GlobalWorkerOptions.workerSrc = new URL(
    './vendor/pdfjs/build/pdf.worker.min.mjs', document.baseURI).href;
  const task = library.getDocument({ data: bytes.slice(), isEvalSupported: false });
  const timeout = setTimeout(() => task.destroy(), 25000);
  try {
    const pdf = await task.promise;
    const pages = [];
    let length = 0;
    for (let index = 1; index <= Math.min(pdf.numPages, 80); index++) {
      const page = await pdf.getPage(index);
      const content = await page.getTextContent();
      const text = content.items.map(item => item.str ?? '').join(' ');
      pages.push(`Page ${index}\n${text}`);
      length += text.length;
      page.cleanup();
      if (length >= 120000) break;
    }
    return pages.join('\n\n').slice(0, 120000);
  } finally {
    clearTimeout(timeout);
    await task.destroy();
  }
};
