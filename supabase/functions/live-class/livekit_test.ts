import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import {
  LiveKitApiError,
  LiveKitRooms,
  participantGrant,
  signToken,
} from "./livekit.ts";
const decode = (token: string) =>
  JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString());

Deno.test("room JWT signature verifies independently, with short expiry and least privilege", async () => {
  const token = await signToken("test-key", "test-secret", {
    sub: "firebase-uid",
    name: "Student",
    video: participantGrant("cas-session", false),
  });
  const [header, body, signature] = token.split(".");
  assert.equal(
    signature,
    createHmac("sha256", "test-secret").update(`${header}.${body}`).digest(
      "base64url",
    ),
  );
  const claims = decode(token);
  assert.equal(claims.iss, "test-key");
  assert.equal(claims.sub, "firebase-uid");
  assert.equal(claims.exp - claims.nbf, 60);
  assert.deepEqual(claims.video.canPublishSources, ["camera", "microphone"]);
  assert.equal(claims.video.roomAdmin, false);
  assert.equal(claims.video.roomCreate, false);
  assert.equal(claims.video.canPublishData, false);
  assert.equal(claims.video.room, "cas-session");
  assert.ok(
    (participantGrant("cas-session", true).canPublishSources as string[])
      .includes("screen_share"),
  );
});
Deno.test("provider room limit, API grants and revocation timestamp use the documented protocol", async () => {
  const requests: { url: string; body: any; claims: any }[] = [];
  const mock = (async (input, init) => {
    const bearer = new Headers(init?.headers).get("Authorization")!.slice(7);
    requests.push({
      url: String(input),
      body: JSON.parse(String(init?.body)),
      claims: decode(bearer),
    });
    return new Response(
      JSON.stringify(
        String(input).endsWith("ListRooms")
          ? { rooms: [{ name: "cas-test" }] }
          : {},
      ),
      { status: 200 },
    );
  }) as typeof fetch;
  const api = new LiveKitRooms(
    "wss://test.livekit.cloud",
    "key",
    "secret",
    mock,
  );
  await api.createRoom("cas-test", "{}");
  assert.equal(requests[0].body.max_participants, 31);
  assert.equal(requests[0].body.empty_timeout, 600);
  assert.equal(requests[0].claims.video.roomCreate, true);
  assert.equal((await api.listRooms("cas-test")).length, 1);
  assert.equal(requests[1].claims.video.roomList, true);
  const cutoff = Math.floor(Date.now() / 1000) + 30;
  await api.removeParticipant("cas-test", "uid", cutoff);
  assert.equal(requests[2].body.revoke_token_ts, String(cutoff));
  assert.equal(requests[2].claims.video.roomAdmin, true);
  assert.match(
    requests[2].url,
    /^https:\/\/test\.livekit\.cloud\/twirp\/livekit.RoomService\/RemoveParticipant$/,
  );
  await api.deleteRoom("cas-test");
  assert.equal(requests[3].claims.video.roomCreate, true);
});
Deno.test("ending tolerates missing participants but fails closed on provider outages", async () => {
  const mock = (code: string) =>
    (async () =>
      new Response(JSON.stringify({ code }), { status: 404 })) as typeof fetch;
  await new LiveKitRooms(
    "wss://test.livekit.cloud",
    "key",
    "secret",
    mock("not_found"),
  ).removeParticipant("r", "u", 100);
  await assert.rejects(
    () =>
      new LiveKitRooms(
        "wss://test.livekit.cloud",
        "key",
        "secret",
        mock("unavailable"),
      ).removeParticipant("r", "u", 100),
    LiveKitApiError,
  );
});
