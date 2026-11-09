import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/, 'Use a local emulator only.');
const project = 'demo-caslms-notes-meeting-chat';
const database = `projects/${project}/databases/(default)`;
const base = `http://${host}/v1/${database}/documents`;
let checks = 0;

const rulesText = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const rulesResponse = await fetch(`http://${host}/emulator/v1/projects/${project}:securityRules`, {
  method: 'PUT',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({rules: {files: [{name: 'firestore.rules', content: rulesText}]}}),
});
assert.equal(rulesResponse.status, 200, await rulesResponse.text());
await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`, {method: 'DELETE'});

function value(item) {
  if (item === null) return {nullValue: null};
  if (item instanceof Date) return {timestampValue: item.toISOString()};
  if (Array.isArray(item)) return {arrayValue: {values: item.map(value)}};
  if (typeof item === 'boolean') return {booleanValue: item};
  if (typeof item === 'number') return {integerValue: String(item)};
  if (typeof item === 'object') return {mapValue: {fields: fields(item)}};
  return {stringValue: String(item)};
}
function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, item]) => [key, value(item)]));
}
function token(uid) {
  const encode = (data) => Buffer.from(JSON.stringify(data)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({
    iss: `https://securetoken.google.com/${project}`,
    aud: project,
    sub: uid,
    user_id: uid,
    email: `${uid}@example.com`,
    email_verified: true,
    auth_time: now,
    iat: now,
    exp: now + 3600,
    firebase: {sign_in_provider: 'password', identities: {}},
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
async function commit(uid, writes, expected, label) {
  const response = await fetch(`${base}:commit`, {
    method: 'POST',
    headers: {Authorization: `Bearer ${token(uid)}`, 'Content-Type': 'application/json'},
    body: JSON.stringify({writes}),
  });
  assert.equal(response.status, expected, `${label}: ${await response.text()}`);
  checks += 1;
}
async function get(uid, path, expected, label) {
  const response = await fetch(`${base}/${path}`, {headers: {Authorization: `Bearer ${token(uid)}`}});
  assert.equal(response.status, expected, `${label}: ${await response.text()}`);
  checks += 1;
}
function create(path, data, timestampFields) {
  return {
    update: {name: `${database}/documents/${path}`, fields: fields(data)},
    updateTransforms: timestampFields.map((fieldPath) => ({fieldPath, setToServerValue: 'REQUEST_TIME'})),
  };
}
function update(path, data, timestampFields = []) {
  return {
    update: {name: `${database}/documents/${path}`, fields: fields(data)},
    updateMask: {fieldPaths: Object.keys(data)},
    updateTransforms: timestampFields.map((fieldPath) => ({fieldPath, setToServerValue: 'REQUEST_TIME'})),
  };
}

for (const [uid, role, name] of [
  ['student', 'student', 'Student One'],
  ['other', 'student', 'Student Two'],
  ['foreign', 'student', 'Student Three'],
  ['teacher', 'instructor', 'Teacher One'],
  ['admin', 'admin', 'Administrator'],
]) {
  await seed(`users/${uid}`, {uid, role, name, status: 'active', email: `${uid}@example.com`});
}
await seed('courses/course', {instructorId: 'teacher', status: 'active', classCode: '4C'});
await seed('courseSections/4C', {courseId: 'course', instructorId: 'teacher', status: 'active'});
await seed('courseSections/4D', {courseId: 'course', instructorId: 'teacher', status: 'active'});
await seed('enrollments/course_student', {courseId: 'course', studentId: 'student', sectionId: '4C', status: 'active'});
await seed('enrollments/course_other', {courseId: 'course', studentId: 'other', sectionId: '4C', status: 'active'});
await seed('enrollments/course_foreign', {courseId: 'course', studentId: 'foreign', sectionId: '4D', status: 'active'});

const notePath = 'users/student/personalNotes/note1';
const note = {ownerId: 'student', title: 'My reminder', content: 'Review module three.'};
await commit('student', [create(notePath, note, ['createdAt', 'updatedAt'])], 200, 'student creates own private note');
await get('student', notePath, 200, 'owner reads private note');
await get('other', notePath, 403, 'other student cannot read private note');
await get('teacher', notePath, 403, 'instructor cannot read private note');
await get('admin', notePath, 403, 'administrator cannot read private note');
await commit('student', [update(notePath, {title: 'Updated reminder'}, ['updatedAt'])], 200, 'owner edits note');
await commit('student', [update(notePath, {ownerId: 'other'}, ['updatedAt'])], 403, 'owner cannot transfer note ownership');
await commit('other', [create('users/student/personalNotes/forged', {...note, ownerId: 'other'}, ['createdAt', 'updatedAt'])], 403, 'student cannot write below another profile');

await seed('liveClasses/live1', {
  courseId: 'course', sectionId: '4C', sessionId: 'session1', status: 'live',
  instructorId: 'teacher', studentIds: ['student'],
});
const messagePath = 'meetingMessages/student_1234567890123';
const message = {
  liveClassId: 'live1', courseId: 'course', sectionId: '4C', sessionId: 'session1',
  senderId: 'student', senderName: 'Student One', senderRole: 'student',
  text: 'Can you repeat the last point?', clientNonce: '1234567890123',
};
await commit('student', [create(messagePath, message, ['createdAt'])], 200, 'joined student sends meeting message');
await get('student', messagePath, 200, 'joined student reads meeting chat');
await get('teacher', messagePath, 200, 'course instructor reads meeting chat');
await get('other', messagePath, 403, 'enrolled but unjoined student cannot read meeting chat');
await get('foreign', messagePath, 403, 'other section cannot read meeting chat');
await get('admin', messagePath, 403, 'administrator cannot read participant chat');
await commit('student', [create('meetingMessages/student_1234567890124', {...message, senderName: 'Teacher One', clientNonce: '1234567890124'}, ['createdAt'])], 403, 'sender name cannot be forged');
await commit('foreign', [create('meetingMessages/foreign_1234567890125', {...message, senderId: 'foreign', senderName: 'Student Three', clientNonce: '1234567890125'}, ['createdAt'])], 403, 'other section cannot send meeting message');
await commit('student', [update(messagePath, {text: 'Edited'})], 403, 'meeting messages are append-only');

await seed('liveClasses/live1', {
  courseId: 'course', sectionId: '4C', sessionId: 'session1', status: 'ended',
  instructorId: 'teacher', studentIds: ['student'],
});
await get('student', messagePath, 403, 'ended meeting chat is no longer readable');
await commit('student', [create('meetingMessages/student_1234567890126', {...message, clientNonce: '1234567890126'}, ['createdAt'])], 403, 'ended meeting rejects new messages');

console.log(`Passed ${checks} private-note and meeting-chat Firestore rule checks.`);
