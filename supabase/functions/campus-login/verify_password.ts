// Do not mint a custom token until Firebase confirms this exact UID/password.
export async function verifyCampusPassword(
  uid: string,
  email: string,
  password: string,
  apiKey: string,
  appCheckToken: string,
  send: typeof fetch = fetch,
): Promise<boolean> {
  const endpoint = new URL(
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
  );
  endpoint.searchParams.set("key", apiKey);
  const result = await send(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Firebase-AppCheck": appCheckToken,
    },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  if (!result.ok) return false;
  const verified = await result.json();
  return verified?.localId === uid && !verified.mfaPendingCredential;
}
