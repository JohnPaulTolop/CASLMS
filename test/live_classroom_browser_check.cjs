const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require('../.dart_tool/live-class-validation/node_modules/playwright-core');
const webRoot = path.resolve(__dirname, '../web');
const output = path.resolve(__dirname, '../.dart_tool/live-class-validation');

const mockSdk = `(() => {
  const eventNames = ['ParticipantConnected','ParticipantDisconnected','TrackSubscribed','TrackUnsubscribed','TrackMuted','TrackUnmuted','LocalTrackPublished','LocalTrackUnpublished','ActiveSpeakersChanged','ParticipantNameChanged','ParticipantMetadataChanged','Reconnecting','Reconnected','AudioPlaybackStatusChanged','Disconnected'];
  const events = Object.fromEntries(eventNames.map(name => [name, name]));
  const fakeTrack = () => ({ attach(element) { return element || document.createElement('audio'); }, detach() {} });
  class Participant {
    constructor(identity, name, role) { Object.assign(this, {identity, name, metadata:JSON.stringify({role}), isMicrophoneEnabled:false, isCameraEnabled:false, isScreenShareEnabled:false, audioTrackPublications:new Map(), camera:fakeTrack(), screen:fakeTrack()}); }
    getTrackPublication(source) { if(source === 'camera' && this.isCameraEnabled) return {track:this.camera,isMuted:false}; if(source === 'screen_share' && this.isScreenShareEnabled) return {track:this.screen,isMuted:false}; }
    async setMicrophoneEnabled(active) {this.isMicrophoneEnabled=active; window.testRoom.emit('TrackMuted');}
    async setCameraEnabled(active) {this.isCameraEnabled=active; window.testRoom.emit('LocalTrackPublished');}
    async setScreenShareEnabled(active) {this.isScreenShareEnabled=active; window.testRoom.emit('LocalTrackPublished');}
  }
  class Room {
    constructor() {
      this.listeners = new Map(); this.state='disconnected';
      const teacher = window.parent.location.search.includes('teacher');
      this.localParticipant = new Participant('self', teacher?'Teacher':'Student', teacher?'instructor':'student');
      this.remoteParticipants = new Map();
      const count = teacher ? 30 : 2;
      for(let i=0;i<count;i++) this.remoteParticipants.set('p'+i,new Participant('p'+i,i===0?'<img src=x onerror=alert(1)>':'Student '+i,'student'));
      window.testRoom=this;
    }
    on(name,handler) { if(!name) throw Error('Unknown event'); const list=this.listeners.get(name)||[]; list.push(handler);this.listeners.set(name,list);return this; }
    emit(name) {for(const handler of this.listeners.get(name)||[]) handler();}
    async connect(url,token) {window.lastTestToken=token;this.state='connected';}
    async startAudio() {this.canPlaybackAudio=true;}
    async disconnect() {this.state='disconnected';this.emit('Disconnected');}
  }
  window.LivekitClient = {Room,RoomEvent:events,Track:{Source:{Camera:'camera',ScreenShare:'screen_share'}},VideoPresets:{h360:{resolution:{width:640,height:360}}}};
})();`;

const server = http.createServer(async (req, res) => {
  try {
    const requestUrl = new URL(req.url, 'http://localhost');
    if (requestUrl.pathname === '/parent') {
      res.setHeader('Content-Type', 'text/html');
      res.end(`<!doctype html><style>body{margin:0}iframe{width:100%;height:100vh;border:0}</style><iframe id="room" src="/live-class.html" allow="camera;microphone;display-capture;autoplay"></iframe><script>
      window.addEventListener('message', e=> {if(e.source!==room.contentWindow || e.origin!==location.origin)return; const d=JSON.parse(e.data); if(d.type==='ready') room.contentWindow.postMessage(JSON.stringify({source:'cas-lms',type:'connect',url:'wss://test.livekit.cloud',token:'test-token',title:'IT 101 · Live discussion',instructor:location.search.includes('teacher')}),location.origin); if(d.type==='leave') window.didLeave=true;});</script>`);
      return;
    }
    const filename = path.resolve(webRoot, '.' + decodeURIComponent(requestUrl.pathname));
    if (!filename.startsWith(webRoot + path.sep)) { res.writeHead(403).end(); return; }
    res.setHeader('Content-Type', filename.endsWith('.js') ? 'text/javascript' : filename.endsWith('.css') ? 'text/css' : 'text/html');
    res.end(await fs.readFile(filename));
  } catch { res.writeHead(404).end(); }
});

(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    const origin = `http://127.0.0.1:${server.address().port}`;
    await fs.mkdir(output,{recursive:true});
    browser = await chromium.launchPersistentContext(path.join(output,'browser-profile'), { executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', headless:true, viewport:{width:1366,height:900} });
    const page = await browser.newPage();
    const errors=[]; page.on('pageerror', error=>errors.push(error.message));
    // Verify every SDK API/event used by the classroom against the vendored SDK.
    await page.goto(origin+'/live-class.html');
    assert.equal(await page.evaluate(()=>!!window.LivekitClient?.Room),true);
    assert.equal(await page.evaluate(()=>!!window.LivekitClient.VideoPresets.h360.resolution),true);
    const actualEvents=await page.evaluate(()=>window.LivekitClient.RoomEvent);
    for(const name of ['ParticipantNameChanged','ParticipantMetadataChanged','AudioPlaybackStatusChanged','LocalTrackUnpublished']) assert.ok(actualEvents[name],name);
    await page.route('**/vendor/livekit-client-2.23.0.min.js',route=>route.fulfill({contentType:'text/javascript',body:mockSdk}));
    await page.goto(origin+'/parent');
    const student=page.frameLocator('#room');
    await student.locator('#state').filter({hasText:'Connected'}).waitFor();
    assert.equal(await student.locator('#share').isVisible(),false);
    assert.equal(await student.locator('#mic').getAttribute('aria-pressed'),'false');
    await student.locator('#mic').click(); assert.equal(await student.locator('#mic').getAttribute('aria-pressed'),'true');
    await student.locator('#camera').click(); assert.equal(await student.locator('video').count(),1);
    await student.locator('#sound').click(); assert.equal(await student.locator('#sound').innerText(),'Sound enabled');
    assert.equal(await student.locator('#roster img').count(),0,'Participant names must remain text');
    await student.locator('#people-toggle').click(); assert.equal(await student.locator('#people').isVisible(),true);
    await student.locator('#leave').click(); await page.waitForFunction(()=>window.didLeave===true);
    await page.goto(origin+'/parent?teacher');
    const teacher=page.frameLocator('#room');
    await teacher.locator('#state').filter({hasText:'Connected'}).waitFor();
    assert.equal(await teacher.locator('#count').innerText(),'31 / 31');
    await teacher.locator('#share').click(); assert.equal(await teacher.locator('#screens video').count(),1);
    await teacher.locator('#share').click(); assert.equal(await teacher.locator('#screens video').count(),0);
    await fs.mkdir(output,{recursive:true});
    await page.screenshot({path:path.join(output,'classroom-desktop.png')});
    await page.setViewportSize({width:390,height:844});
    await page.screenshot({path:path.join(output,'classroom-mobile.png')});
    assert.equal(await page.locator('#room').evaluate(frame=>frame.contentDocument.documentElement.scrollWidth <= frame.clientWidth),true,'No horizontal overflow on mobile');
    assert.deepEqual(errors,[]);
    console.log('Passed: real SDK API checks; embedded role controls, mic/camera/screen toggles, sound, safe names, participant grid, leave cleanup and responsive layout with mocked media.');
  } finally { await browser?.close(); await new Promise(resolve=>server.close(resolve)); }
})().catch(error=>{console.error(error);process.exitCode=1;});
