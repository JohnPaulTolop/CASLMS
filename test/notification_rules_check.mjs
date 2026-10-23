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
  return `${enc({alg:'none',typ:'JWT'})}.${enc({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,iat:now,exp:now+3600,firebase:{sign_in_provider:'password'}})}.`;}
async function seed(path,data){const r=await fetch(`${base}/${path}`,{method:'PATCH',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify({fields:fields(data)})});assert.equal(r.status,200,await r.text());}
const write=(path,data,timestamps=[])=>({update:{name:`${database}/documents/${path}`,fields:fields(data)},
  ...(timestamps.length?{updateTransforms:timestamps.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})});
async function commit(uid,writes,status,label){const r=await fetch(`${base}:commit`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({writes})});assert.equal(r.status,status,`${label}: ${await r.text()}`);checks++;}
async function get(uid,path,status){const r=await fetch(`${base}/${path}`,{headers:{Authorization:`Bearer ${token(uid)}`}});assert.equal(r.status,status,await r.clone().text());checks++;return r;}
await seed('users/nt',{role:'instructor',status:'active'});
await seed('users/ns',{role:'student',status:'active'});
await seed('users/nother',{role:'student',status:'active'});
await seed('courses/nc',{instructorId:'nt',status:'active',classCode:'A'});
await seed('enrollments/nc_ns',{courseId:'nc',studentId:'ns',status:'active',sectionId:'A'});
await seed('enrollments/nc_nother',{courseId:'nc',studentId:'nother',status:'active',sectionId:'B'});
const enroll={userId:'ns',type:'course_enrollment',sourceType:'enrollment',sourceId:'nc_ns',actorId:'ns',title:'Course enrollment confirmed',message:'Open your enrolled course.',courseId:'nc',isRead:false,readAt:null};
await commit('ns',[write('notifications/enrollment_nc_ns',enroll,['createdAt'])],200,'Own active enrollment shortcut');
await get('nother','notifications/enrollment_nc_ns',403);
const unread=await get('ns','notifications/enrollment_nc_ns',200);
assert.equal((await unread.json()).fields.isRead.booleanValue,false,'Reading inbox must not mark notices read');checks++;
await commit('ns',[{...write('notifications/enrollment_nc_ns',{isRead:true},['readAt']),updateMask:{fieldPaths:['isRead']}}],200,'Read only one notice');
await commit('ns',[{...write('notifications/enrollment_nc_ns',{sourceId:'foreign'}),updateMask:{fieldPaths:['sourceId']}}],403,'Cannot change navigation target');
await commit('nother',[write('notifications/enrollment_nc_ns',{...enroll,actorId:'nother'},['createdAt'])],403,'Cannot forge another student enrollment notice');
await seed('conversations/nc_nt_ns',{courseId:'nc',instructorId:'nt',studentId:'ns',participantIds:['nt','ns']});
const messageNotice={userId:'nt',type:'message',sourceType:'conversation',sourceId:'nc_nt_ns',messageId:'nm1',actorId:'ns',title:'New message',message:'Open your conversation to read the message.',courseId:'nc',isRead:false,readAt:null};
await commit('ns',[
  write('conversations/nc_nt_ns/messages/nm1',{senderId:'ns',receiverId:'nt',text:'Hello',isRead:false},['sentAt']),
  write('notifications/message_nm1_nt',messageNotice,['createdAt']),
],200,'Message + exact conversation notice atomically');
await commit('ns',[write('notifications/message_fake_nt',{...messageNotice,messageId:'fake'},['createdAt'])],403,'Notification needs a real new message');
await commit('nother',[write('notifications/message_nm2_nt',{...messageNotice,messageId:'nm2',actorId:'nother'},['createdAt'])],403,'Outsider cannot forge message notice');
await seed('modules/nm',{courseId:'nc',title:'Module',status:'published'});
await seed('assessments/na',{courseId:'nc',moduleId:'nm',sectionId:'A',status:'published',assessmentType:'activity',deliveryType:'external_link',title:'Activity'});
const assessmentNotice={userId:'ns',type:'assessment',sourceType:'assessment',sourceId:'na',title:'New activity',message:'Activity posted',courseId:'nc',authorizationCourseId:'nc',courseCode:'IT',courseTitle:'Course',moduleId:'nm',activityType:'activity',actorId:'nt',actorName:'Teacher',priority:'normal',isUrgent:false,isRead:false,readAt:null};
await commit('nt',[write('notifications/assessment_na_ns',assessmentNotice,['createdAt'])],200,'Section A receives its activity');
await commit('nt',[write('notifications/assessment_na_nother',{...assessmentNotice,userId:'nother'},['createdAt'])],403,'Section B never receives Section A activity');
await commit('nt',[write('notifications/assessment_na_ns',assessmentNotice,['createdAt'])],403,'Stable IDs cannot overwrite existing notice');
await seed('assessments/draft',{courseId:'nc',moduleId:'nm',sectionId:'A',status:'draft',title:'Draft'});
await commit('nt',[write('notifications/assessment_draft_ns',{...assessmentNotice,sourceId:'draft'},['createdAt'])],403,'Draft never notifies students');
await seed('assignments/nlegacy',{courseId:'nc',title:'Legacy task',points:10});
const received={userId:'nt',type:'submission',sourceType:'submissionReceived',sourceId:'nl1',actorId:'ns',title:'New assessment submission',message:'A student submitted work. Open this notification to review it.',courseId:'nc',isRead:false,readAt:null};
await commit('ns',[
  write('submissions/nl1',{assignmentId:'nlegacy',courseId:'nc',studentId:'ns',answerText:'Answer',status:'submitted',score:0,feedback:''},['submittedAt']),
  write('notifications/submissionReceived_nl1_nt',received,['createdAt']),
],200,'Exact legacy submission and instructor receipt atomically');
await commit('ns',[write('notifications/submissionReceived_fake_nt',{...received,sourceId:'fake'},['createdAt'])],403,'No fabricated submission shortcut');
await seed('courses/foreign',{instructorId:'nt',status:'active'});
await seed('assignments/foreign',{courseId:'foreign',title:'Other course'});
await commit('ns',[
  write('submissions/nl2',{assignmentId:'foreign',courseId:'foreign',studentId:'ns',status:'submitted'},['submittedAt']),
  write('notifications/submissionReceived_nl2_nt',{...received,sourceId:'nl2',courseId:'foreign'},['createdAt']),
],403,'No instructor receipt from an unenrolled student');
await commit('nt',[write('notifications/course_nc_ns',{...assessmentNotice,type:'course',sourceType:'course',sourceId:'nc',moduleId:''},['createdAt'])],200,'Course publication targets only enrolled students');
await seed('notifications/missing',{userId:'ns',sourceType:'assessment',sourceId:'deleted',isRead:false});
await get('ns','notifications/missing',200);
await get('ns','assessments/deleted',403); // Rules conceal missing protected targets as denied.
await seed('semesterGrades/secret',{studentId:'ns',posted:true,encrypted:'secret'});
await get('ns','semesterGrades/secret',403);
console.log(`Passed ${checks} notification ownership, atomic-message, section, deduplication and grade-privacy checks.`);
