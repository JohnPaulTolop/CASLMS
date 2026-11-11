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
const value=v=>typeof v==='number'?{integerValue:String(v)}:{stringValue:String(v)};
const fields=data=>Object.fromEntries(Object.entries(data).map(([key,item])=>[key,value(item)]));
function token(uid){
  const encode=item=>Buffer.from(JSON.stringify(item)).toString('base64url');
  const now=Math.floor(Date.now()/1000);
  return `${encode({alg:'none',typ:'JWT'})}.${encode({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,auth_time:1700000000,iat:now,exp:now+3600,firebase:{sign_in_provider:'password'}})}.`;
}
async function seed(path,data){
  const response=await fetch(`${base}/${path}`,{method:'PATCH',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify({fields:fields(data)})});
  assert.equal(response.status,200,await response.text());
}
async function get(uid,path,status){
  const response=await fetch(`${base}/${path}`,{headers:{Authorization:`Bearer ${token(uid)}`}});
  assert.equal(response.status,status,await response.clone().text());
  checks++;
}
async function create(uid,path,data,status){
  const response=await fetch(`${base}:commit`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({writes:[{update:{name:`${database}/documents/${path}`,fields:fields(data)}}]})});
  assert.equal(response.status,status,await response.text());
  checks++;
}

for(const [uid,role] of [['admin','admin'],['teacher','instructor'],['student','student']]){
  await seed(`users/${uid}`,{uid,role,status:'active',name:uid});
}
await seed('activityLogs/legacy-login',{type:'login',actorId:'student',actorName:'student',actorRole:'student',createdAt:'2026-11-11T00:00:00.000Z'});

for(const uid of ['admin','teacher','student']){
  await get(uid,'activityLogs/legacy-login',403);
  await create(uid,`activityLogs/client-${uid}`,{type:'login',actorId:uid},403);
  const query=await fetch(`${base}:runQuery`,{method:'POST',headers:{Authorization:`Bearer ${token(uid)}`,'Content-Type':'application/json'},body:JSON.stringify({structuredQuery:{from:[{collectionId:'activityLogs'}],limit:10}})});
  assert.equal(query.status,403,await query.clone().text());
  checks++;
}

console.log(`Passed ${checks} legacy activity-log client-denial checks.`);
