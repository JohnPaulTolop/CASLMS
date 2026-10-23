// Match the existing adminMaterialUri storage boundary. Documents are fetched
// only from our learning-material bucket; no external document viewer is used.
export function materialUrl(value) {
  try {
    const url = new URL(value);
    const prefix = '/storage/v1/object/public/caslms-learning-materials/';
    if (url.origin !== 'https://jymjlterjhznsxrwpjqz.supabase.co' ||
        url.username || url.password || !url.pathname.startsWith(prefix) ||
        url.pathname.length <= prefix.length) return null;
    for (const encoded of url.pathname.split('/')) {
      const segment = decodeURIComponent(encoded);
      if (segment === '.' || segment === '..' || /[\\/\u0000-\u001f]/.test(segment)) return null;
    }
    // Avoid forcing a download when the original link opens in a browser.
    url.searchParams.delete('download');
    url.hash = '';
    return url;
  } catch {
    return null;
  }
}

export function previewFailure(error) {
  if (error?.name === 'PasswordException') {
    return 'This PDF is password protected. Use Open original to unlock it in your PDF application.';
  }
  if (error?.name === 'InvalidPDFException') {
    return 'This file is not a readable PDF, or it is damaged. Try Open original to check the file.';
  }
  if (error?.name === 'MissingPDFException' || error?.status === 404) {
    return 'This file is no longer available in storage.';
  }
  if (error?.status === 401 || error?.status === 403) {
    return 'Storage denied access to this file. Your administrator may need to check its permissions.';
  }
  return 'Unable to load this PDF. Check your connection, retry, or choose Open original.';
}
