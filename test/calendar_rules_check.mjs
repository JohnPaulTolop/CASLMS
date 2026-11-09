import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/, 'Use a local emulator only');
const project = 'demo-caslms-calendar-check';
const database = `projects/${project}/databases/(default)`;
const base = `http://${host}/v1/${database}/documents`;
let checks = 0;
const baseRules = readFileSync(new URL('../firestore.rules',import.meta.url),'utf8');
const calendarRules = readFileSync(new URL('../docs/calendar-events.rules',import.meta.url),'utf8');
const testRules = baseRules.includes('match /calendarEvents/') ? baseRules : baseRules.replace('    match /{document=**} {', calendarRules + '\n    match /{document=**} {');
const rules = await fetch(`http://${host}/emulator/v1/projects/${project}:securityRules`, { method: 'PUT', headers: {'Content-Type':'application/json'}, body: JSON.stringify({rules:{files:[{name:'firestore.rules', content:testRules}]}}) });
assert.equal(rules.status,200,await rules.text());
await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`, {method:'DELETE'});
function value(v) {
  if (v instanceof Date) return {timestampValue:v.toISOString()};
  if (typeof v === 'boolean') return {booleanValue:v};
  return {stringValue:String(v)};
}
const fields = data => Object.fromEntries(Object.entries(data).map(([k,v])=>[k,value(v)]));
function token(uid) {
  const enc = value => Buffer.from(JSON.stringify(value)).toString('base64url'); const now = Math.floor(Date.now()/1000);
  return `${enc({alg:'none',typ:'JWT'})}.${enc({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,iat:now,exp:now+3600,firebase:{sign_in_provider:'password'}})}.`;
}
async function seed(path,data) {
  const response = await fetch(`${base}/${path}`,{method:'PATCH',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify({fields:fields(data)})});
  assert.equal(response.status,200,await response.text());
}
async function commit(uid,writes,status,label) {
  const response = await fetch(`${base}:commit`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({writes})});
  assert.equal(response.status,status,`${label}: ${await response.text()}`); checks++;
}
const create = (id,data) => ({update:{name:`${database}/documents/calendarEvents/${id}`,fields:fields(data)},
  updateTransforms:['createdAt','updatedAt'].map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))});
const update = (id,data) => ({update:{name:`${database}/documents/calendarEvents/${id}`,fields:fields(data)}, updateMask:{fieldPaths:Object.keys(data)}, updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]});
async function get(uid,id,status) {
  const response = await fetch(`${base}/calendarEvents/${id}`,{headers:{Authorization:`Bearer ${token(uid)}`}});
  assert.equal(response.status,status,await response.text()); checks++;
}
async function query(uid,courseId,status) {
  const structuredQuery = {from:[{collectionId:'calendarEvents'}], ...(courseId !== null ? {where:{fieldFilter:{field:{fieldPath:'courseId'},op:'EQUAL',value:{stringValue:courseId}}}} : {})};
  const response = await fetch(`${base}:runQuery`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({structuredQuery})});
  assert.equal(response.status,status,await response.text()); checks++;
}
for (const [uid,role,status] of [['admin','admin','active'],['teacher','instructor','active'],['other','instructor','active'],['student','student','active'],['foreign','student','active'],['inactive','instructor','inactive']]) await seed(`users/${uid}`,{role,status});
await seed('courses/course',{instructorId:'teacher',status:'active'});
await seed('courses/foreign',{instructorId:'other',status:'active'});
await seed('enrollments/course_student',{courseId:'course',studentId:'student',status:'active'});
await seed('enrollments/foreign_foreign',{courseId:'foreign',studentId:'foreign',status:'active'});
const event = {title:'Class workshop',description:'Bring your notes',courseId:'course',ownerId:'teacher',creatorRole:'instructor',allDay:false,startAt:new Date('2026-11-06T01:00:00Z'),endAt:new Date('2026-11-06T02:00:00Z')};
await commit('teacher',[create('owned',event)],200,'Owner creates class event');
await commit('other',[create('foreign',{...event,ownerId:'other'})],403,'Other teacher cannot publish into foreign course');
await commit('teacher',[create('wide',{...event,courseId:''})],403,'Teacher cannot publish schoolwide');
await commit('student',[create('student',{...event,ownerId:'student',creatorRole:'student'})],403,'Student cannot create event');
await commit('inactive',[create('inactive',{...event,ownerId:'inactive'})],403,'Inactive teacher cannot create event');
await commit('admin',[create('schoolwide',{...event,courseId:'',ownerId:'admin',creatorRole:'admin'})],200,'Admin publishes schoolwide');
await commit('other',[create('other-event',{...event,courseId:'foreign',ownerId:'other'})],200,'Other teacher publishes own course');
await get('student','owned',200); await get('student','schoolwide',200); await get('student','other-event',403);
await get('teacher','other-event',403); await get('foreign','owned',403); await get('admin','other-event',200);
await query('student','',200); await query('student','course',200); await query('student','foreign',403); await query('student',null,403); await query('admin',null,200);
await commit('teacher',[update('owned',{title:'Updated workshop'})],200,'Owner edits event');
await commit('teacher',[update('owned',{ownerId:'other'})],403,'Owner cannot be reassigned');
await commit('teacher',[update('owned',{courseId:'foreign'})],403,'Cannot move into foreign course');
await commit('other',[update('owned',{title:'Hijacked'})],403,'Other teacher cannot edit');
await commit('admin',[update('owned',{title:'Admin corrected title'})],200,'Admin can moderate event');
for (const [name,change] of [['reversed',{endAt:new Date('2026-11-05T00:00:00Z')}],['long',{title:'x'.repeat(121)}],['span',{endAt:new Date('2027-01-01T00:00:00Z')}],['extra',{secret:'forbidden'}],['forged',{creatorRole:'admin'}]]) await commit('teacher',[create(name,{...event,...change})],403,`Reject ${name}`);
await seed('enrollments/course_student',{courseId:'course',studentId:'student',status:'inactive'});
await get('student','owned',403); await query('student','course',403);
await commit('student',[{delete:`${database}/documents/calendarEvents/owned`}],403,'Student cannot delete');
await commit('other',[{delete:`${database}/documents/calendarEvents/owned`}],403,'Other teacher cannot delete');
await commit('teacher',[{delete:`${database}/documents/calendarEvents/owned`}],200,'Owner can delete');
await commit('admin',[{delete:`${database}/documents/calendarEvents/other-event`}],200,'Admin can delete');
console.log(`Passed ${checks} calendar permission and validation checks.`);
