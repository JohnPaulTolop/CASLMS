// LiveKit's documented Twirp API and HS256 JWT format. WebCrypto keeps this
// edge-function adapter independent of Node-only dependencies.
import { ROOM_LIMIT } from "./policy.ts";
type Data = Record<string, unknown>;
const bytes = (value: string) => new TextEncoder().encode(value);
function base64url(value: Uint8Array): string {
  return btoa(String.fromCharCode(...value)).replace(/=/g, "").replace(
    /\+/g,
    "-",
  ).replace(/\//g, "_");
}
export async function signToken(
  apiKey: string,
  secret: string,
  claims: Data,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(bytes(JSON.stringify({ alg: "HS256", typ: "JWT" })));
  const payload = base64url(
    bytes(
      JSON.stringify({
        ...claims,
        iss: apiKey,
        nbf: now,
        iat: now,
        exp: now + 60,
      }),
    ),
  );
  const content = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "raw",
    bytes(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, bytes(content));
  return `${content}.${base64url(new Uint8Array(signature))}`;
}
export function participantGrant(room: string, instructor: boolean): Data {
  return {
    room,
    roomJoin: true,
    roomCreate: false,
    roomAdmin: false,
    canPublish: true,
    canSubscribe: true,
    canPublishData: false,
    canUpdateOwnMetadata: false,
    canPublishSources: instructor
      ? ["camera", "microphone", "screen_share", "screen_share_audio"]
      : ["camera", "microphone"],
  };
}
export class LiveKitApiError extends Error {
  constructor(public code: string) {
    super("Video service request failed.");
  }
}
export class LiveKitRooms {
  constructor(
    private url: string,
    private key: string,
    private secret: string,
    private transport: typeof fetch = fetch,
  ) {}
  private async call(method: string, body: Data, video: Data): Promise<Data> {
    const token = await signToken(this.key, this.secret, { video });
    const response = await this.transport(
      `${
        this.url.replace("wss:", "https:").replace(/\/$/, "")
      }/twirp/livekit.RoomService/${method}`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(15000),
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new LiveKitApiError(
        typeof data.code === "string" ? data.code : "unavailable",
      );
    }
    return data;
  }
  createRoom(name: string, metadata: string) {
    return this.call("CreateRoom", {
      name,
      metadata,
      max_participants: ROOM_LIMIT,
      empty_timeout: 600,
      departure_timeout: 600,
    }, { roomCreate: true });
  }
  async listRooms(name: string): Promise<unknown[]> {
    const response = await this.call("ListRooms", { names: [name] }, {
      roomList: true,
    });
    return Array.isArray(response.rooms) ? response.rooms : [];
  }
  deleteRoom(room: string) {
    return this.call("DeleteRoom", { room }, { roomCreate: true });
  }
  async removeParticipant(room: string, identity: string, cutoff: number) {
    try {
      // The API expects Unix seconds (not JavaScript milliseconds).
      await this.call("RemoveParticipant", {
        room,
        identity,
        revoke_token_ts: String(cutoff),
      }, { roomAdmin: true, room });
    } catch (error) {
      if (!(error instanceof LiveKitApiError && error.code === "not_found")) {
        throw error;
      }
    }
  }
}
