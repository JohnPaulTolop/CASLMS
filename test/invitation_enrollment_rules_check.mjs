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
  if(v===null)return {nullValue:null};
  if(typeof v==='boolean')return {booleanValue:v};
  if(Array.isArray(v))return {arrayValue:{values:v.map(value)}};
  if(typeof v==='number')return {integerValue:String(v)};
  return {stringValue:String(v)};
}
const fields=d=>Object.fromEntries(Object.entries(d).map(([k,v])=>[k,value(v)]));
function token(uid){const enc=v=>Buffer.from(JSON.stringify(v)).toString('base64url');const now=Math.floor(Date.now()/1000);
  return `${enc({alg:'none',typ:'JWT'})}.${enc({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,email:uid+'@example.com',email_verified:true,iat:now,exp:now+3600,firebase:{sign_in_provider:'password'}})}.`;}
async function seed(path,data){const r=await fetch(`${base}/${path}`,{method:'PATCH',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify({fields:fields(data)})});assert.equal(r.status,200,await r.text());}
const write=(path,data,timestamps=[])=>({update:{name:`${database}/documents/${path}`,fields:fields(data)},
  ...(timestamps.length?{updateTransforms:timestamps.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})});
async function commit(uid,writes,status,label){const r=await fetch(`${base}:commit`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({writes})});assert.equal(r.status,status,`${label}: ${await r.text()}`);checks++;}
async function get(uid,path,status){const r=await fetch(`${base}/${path}`,{headers:{Authorization:`Bearer ${token(uid)}`}});assert.equal(r.status,status,await r.clone().text());checks++;return r;}

for (const [uid, role, universityId] of [['it','instructor','90000'],['is1','student','10001'],['is2','student','10002'],['is3','student','10003'],['foreign','instructor','90001']]) {
  await seed('users/'+uid,{uid,role,status:'active',universityId,email:uid+'@example.com',emailVerificationRequired:true});
}
await seed('courses/ic',{instructorId:'it',status:'active',classCode:'ORIGINAL'});
await seed('courses/foreign',{instructorId:'foreign',status:'active',classCode:'FOREIGN'});
await seed('courseSections/SECOND',{courseId:'ic',instructorId:'it',status:'active',name:'Section Two'});
await seed('courseSections/FOREIGN',{courseId:'foreign',instructorId:'foreign',status:'active'});
const invitation=(studentId,studentCampusId,sectionId)=>({courseId:'ic',courseCode:'IT101',courseTitle:'Programming',instructorId:'it',instructorName:'Teacher',studentId,studentCampusId,studentName:'Student',studentEmail:'student@example.com',status:'pending',respondedAt:null,...(sectionId?{sectionId,sectionName:'Section Two'}:{})});
const invite=(uid,campus,section)=>write('courseInvitations/ic_'+uid,invitation(uid,campus,section),['createdAt','updatedAt']);
const enrollment=(uid,campus,section)=>({courseId:'ic',studentId:uid,studentName:'Student',studentCampusId:campus,sectionId:section,status:'active',enrollmentSource:'instructor_invitation',invitationId:'ic_'+uid,invitedBy:'it'});
const response=(uid,status='accepted')=>({...write('courseInvitations/ic_'+uid,{status},['updatedAt','respondedAt']),updateMask:{fieldPaths:['status']}});
const accept=(uid,campus,section)=>[write('enrollments/ic_'+uid,enrollment(uid,campus,section),['enrolledAt','acceptedAt']),response(uid)];
await commit('it',[invite('is1','10001','SECOND')],200,'Instructor invites to exact new section');
await commit('foreign',[invite('is2','10002','SECOND')],403,'Other instructor cannot invite into course');
await commit('it',[invite('is2','10002','FOREIGN')],403,'No cross-course section invitation');
await get('is1','enrollments/ic_is1',404);
await get('is1','courseSections/SECOND',200);
await commit('is2',accept('is1','10001','SECOND'),403,'Only invitation recipient accepts');
await commit('is1',accept('is1','10001','ORIGINAL'),403,'Recipient cannot change invitation section');
await commit('is1',[response('is1')],403,'Invitation cannot accept without membership');
await commit('is1',[write('enrollments/ic_is1',enrollment('is1','10001','SECOND'),['enrolledAt','acceptedAt'])],403,'Membership cannot activate without atomic acceptance');
await commit('is1',accept('is1','10001','SECOND'),200,'Accept invitation into exact section atomically');
const member=await get('is1','enrollments/ic_is1',200);
assert.equal((await member.json()).fields.sectionId.stringValue,'SECOND');checks++;
await commit('is1',accept('is1','10001','SECOND'),403,'Used invitation cannot create a fresh enrollment');
await commit('is1',[write('notifications/bad_receipt',{userId:'is1',sourceId:'bad'})],403,'Invalid optional notification fails independently');
await get('is1','enrollments/ic_is1',200);
await commit('is2',[write('enrollments/ic_is2',{courseId:'ic',studentId:'is2',studentName:'Student',studentCampusId:'10002',sectionId:'SECOND',status:'active',enrollmentSource:'section_code'},['enrolledAt'])],403,'Known section code never grants membership');
await commit('it',[invite('is2','10002')],200,'Legacy invitation without section remains valid');
await commit('is2',accept('is2','10002','ORIGINAL'),200,'Legacy invitation resolves original section');
await commit('it',[invite('is3','10003','SECOND')],200,'Invite third student');
await seed('courseSections/SECOND',{courseId:'ic',instructorId:'it',status:'archived',name:'Section Two'});
await commit('is3',accept('is3','10003','SECOND'),403,'Archived section cannot accept');
await commit('is3',[response('is3','declined')],200,'Recipient can decline unavailable section');
await seed('courseSections/SECOND',{courseId:'ic',instructorId:'it',status:'active',name:'Section Two'});
await commit('it',[{...write('courseInvitations/ic_is3',{sectionId:'ORIGINAL',sectionName:'Original Section',status:'pending',respondedAt:null},['createdAt','updatedAt']),updateMask:{fieldPaths:['sectionId','sectionName','status','respondedAt']}}],200,'Instructor can reissue declined invitation to chosen section');
await seed('enrollments/ic_is3',{...enrollment('is3','10003','SECOND'),status:'inactive',oldField:'legacy metadata'});
await commit('is3',accept('is3','10003','ORIGINAL'),200,'Clean enrollment replacement restores inactive legacy membership');
await seed('courseInvitations/ic_is1',{...invitation('is1','10001','ORIGINAL'),createdAt:'legacy-created'});
await commit('is1',accept('is1','10001','ORIGINAL'),403,'Active student cannot self transfer via another invitation');
await commit('it',[{...write('enrollments/ic_is1',{sectionId:'ORIGINAL'}),updateMask:{fieldPaths:['sectionId']}}],200,'Instructor can transfer an existing student');
await seed('courseInvitations/ic_is1',{...invitation('is1','10001','ORIGINAL'),createdAt:'existing-invitation'});
const before=await get('is1','enrollments/ic_is1',200);
const savedFields=(await before.json()).fields;
const preserved=write('enrollments/ic_is1',enrollment('is1','10001','ORIGINAL'),['acceptedAt']);
preserved.update.fields.enrolledAt=savedFields.enrolledAt;
await commit('is1',[preserved,response('is1')],200,'Existing same-section membership retains original join date');
const after=await get('is1','enrollments/ic_is1',200);
assert.deepEqual((await after.json()).fields.enrolledAt,savedFields.enrolledAt);checks++;
console.log('Passed '+checks+' invitation and invitation-only enrollment checks.');
