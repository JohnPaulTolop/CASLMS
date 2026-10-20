export function decode64(value: string) {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
}
function encode64(value: Uint8Array) {
  return btoa(String.fromCharCode(...value));
}
async function key(secret: string) {
  const raw = decode64(secret);
  if (raw.byteLength !== 32) throw new Error("Invalid grade encryption key.");
  return await crypto.subtle.importKey("raw", raw, { name: "AES-GCM" }, false, [
    "encrypt",
    "decrypt",
  ]);
}
export async function encryptGrade(
  payload: unknown,
  secret: string,
  context: string,
) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: new TextEncoder().encode(context) },
    await key(secret),
    new TextEncoder().encode(JSON.stringify(payload)),
  );
  return {
    version: 1,
    iv: encode64(iv),
    ciphertext: encode64(new Uint8Array(ciphertext)),
  };
}
export async function decryptGrade(
  encrypted: { version: number; iv: string; ciphertext: string },
  secret: string,
  context: string,
) {
  if (encrypted.version !== 1) {
    throw new Error("Unsupported grade encryption version.");
  }
  const payload = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: decode64(encrypted.iv),
      additionalData: new TextEncoder().encode(context),
    },
    await key(secret),
    decode64(encrypted.ciphertext),
  );
  return JSON.parse(new TextDecoder().decode(payload));
}
