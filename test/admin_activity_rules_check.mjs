import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const host=process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host??'',/^(127\.0\.0\.1|localhost):\d+$/,'Use a local emulator only');
const project='demo-caslms-school-check';
const database=`projects/${project}/databases/(default)`;
const base=`http://${host}/v1/${database}/documents`;
const rulesResponse=await fetch(`http://${host}/emulator/v1/projects/${project}:securityRules`,{
  method:'PUT',headers:{'Content-Type':'application/json'},
  body:JSON.stringify({rules:{files:[{name:'firestore.rules',content:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8')}]}}),
});
assert.equal(rulesResponse.status,200,await rulesResponse.text());
const cleared=await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});
assert.equal(cleared.status,200,await cleared.text());
let checks=0;
function value(v) {
  if(v instanceof Date)return {timestampValue:v.toISOString()};
  if(v===null)return {nullValue:null};
  if(typeof v==='boolean')return {booleanValue:v};
  if(Array.isArray(v))return {arrayValue:{values:v.map(value)}};
  if(typeof v==='number')return {integerValue:String(v)};
  return {stringValue:String(v)};
}
const fields=d=>Object.fromEntries(Object.entries(d).map(([k,v])=>[k,value(v)]));
function token(uid){const enc=v=>Buffer.from(JSON.stringify(v)).toString('base64url');const now=Math.floor(Date.now()/1000);
  return `${enc({alg:'none',typ:'JWT'})}.${enc({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,auth_time:1700000000,email:uid+'@example.com',email_verified:true,iat:now,exp:now+3600,firebase:{sign_in_provider:'password'}})}.`;}
async function seed(path,data){const r=await fetch(`${base}/${path}`,{method:'PATCH',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify({fields:fields(data)})});assert.equal(r.status,200,await r.text());}
const write=(path,data,timestamps=[])=>({update:{name:`${database}/documents/${path}`,fields:fields(data)},
  ...(timestamps.length?{updateTransforms:timestamps.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})});
async function commit(uid,writes,status,label){const r=await fetch(`${base}:commit`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({writes})});assert.equal(r.status,status,`${label}: ${await r.text()}`);checks++;}
async function get(uid,path,status){const r=await fetch(`${base}/${path}`,{headers:{Authorization:`Bearer ${token(uid)}`}});assert.equal(r.status,status,await r.clone().text());checks++;return r;}
for (const [uid,role] of [['admin','admin'],['teacher','instructor'],['other','instructor'],['student','student']]) {
  await seed('users/'+uid,{uid,role,status:'active',name:uid,email:uid+'@example.com',emailVerificationRequired:true});
}
const actor=(uid,role,type)=>({actorId:uid,actorName:uid,actorRole:role,type});
const login={...actor('student','student','login'),sessionAuthTime:1700000000};
await commit('student',[write('activityLogs/login_1700000000_student',login,['createdAt'])],200,'Successful sign-in recorded for the authenticated account');
await get('admin','activityLogs/login_1700000000_student',200);
await get('student','activityLogs/login_1700000000_student',403);
await get('teacher','activityLogs/login_1700000000_student',403);
await commit('student',[write('activityLogs/login_1700000000_student',login,['createdAt'])],403,'Duplicate session cannot overwrite history');
await commit('admin',[{...write('activityLogs/login_1700000000_student',{actorName:'forged'}),updateMask:{fieldPaths:['actorName']}}],403,'Admin cannot edit recorded history');
await commit('admin',[{delete:database+'/documents/activityLogs/login_1700000000_student'}],403,'Admin cannot delete activity history from the client');
const logout={...login,type:'logout'};
await commit('student',[write('activityLogs/logout_1700000000_student',{...logout,actorId:'teacher'},['createdAt'])],403,'Cannot impersonate another account');
await commit('student',[write('activityLogs/logout_1700000000_student',{...logout,actorRole:'admin'},['createdAt'])],403,'Cannot forge an administrator role');
await commit('student',[write('activityLogs/logout_1700000000_student',{...logout,actorName:'Someone else'},['createdAt'])],403,'Actor name must match the profile');
await commit('student',[write('activityLogs/login_1700000001_student',{...login,sessionAuthTime:1700000001},['createdAt'])],403,'Cannot invent an authentication session');
await commit('student',[write('activityLogs/arbitrary-id',logout,['createdAt'])],403,'Deterministic session IDs enforced');
await commit('student',[write('activityLogs/logout_1700000000_student',{...logout,password:'must never be stored'},['createdAt'])],403,'No password or unexpected fields allowed');
await commit('student',[write('activityLogs/logout_1700000000_student',{...logout,createdAt:new Date('2020-01-01T00:00:00Z')})],403,'Log time must be a server timestamp');
await commit('student',[write('activityLogs/logout_1700000000_student',logout,['createdAt'])],200,'Explicit logout request recorded independently');
const created=new Date('2026-01-01T00:00:00Z');
for(const id of ['c1','c2','c3'])await seed('courses/'+id,{instructorId:'teacher',title:'Course '+id,status:'active',classCode:id,createdAt:created});
const course=(id,uid='teacher')=>({...actor(uid,'instructor','course_created'),targetId:id,courseId:id,title:'Course '+id,occurredAt:created});
await commit('teacher',[write('activityLogs/course_created_c1',course('c1'),['createdAt'])],200,'Course creation bound to the real source and instructor');
await commit('other',[write('activityLogs/course_created_c2',course('c2','other'),['createdAt'])],403,'Another instructor cannot claim course creation');
await commit('teacher',[write('activityLogs/course_created_c2',{...course('c2'),title:'Invented course name'},['createdAt'])],403,'Source title cannot be fabricated');
await commit('teacher',[write('activityLogs/course_created_c2',{...course('c2'),occurredAt:new Date('2020-01-01T00:00:00Z')},['createdAt'])],403,'Source creation time cannot be fabricated');
await commit('teacher',[write('activityLogs/course_created_missing',course('missing'),['createdAt'])],403,'Missing course cannot produce a creation event');
await seed('courses/bad-owner',{instructorId:'student',title:'Course bad-owner',createdAt:created});
await commit('student',[write('activityLogs/course_created_bad-owner',{...course('bad-owner','student'),actorRole:'student'},['createdAt'])],403,'Student cannot emit instructor course events');
await seed('moduleResources/f1',{courseId:'c1',moduleId:'m1',createdBy:'teacher',title:'Lecture PDF',fileName:'lecture.pdf',deliveryType:'uploaded_file',status:'draft',createdAt:created});
await seed('moduleResources/link',{courseId:'c1',moduleId:'m1',createdBy:'teacher',title:'External link',deliveryType:'external_link',createdAt:created});
const upload={...actor('teacher','instructor','material_uploaded'),targetId:'f1',courseId:'c1',title:'Lecture PDF',occurredAt:created};
await commit('teacher',[write('activityLogs/material_uploaded_f1',{...upload,courseId:'c2'},['createdAt'])],403,'File event cannot claim a different course');
await commit('other',[write('activityLogs/material_uploaded_f1',{...upload,actorId:'other',actorName:'other'},['createdAt'])],403,'Uploader identity must match the source');
await commit('teacher',[write('activityLogs/material_uploaded_link',{...upload,targetId:'link',title:'External link'},['createdAt'])],403,'An external link is not a file-upload event');
await commit('teacher',[write('activityLogs/material_uploaded_f1',upload,['createdAt'])],200,'Instructor upload recorded with original resource ID');
await get('admin','moduleResources/f1',200);
await get('admin','activityLogs/material_uploaded_f1',200);
await commit('admin',[write('activityLogs/course_created_c3',{...course('c3','admin'),actorRole:'admin'},['createdAt'])],200,'Admin source event uses its actual administrator identity');
for(const [uid,expected] of [['admin',200],['teacher',403],['student',403]]) {
  const response=await fetch(base+':runQuery',{method:'POST',headers:{Authorization:'Bearer '+token(uid),'Content-Type':'application/json'},body:JSON.stringify({structuredQuery:{from:[{collectionId:'activityLogs'}],where:{fieldFilter:{field:{fieldPath:'type'},op:'EQUAL',value:{stringValue:'login'}}},orderBy:[{field:{fieldPath:'createdAt'},direction:'DESCENDING'}],limit:50}})});
  assert.equal(response.status,expected,await response.clone().text());checks++;
  if(expected===200) {const docs=(await response.json()).filter(r=>r.document);assert.equal(docs.length,1);assert.equal(docs[0].document.fields.type.stringValue,'login');checks++;}
}
const removed=await fetch(base+'/courses/c1',{method:'DELETE',headers:{Authorization:'Bearer owner'}});
assert.equal(removed.status,200);checks++;
await get('admin','activityLogs/course_created_c1',200);
console.log('Passed '+checks+' admin activity ownership, immutable history, source binding and log-category checks.');
