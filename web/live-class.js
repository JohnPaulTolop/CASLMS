/* LiveKit room credentials are received only from our same-origin parent. */
(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  let room;
  let connecting = false;
  let intentionalLeave = false;
  const tiles = new Map();
  const audio = new Map();
  const send = (type) => window.parent.postMessage(JSON.stringify({ source: 'cas-classroom', type }), window.location.origin);
  const notice = (text) => { $('notice').textContent = text; };
  const status = (text) => { $('state').textContent = text; };
  const sources = () => window.LivekitClient.Track.Source;
  function role(participant) {
    try { return JSON.parse(participant.metadata || '{}').role === 'instructor' ? 'Instructor' : 'Student'; }
    catch { return 'Student'; }
  }
  function disposeTile(tile) {
    if (tile.track && tile.video) tile.track.detach(tile.video);
    tile.node.remove();
  }
  function tileFor(key, participant, track, screen, muted) {
    let tile = tiles.get(key);
    if (!tile) {
      const node = document.createElement('article'); node.className = 'tile';
      const avatar = document.createElement('span'); avatar.className = 'avatar';
      const name = document.createElement('span'); name.className = 'name';
      node.append(avatar, name);
      tile = { node, avatar, name }; tiles.set(key, tile);
      $(screen ? 'screens' : 'grid').append(node);
    }
    const local = participant === room.localParticipant;
    const name = participant.name || 'Participant';
    tile.avatar.textContent = name.slice(0, 1).toUpperCase();
    tile.name.textContent = `${name}${local ? ' (You)' : ''} · ${screen ? 'Screen' : role(participant)}${participant.isMicrophoneEnabled ? '' : ' · Mic off'}`;
    tile.node.classList.toggle('speaking', !!participant.isSpeaking);
    if (tile.track !== track) {
      if (tile.track && tile.video) tile.track.detach(tile.video);
      tile.video?.remove(); tile.video = null; tile.track = track;
      if (track) {
        const video = document.createElement('video');
        video.autoplay = true; video.playsInline = true; video.muted = true;
        track.attach(video); tile.node.append(video); tile.node.append(tile.name); tile.video = video;
      }
    }
    if (tile.video) tile.video.hidden = !!muted;
    tile.avatar.hidden = !!track && !muted;
  }
  function sync() {
    if (!room) return;
    const participants = [room.localParticipant, ...room.remoteParticipants.values()];
    const seenTiles = new Set(); const seenAudio = new Set();
    const roster = document.createDocumentFragment();
    for (const participant of participants) {
      const camera = participant.getTrackPublication(sources().Camera);
      const cameraKey = `${participant.identity}:camera`;
      tileFor(cameraKey, participant, camera?.track, false, camera?.isMuted); seenTiles.add(cameraKey);
      const screen = participant.getTrackPublication(sources().ScreenShare);
      if (screen?.track && !screen.isMuted) {
        const key = `${participant.identity}:screen`;
        tileFor(key, participant, screen.track, true, false); seenTiles.add(key);
      }
      const row = document.createElement('li');
      row.textContent = `${participant.name || 'Participant'} · ${role(participant)}${participant === room.localParticipant ? ' (You)' : ''}`;
      roster.append(row);
      if (participant !== room.localParticipant) {
        for (const publication of participant.audioTrackPublications.values()) {
          if (!publication.track) continue;
          const key = publication.trackSid; seenAudio.add(key);
          if (!audio.has(key)) {
            const element = publication.track.attach(); element.autoplay = true;
            $('audio').append(element); audio.set(key, { track: publication.track, element });
          }
        }
      }
    }
    for (const [key, tile] of tiles) if (!seenTiles.has(key)) { disposeTile(tile); tiles.delete(key); }
    for (const [key, item] of audio) if (!seenAudio.has(key)) { item.track.detach(item.element); item.element.remove(); audio.delete(key); }
    $('roster').replaceChildren(roster); $('count').textContent = `${participants.length} / 31`;
    const self = room.localParticipant;
    for (const [id, active, on, off] of [
      ['mic', self.isMicrophoneEnabled, 'Turn mic off', 'Turn mic on'],
      ['camera', self.isCameraEnabled, 'Turn camera off', 'Turn camera on'],
      ['share', self.isScreenShareEnabled, 'Stop sharing', 'Share screen'],
    ]) { $(id).textContent = active ? on : off; $(id).setAttribute('aria-pressed', String(active)); }
  }
  async function control(button, action) {
    if (!room || room.state !== 'connected') return;
    button.disabled = true;
    try { await action(); notice(''); }
    catch { notice('Unable to enable this device. Check browser permissions and make sure another app is not using it. You can still listen to the class.'); }
    finally { button.disabled = room.state !== 'connected'; sync(); }
  }
  $('mic').onclick = () => control($('mic'), () => room.localParticipant.setMicrophoneEnabled(!room.localParticipant.isMicrophoneEnabled));
  $('camera').onclick = () => control($('camera'), () => room.localParticipant.setCameraEnabled(!room.localParticipant.isCameraEnabled));
  $('share').onclick = () => control($('share'), () => room.localParticipant.setScreenShareEnabled(!room.localParticipant.isScreenShareEnabled));
  $('sound').onclick = () => control($('sound'), async () => { await room.startAudio(); $('sound').textContent = 'Sound enabled'; });
  $('people-toggle').onclick = () => {
    $('people').hidden = !$('people').hidden;
    $('people-toggle').setAttribute('aria-expanded', String(!$('people').hidden));
  };
  $('leave').onclick = async () => { intentionalLeave = true; await room?.disconnect(); send('leave'); };
  window.addEventListener('pagehide', () => { room?.disconnect(); });
  async function connect(data) {
    if (connecting || room) return;
    connecting = true;
    $('title').textContent = data.title || 'Live classroom';
    $('share').hidden = data.instructor !== true;
    try {
      const { Room, RoomEvent, VideoPresets } = window.LivekitClient;
      room = new Room({ adaptiveStream: true, dynacast: true,
        videoCaptureDefaults: { resolution: VideoPresets.h360.resolution },
        publishDefaults: { videoEncoding: { maxBitrate: 400000, maxFramerate: 20 }, simulcast: true } });
      for (const event of [RoomEvent.ParticipantConnected, RoomEvent.ParticipantDisconnected,
        RoomEvent.TrackSubscribed, RoomEvent.TrackUnsubscribed, RoomEvent.TrackMuted, RoomEvent.TrackUnmuted,
        RoomEvent.LocalTrackPublished, RoomEvent.LocalTrackUnpublished, RoomEvent.ActiveSpeakersChanged,
        RoomEvent.ParticipantNameChanged, RoomEvent.ParticipantMetadataChanged]) room.on(event, sync);
      room.on(RoomEvent.Reconnecting, () => { status('Reconnecting…'); notice('Your connection was interrupted. Reconnecting to the class…'); });
      room.on(RoomEvent.Reconnected, () => { status('Connected'); notice(''); sync(); });
      room.on(RoomEvent.AudioPlaybackStatusChanged, () => {
        if (!room.canPlaybackAudio) notice('Click Enable sound to hear your class.');
      });
      room.on(RoomEvent.Disconnected, () => {
        status('Disconnected');
        for (const id of ['mic', 'camera', 'share', 'sound']) $(id).disabled = true;
        for (const tile of tiles.values()) disposeTile(tile); tiles.clear();
        for (const item of audio.values()) { item.track.detach(item.element); item.element.remove(); } audio.clear();
        if (!intentionalLeave) notice('You have disconnected or the class has ended. Leave this screen, then join again if the class is still live.');
      });
      await room.connect(data.url, data.token, { autoSubscribe: true });
      data.token = ''; // Keep the credential out of any persistent state.
      for (const id of ['mic', 'camera', 'share', 'sound']) $(id).disabled = false;
      status('Connected'); notice('Camera and microphone are off. Click Enable sound if you cannot hear the class.'); sync();
    } catch {
      await room?.disconnect();
      status('Unable to connect');
      notice('Could not join this classroom. Leave and try again. Check your connection; the room may be full, expired, or your joining token may have expired.');
    } finally { connecting = false; }
  }
  window.addEventListener('message', (event) => {
    if (event.origin !== window.location.origin || event.source !== window.parent || typeof event.data !== 'string') return;
    try {
      const data = JSON.parse(event.data);
      if (data.source === 'cas-lms' && data.type === 'connect' && typeof data.token === 'string' && typeof data.url === 'string') connect(data);
    } catch { /* Ignore messages unrelated to this classroom. */ }
  });
  if (!window.LivekitClient) { status('Unable to load video'); notice('The video component did not load. Refresh the LMS and try again.'); }
  else if (window.parent === window) notice('Open this classroom from your course in CAS LMS.');
  else send('ready');
})();
