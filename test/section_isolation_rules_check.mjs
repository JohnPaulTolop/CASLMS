import assert from 'node:assert/strict';

const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(host ?? '', /^(127\.0\.0\.1|localhost):\d+$/, 'Use the local Firestore emulator.');
const project = 'demo-caslms-section-isolation';
const database = `projects/${project}/databases/(default)`;
const base = `http://${host}/v1/${database}/documents`;
let checks = 0;

function value(item) {
  if (item === null) return {nullValue: null};
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
    iss: `https://securetoken.google.com/${project}`, aud: project, sub: uid, user_id: uid,
    email: `${uid}@example.com`, email_verified: true, auth_time: now, iat: now, exp: now + 3600,
    firebase: {sign_in_provider: 'password', identities: {}},
  })}.`;
}
async function request(path, method, data, bearer = 'owner') {
  return fetch(`${base}/${path}`, {
    method,
    headers: {Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json'},
    body: data === undefined ? undefined : JSON.stringify({fields: fields(data)}),
  });
}
async function seed(path, data) {
  const response = await request(path, 'PATCH', data);
  assert.equal(response.status, 200, await response.text());
}
async function expectStatus(path, method, data, uid, expected, label) {
  const response = await request(path, method, data, token(uid));
  assert.equal(response.status, expected, `${label}: ${await response.text()}`);
  checks += 1;
}

await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`, {method: 'DELETE'});
for (const [uid, role] of [['teacher', 'instructor'], ['student4c', 'student'], ['student4d', 'student'],
  ['archived', 'student'], ['removed', 'student']]) {
  await seed(`users/${uid}`, {uid, role, status: 'active', email: `${uid}@example.com`});
}
await seed('courses/course', {instructorId: 'teacher', status: 'active', classCode: '4C'});
await seed('courseSections/4C', {courseId: 'course', instructorId: 'teacher', status: 'active', name: '4C'});
await seed('courseSections/4D', {courseId: 'course', instructorId: 'teacher', status: 'active', name: '4D'});
await seed('courseSections/OLD', {courseId: 'course', instructorId: 'teacher', status: 'archived', name: 'Old'});
await seed('enrollments/course_student4c', {courseId: 'course', studentId: 'student4c', sectionId: '4C', status: 'active'});
await seed('enrollments/course_student4d', {courseId: 'course', studentId: 'student4d', sectionId: '4D', status: 'active'});
await seed('enrollments/course_archived', {courseId: 'course', studentId: 'archived', sectionId: 'OLD', status: 'active'});
await seed('enrollments/course_removed', {courseId: 'course', studentId: 'removed', sectionId: '4C', status: 'removed'});
await seed('modules/only4c', {courseId: 'course', title: '4C', status: 'published', sectionIds: ['4C']});
await seed('modules/multiple', {courseId: 'course', title: 'Both', status: 'published', sectionIds: ['4C', '4D']});
await seed('modules/all', {courseId: 'course', title: 'All', status: 'published', sectionIds: ['*']});
await seed('modules/draft', {courseId: 'course', title: 'Draft', status: 'draft', sectionIds: ['4C']});
await seed('modules/legacy', {courseId: 'course', title: 'Legacy', status: 'published'});
await seed('moduleResources/resource4c', {courseId: 'course', moduleId: 'only4c', createdBy: 'teacher', status: 'published', sectionIds: ['4C']});
await seed('moduleResources/expanded', {courseId: 'course', moduleId: 'only4c', createdBy: 'teacher', status: 'published', sectionIds: ['*']});
await seed('assessments/single4d', {courseId: 'course', moduleId: 'multiple', createdBy: 'teacher', status: 'published', sectionIds: ['4C', '4D'], sectionId: '4D'});

await expectStatus('modules/only4c', 'GET', undefined, 'student4c', 200, '4C reads assigned module by ID');
await expectStatus('modules/only4c', 'GET', undefined, 'student4d', 403, '4D cannot read 4C module by ID');
await expectStatus('modules/multiple', 'GET', undefined, 'student4c', 200, 'multiple includes 4C');
await expectStatus('modules/multiple', 'GET', undefined, 'student4d', 200, 'multiple includes 4D');
await expectStatus('modules/all', 'GET', undefined, 'student4d', 200, 'all sections includes 4D');
await expectStatus('modules/draft', 'GET', undefined, 'student4c', 403, 'draft module hidden');
await expectStatus('modules/legacy', 'GET', undefined, 'student4d', 200, 'legacy missing audience remains shared');
await expectStatus('moduleResources/resource4c', 'GET', undefined, 'student4c', 200, '4C reads child');
await expectStatus('moduleResources/resource4c', 'GET', undefined, 'student4d', 403, '4D cannot read child by ID');
await expectStatus('moduleResources/expanded', 'GET', undefined, 'student4d', 403, 'child cannot widen parent on read');
await expectStatus('assessments/single4d', 'GET', undefined, 'student4c', 403, 'existing sectionId further restricts 4C');
await expectStatus('assessments/single4d', 'GET', undefined, 'student4d', 200, 'existing sectionId allows 4D');
await expectStatus('modules/all', 'GET', undefined, 'archived', 403, 'archived section is denied');
await expectStatus('modules/all', 'GET', undefined, 'removed', 403, 'removed enrollment is denied');

await expectStatus('moduleResources/forged', 'PATCH', {
  courseId: 'course', moduleId: 'only4c', createdBy: 'teacher', status: 'published', sectionIds: ['4C', '4D'],
}, 'teacher', 403, 'instructor cannot create child that expands parent');
await expectStatus('modules/only4c', 'PATCH', {
  courseId: 'course', title: '4C', status: 'published', sectionIds: ['*'],
}, 'teacher', 403, 'published module audience cannot change in place');
await expectStatus('modules/malformed', 'PATCH', {
  courseId: 'course', title: 'Bad', status: 'published', sectionIds: ['*', '4C'],
}, 'teacher', 403, 'mixed wildcard audience rejected');

console.log(`Passed ${checks} section-isolation Firestore rule checks against the local emulator.`);
