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
  const status = (text) => {
    $('state').textContent = text;
    document.body.dataset.connection = text === 'Connected' ? 'connected' : text.startsWith('Reconnecting') ? 'reconnecting' : text === 'Disconnected' ? 'disconnected' : text.startsWith('Unable') ? 'error' : 'connecting';
    if (text === 'Disconnected' || text.startsWith('Unable')) {
      $('empty').hidden = false; $('empty-title').textContent = 'You are not connected';
      $('empty-description').textContent = 'Leave this screen and join again when your classroom is available.';
    }
  };
  const sources = () => window.LivekitClient.Track.Source;
  const iconPaths = {
    mic: 'M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zm-7 9a7 7 0 0 0 14 0M12 19v3m-4 0h8',
    micOff: 'm3 3 18 18M9 9v3a3 3 0 0 0 5 2.2M15 9V6a3 3 0 0 0-5.8-1M5 12a7 7 0 0 0 12 4.9M19 12v.5M12 19v3m-4 0h8',
    camera: 'M4 6h10a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2zm12 4 6-3v10l-6-3',
    cameraOff: 'm3 3 18 18M9 6h5a2 2 0 0 1 2 2v2l6-3v10l-3-1.5M16 16v.5a2 2 0 0 1-2 1.5H4a2 2 0 0 1-2-2V8a2 2 0 0 1 1-1.7',
    share: 'M9 16H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-5M8 21h8m-4 0V8m-4 4 4-4 4 4',
    sound: 'm11 4-6 5H2v6h3l6 5V4zm4 4a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14',
    leave: 'm3 16 4-1v-4m10 4v-4l4 1m-18 0a13 13 0 0 1 18 0l-2 4-4-1v-3a12 12 0 0 0-6 0v3l-4 1-2-4',
  };
  function setButton(id, label, icon, action = label) {
    const button = $(id);
    button.querySelector('.control-label').textContent = label;
    button.setAttribute('aria-label', action); button.title = action;
    const host = button.querySelector('.control-icon');
    if (host.dataset.icon === icon) return;
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', iconPaths[icon]); svg.append(path); host.replaceChildren(svg); host.dataset.icon = icon;
  }
  setButton('mic', 'Mic off', 'micOff', 'Turn microphone on');
  setButton('camera', 'Camera off', 'cameraOff', 'Turn camera on');
  setButton('share', 'Share screen', 'share');
  setButton('sound', 'Enable sound', 'sound');
  setButton('leave', 'Leave class', 'leave');
  function filterPeople() {
    const query = $('people-search').value.trim().toLocaleLowerCase();
    let matches = 0;
    for (const item of $('roster').children) {
      item.hidden = !item.textContent.toLocaleLowerCase().includes(query);
      if (!item.hidden) matches++;
    }
    $('no-people').hidden = matches > 0 || !query;
  }
  function showPeople(open) {
    $('people').hidden = !open;
    $('people-toggle').setAttribute('aria-expanded', String(open));
    $('people-toggle').title = open ? 'Hide participants' : 'Show participants';
    if (open) $('people-search').focus(); else $('people-toggle').focus();
  }
  $('people-search').addEventListener('input', filterPeople);
  $('people-close').onclick = () => showPeople(false);
  document.addEventListener('keydown', (event) => { if (event.key === 'Escape' && !$('people').hidden) showPeople(false); });
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
    tile.node.dataset.role = role(participant);
    tile.avatar.textContent = name.slice(0, 1).toUpperCase();
    tile.name.textContent = `${name}${local ? ' (You)' : ''} · ${screen ? 'Screen' : role(participant)}${participant.isMicrophoneEnabled ? '' : ' · Mic off'}`;
    tile.name.title = tile.name.textContent;
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
    if (!room || room.state !== 'connected') return;
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
      const avatar = document.createElement('span'); avatar.className = 'roster-avatar'; avatar.setAttribute('aria-hidden', 'true'); avatar.textContent = (participant.name || 'P').slice(0, 1).toUpperCase();
      const person = document.createElement('span'); person.className = 'roster-person';
      const name = document.createElement('span'); name.className = 'roster-name'; name.textContent = `${participant.name || 'Participant'}${participant === room.localParticipant ? ' (You)' : ''}`;
      const label = document.createElement('span'); label.className = 'roster-role'; label.textContent = role(participant);
      const mic = document.createElement('span'); mic.className = `roster-mic${participant.isMicrophoneEnabled ? ' active' : ''}`; mic.setAttribute('role', 'img'); mic.setAttribute('aria-label', participant.isMicrophoneEnabled ? 'Microphone on' : 'Microphone off');
      person.append(name, label); row.append(avatar, person, mic); roster.append(row);
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
    $('roster').replaceChildren(roster); filterPeople(); $('empty').hidden = participants.length > 0; document.body.classList.toggle('presenting', $('screens').children.length > 0); $('count').textContent = `${participants.length} / 31`;
    const self = room.localParticipant;
    for (const [id, active, on, off, iconOn, iconOff, actionOn, actionOff] of [
      ['mic', self.isMicrophoneEnabled, 'Mic on', 'Mic off', 'mic', 'micOff', 'Turn microphone off', 'Turn microphone on'],
      ['camera', self.isCameraEnabled, 'Camera on', 'Camera off', 'camera', 'cameraOff', 'Turn camera off', 'Turn camera on'],
      ['share', self.isScreenShareEnabled, 'Stop sharing', 'Share screen', 'share', 'share', 'Stop sharing', 'Share screen'],
    ]) { setButton(id, active ? on : off, active ? iconOn : iconOff, active ? actionOn : actionOff); $(id).setAttribute('aria-pressed', String(active)); }
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
  $('sound').onclick = () => control($('sound'), async () => { await room.startAudio(); setButton('sound', 'Sound enabled', 'sound'); });
  $('people-toggle').onclick = () => showPeople($('people').hidden);
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
        $('roster').replaceChildren(); $('count').textContent = '0 / 31'; document.body.classList.remove('presenting');
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
