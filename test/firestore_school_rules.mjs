import assert from 'node:assert/strict';

// This suite is deliberately restricted to a local, disposable demo database.
const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/, 'Set FIRESTORE_EMULATOR_HOST to your local emulator.');
const project = 'demo-caslms-school-check';
const database = `projects/${project}/databases/(default)`;
const base = `http://${host}/v1/${database}/documents`;
let checks = 0;
function value(item) {
  if (item === null) return { nullValue: null };
  if (typeof item === 'boolean') return { booleanValue: item };
  if (typeof item === 'number') return { doubleValue: item };
  return { stringValue: String(item) };
}
function fields(data) { return Object.fromEntries(Object.entries(data).map(([key, item]) => [key, value(item)])); }
function token(uid, emailVerified = false) {
  const encode = (data) => Buffer.from(JSON.stringify(data)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({ iss: `https://securetoken.google.com/${project}`,
    aud: project, sub: uid, user_id: uid, email: `${uid}@example.com`, email_verified: emailVerified,
    auth_time: now, iat: now, exp: now + 3600, firebase: { sign_in_provider: 'password', identities: {} } })}.`;
}
async function request(path, method, data, bearer = 'owner') {
  const result = await fetch(`${base}/${path}`, { method,
    headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
    body: data === undefined ? undefined : JSON.stringify({ fields: fields(data) }) });
  return result;
}
async function seed(path, data) {
  const result = await request(path, 'PATCH', data);
  assert.equal(result.status, 200, await result.text());
}
async function status(path, method, data, bearer, expected, label) {
  const result = await request(path, method, data, bearer);
  assert.equal(result.status, expected, `${label}: ${await result.text()}`);
  checks++;
}
await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`, { method: 'DELETE' });
await seed('users/legacy', { uid: 'legacy', role: 'student', status: 'active', universityId: '10001', email: 'legacy@example.com' });
await seed('users/pending', { uid: 'pending', role: 'student', status: 'pending_verification', universityId: '10002',
  email: 'pending@example.com', authEmail: 'pending@example.com', emailVerificationRequired: true });
await seed('users/verified', { uid: 'verified', role: 'student', status: 'active', universityId: '10003',
  email: 'verified@example.com', authEmail: 'verified@example.com', emailVerificationRequired: true });
await seed('users/teacher', { uid: 'teacher', role: 'instructor', status: 'active' });
await seed('users/other', { uid: 'other', role: 'instructor', status: 'active' });
await seed('courses/course', { instructorId: 'teacher', status: 'active', classCode: 'ORIGINAL' });
await seed('courseSections/NEW-A', { courseId: 'course', instructorId: 'teacher', classCode: 'NEW-A', legacy: false, status: 'active' });
await seed('assessmentSubmissions/form_verified', { assessmentId: 'form', courseId: 'course', moduleId: 'module', studentId: 'verified', status: 'graded', score: 18 });
await status('courses/course', 'GET', undefined, token('legacy'), 200, 'Existing active students retain access');
await status('users/pending', 'GET', undefined, token('pending'), 200, 'Pending student can read own verification state');
await status('courses/course', 'GET', undefined, token('pending'), 403, 'Pending student cannot access dashboard data');
await status('courses/course', 'GET', undefined, token('verified'), 403, 'Required email verification cannot be bypassed with active status alone');
await status('courses/course', 'GET', undefined, token('verified', true), 200, 'Verified active student has access');
await status('assessmentSubmissions/form_verified', 'GET', undefined, token('verified', true), 200, 'Manual grade visible to its student');
await status('assessmentSubmissions/form_verified', 'GET', undefined, token('legacy'), 403, 'Other students cannot read a classmate grade');
await status('users/attacker', 'PATCH', { uid: 'attacker', role: 'student', status: 'active', universityId: '10004' }, token('attacker'), 403, 'Clients cannot create self-activated profiles');
await status('users/pending', 'PATCH', { uid: 'pending', role: 'student', status: 'active', universityId: '10002',
  email: 'pending@example.com', authEmail: 'pending@example.com', emailVerificationRequired: true }, token('pending'), 403, 'Pending user cannot activate own profile');
await status('users/verified', 'PATCH', { uid: 'verified', role: 'student', status: 'active', universityId: '10003',
  email: 'verified@example.com', authEmail: 'verified@example.com', emailVerificationRequired: false }, token('verified', true), 403, 'Verification requirement is immutable to students');
await status('assessmentSubmissions/form_verified', 'PATCH', { assessmentId: 'form', courseId: 'course', moduleId: 'module', studentId: 'verified', status: 'graded', score: 20 }, token('verified', true), 403, 'Students cannot change scores');
await status('assessmentSubmissions/form_verified', 'PATCH', { assessmentId: 'form', courseId: 'course', moduleId: 'module', studentId: 'verified', status: 'graded', score: 20 }, token('teacher'), 403, 'Manual scores require trusted backend validation');

const joined = await fetch(`${base}:commit`, { method: 'POST', headers: {
  Authorization: `Bearer ${token('verified', true)}`, 'Content-Type': 'application/json',
}, body: JSON.stringify({ writes: [{ update: { name: `${database}/documents/enrollments/course_verified`, fields: fields({
  courseId: 'course', studentId: 'verified', studentName: 'Verified Student', studentCampusId: '10003',
  sectionId: 'NEW-A', status: 'active', enrollmentSource: 'section_code',
}) }, updateTransforms: [{ fieldPath: 'enrolledAt', setToServerValue: 'REQUEST_TIME' }] }] }) });
assert.equal(joined.status, 200, `Verified student joins selected section: ${await joined.text()}`);
checks++;
const enrollment = { courseId: 'course', studentId: 'verified', studentName: 'Verified Student', studentCampusId: '10003',
  sectionId: 'ORIGINAL', status: 'active', enrollmentSource: 'section_code' };
await status('enrollments/course_verified', 'PATCH', enrollment, token('teacher'), 200, 'Owner can transfer enrolled student');
await status('enrollments/course_verified', 'PATCH', { ...enrollment, sectionId: 'NEW-A' }, token('other'), 403, 'Another instructor cannot transfer student');
await seed('courseInvitations/course_legacy', { courseId: 'course', studentId: 'legacy', studentCampusId: '10001',
  instructorId: 'teacher', status: 'accepted' });
const invitedFields = { courseId: 'course', studentId: 'legacy', studentName: 'Legacy Student', studentCampusId: '10001',
  sectionId: 'ORIGINAL', status: 'active', enrollmentSource: 'instructor_invitation', invitationId: 'course_legacy', invitedBy: 'teacher' };
const inviteResult = await fetch(`${base}:commit`, { method: 'POST', headers: {
  Authorization: `Bearer ${token('legacy')}`, 'Content-Type': 'application/json',
}, body: JSON.stringify({ writes: [{ update: { name: `${database}/documents/enrollments/course_legacy`, fields: fields(invitedFields) },
  updateTransforms: [{ fieldPath: 'enrolledAt', setToServerValue: 'REQUEST_TIME' }, { fieldPath: 'acceptedAt', setToServerValue: 'REQUEST_TIME' }] }] }) });
assert.equal(inviteResult.status, 200, `Invitation retains explicit original-section membership: ${await inviteResult.text()}`);
checks++;
console.log(`Passed ${checks} Firestore access and membership checks against the local emulator.`);
