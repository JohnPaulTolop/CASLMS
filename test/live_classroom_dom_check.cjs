const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { JSDOM, VirtualConsole } = require('../.dart_tool/live-class-validation/node_modules/jsdom');
const root = path.resolve(__dirname, '../web');
const mock = `(() => {
  const events = Object.fromEntries(['ParticipantConnected','ParticipantDisconnected','TrackSubscribed','TrackUnsubscribed','TrackMuted','TrackUnmuted','LocalTrackPublished','LocalTrackUnpublished','ActiveSpeakersChanged','ParticipantNameChanged','ParticipantMetadataChanged','Reconnecting','Reconnected','AudioPlaybackStatusChanged','Disconnected'].map(n=>[n,n]));
  class Participant {
    constructor(id,name,role) {Object.assign(this,{identity:id,name,metadata:JSON.stringify({role}),isCameraEnabled:false,isMicrophoneEnabled:false,isScreenShareEnabled:false,audioTrackPublications:new Map()});this.camera={attach:e=>e,detach:()=>{}};this.screen={attach:e=>e,detach:()=>{}};}
    getTrackPublication(source) {if(source==='camera'&&this.isCameraEnabled)return {track:this.camera};if(source==='screen'&&this.isScreenShareEnabled)return {track:this.screen};}
    async setMicrophoneEnabled(v) {this.isMicrophoneEnabled=v;}
    async setCameraEnabled(v) {this.isCameraEnabled=v;}
    async setScreenShareEnabled(v) {this.isScreenShareEnabled=v;}
  }
  class Room {
    constructor() {this.listeners=new Map();this.state='disconnected';this.localParticipant=new Participant('uid','My name','student');this.remoteParticipants=new Map([['teacher',new Participant('teacher','<img src=x onerror=alert(1)>','instructor')]]);window.testRoom=this;}
    on(name,fn) {if(!name)throw Error('Invalid event');const items=this.listeners.get(name)||[];items.push(fn);this.listeners.set(name,items);return this;}
    emit(name) {for(const fn of this.listeners.get(name)||[])fn();}
    async connect(url,token) {this.state='connected';window.testToken=token;}
    async startAudio() {this.canPlaybackAudio=true;}
    async disconnect() {this.state='disconnected';this.emit('Disconnected');}
  }
  window.LivekitClient={Room,RoomEvent:events,Track:{Source:{Camera:'camera',ScreenShare:'screen'}},VideoPresets:{h360:{resolution:{width:640,height:360}}}};
})();`;
const tick = () => new Promise(resolve=>setImmediate(resolve));

(async () => {
  const html=(await fs.readFile(path.join(root,'live-class.html'),'utf8')).replace(/<script[^>]*src=[^>]*><\/script>/g,'');
  const source=await fs.readFile(path.join(root,'live-class.js'),'utf8');
  const css=await fs.readFile(path.join(root,'live-class.css'),'utf8');
  const sdk=await fs.readFile(path.join(root,'vendor/livekit-client-2.23.0.min.js'),'utf8');
  const errors=[];
  const virtualConsole=new VirtualConsole();virtualConsole.on('jsdomError',error=>errors.push(error.message));
  for(const instructor of [false,true]) {
    const dom=new JSDOM(html,{url:'https://lms.example/live-class.html',runScripts:'outside-only',virtualConsole});
    try {
      const w=dom.window;w.TextEncoder=TextEncoder;w.TextDecoder=TextDecoder;
      const style=w.document.createElement('style');style.textContent=css;w.document.head.append(style);
      // The real vendored bundle must expose all APIs referenced by our UI.
      w.eval(sdk);
      assert.ok(w.LivekitClient.Room);
      assert.ok(w.LivekitClient.VideoPresets.h360.resolution);
      for(const event of ['ParticipantNameChanged','ParticipantMetadataChanged','LocalTrackUnpublished','AudioPlaybackStatusChanged'])assert.ok(w.LivekitClient.RoomEvent[event],event);
      const sent=[];const parent={postMessage:message=>sent.push(JSON.parse(message))};
      Object.defineProperty(w,'parent',{value:parent});
      w.eval(mock);w.eval(source);
      assert.equal(sent[0].type,'ready');
      const connect={source:'cas-lms',type:'connect',url:'wss://test.livekit.cloud',token:'temporary-token',title:'Live IT class',instructor};
      // Reject both a different origin and a same-origin sibling frame.
      w.dispatchEvent(new w.MessageEvent('message',{origin:'https://attacker.example',source:parent,data:JSON.stringify(connect)}));
      w.dispatchEvent(new w.MessageEvent('message',{origin:w.location.origin,source:{},data:JSON.stringify(connect)}));
      assert.equal(w.testRoom,undefined);
      w.dispatchEvent(new w.MessageEvent('message',{origin:w.location.origin,source:parent,data:JSON.stringify(connect)}));
      await tick();
      const $=id=>w.document.getElementById(id);
      assert.equal($('state').textContent,'Connected');
      assert.equal($('share').hidden,!instructor);
      assert.equal($('mic').getAttribute('aria-pressed'),'false');
      assert.equal($('camera').getAttribute('aria-pressed'),'false');
      $('mic').click();await tick();assert.equal($('mic').getAttribute('aria-pressed'),'true');
      $('camera').click();await tick();assert.equal(w.document.querySelectorAll('video').length,1);
      $('sound').click();await tick();assert.equal($('sound').textContent,'Sound enabled');
      assert.equal(w.document.querySelectorAll('#roster img').length,0);
      assert.ok($('roster').textContent.includes('<img src=x'));
      $('people-toggle').click();assert.equal($('people').hidden,false);
      if(instructor) {
        $('share').click();await tick();assert.equal(w.document.querySelectorAll('#screens video').length,1);
        $('share').click();await tick();assert.equal(w.document.querySelectorAll('#screens video').length,0);
      }
      // Device failures leave a usable room and a readable message.
      w.testRoom.localParticipant.setMicrophoneEnabled=async()=>{throw Error('permission denied');};
      $('mic').click();await tick();assert.match($('notice').textContent,/permissions/);assert.equal($('mic').disabled,false);
      $('leave').click();await tick();assert.equal(sent.at(-1).type,'leave');
      assert.equal(w.document.querySelectorAll('video').length,0);
    } finally {dom.window.close();}
  }
  assert.deepEqual(errors,[]);
  console.log('Passed: real SDK API checks, trusted iframe messages, student/instructor controls, camera/mic/screen toggles, audio unlock, safe participant names, denied devices and leave cleanup (simulated media DOM).');
})().catch(error=>{console.error(error);process.exitCode=1;});
