import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/, 'Use the local Firestore emulator.');
const project = 'demo-caslms-student-role';
const database = `projects/${project}/databases/(default)`;
const base = `http://${host}/v1/${database}/documents`;

const rulesText = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const rulesResponse = await fetch(`http://${host}/emulator/v1/projects/${project}:securityRules`, {
  method: 'PUT',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({rules: {files: [{name: 'firestore.rules', content: rulesText}]}}),
});
assert.equal(rulesResponse.status, 200, await rulesResponse.text());
await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`, {method: 'DELETE'});

function value(item) {
  if (typeof item === 'boolean') return {booleanValue: item};
  return {stringValue: String(item)};
}
const fields = (data) => Object.fromEntries(Object.entries(data).map(([key, item]) => [key, value(item)]));
function token(uid, email) {
  const encode = (data) => Buffer.from(JSON.stringify(data)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({
    iss: `https://securetoken.google.com/${project}`,
    aud: project,
    sub: uid,
    user_id: uid,
    email,
    email_verified: true,
    iat: now,
    exp: now + 3600,
    firebase: {sign_in_provider: 'password'},
  })}.`;
}
async function seed(path, data) {
  const response = await fetch(`${base}/${path}`, {
    method: 'PATCH',
    headers: {Authorization: 'Bearer owner', 'Content-Type': 'application/json'},
    body: JSON.stringify({fields: fields(data)}),
  });
  assert.equal(response.status, 200, await response.text());
}
async function get(uid, email, path, expected, label) {
  const response = await fetch(`${base}/${path}`, {headers: {Authorization: `Bearer ${token(uid, email)}`}});
  assert.equal(response.status, expected, `${label}: ${await response.text()}`);
}

await seed('users/student', {
  uid: 'student',
  role: 'student',
  status: 'active',
  email: 'student@example.com',
  authEmail: '123456@caslms.app',
  emailVerificationRequired: true,
});
await seed('users/legacy', {
  uid: 'legacy',
  role: 'Student',
  status: 'Active',
  email: 'legacy@example.com',
  emailVerificationRequired: true,
});
await seed('courses/course', {status: 'active', instructorId: 'teacher', classCode: '4C'});
await seed('enrollments/course_student', {courseId: 'course', studentId: 'student', sectionId: '4C', status: 'active'});
await seed('users/student/personalNotes/note', {ownerId: 'student', title: 'Note', content: 'Private'});

await get('student', 'student@example.com', 'courses/course', 200,
  'verified student remains active when legacy authEmail is stale');
await get('student', 'student@example.com', 'enrollments/course_student', 200,
  'student reads own enrollment');
await get('student', 'student@example.com', 'users/student/personalNotes/note', 200,
  'student reads own private note');
await get('legacy', 'legacy@example.com', 'courses/course', 200,
  'legacy role and status capitalization remains supported');
await get('student', 'other@example.com', 'courses/course', 403,
  'unmatched verified email is denied');

console.log('Passed 5 student-role permission checks.');
