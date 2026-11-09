import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

// Exercise the real endpoint with isolated auth and storage dependencies.
const source = readFileSync(new URL('../supabase/functions/assessment-submission/index.ts', import.meta.url), 'utf8');
const endpoint = source.slice(source.indexOf('async function requireAppCheck('), source.indexOf('async function publishAiQuiz('));
class RequestError extends Error { constructor(message, status) { super(message); this.status = status; } }
async function run(overrides = {}) {
  const user = { uid: 'me', profile: { role: 'student' }, ...overrides.user };
  const course = { status: 'active', classCode: 'legacy', ...overrides.course };
  const enrollment = { studentId: 'me', courseId: 'course', status: 'active', sectionId: 'A', ...overrides.enrollment };
  let queried = false;
  const context = vm.createContext({
    RequestError,
    clean: value => String(value ?? '').trim(),
    requireActiveUser: async () => user,
    firebaseApp: {},
    getAppCheck: () => ({ verifyToken: async () => { if (overrides.badApp) throw Error('invalid'); } }),
    json: value => value,
    firestore: { collection: collection => ({
      doc: () => ({ get: async () => ({ data: () => collection === 'courses' ? course : enrollment }) }),
      where: () => ({ get: async () => {
        queried = true;
        return { docs: (overrides.rows ?? []).map(row => ({ data: () => row })) };
      } }),
    }) },
  });
  vm.runInContext(stripTypeScriptTypes(endpoint), context);
  try {
    const request = { headers: { get: () => overrides.missingApp ? null : 'verified' } };
    await context.requireAppCheck(request);
    const result = await context.studentRoster(request, { courseId: 'course' });
    return { result: JSON.parse(JSON.stringify(result)), queried };
  } catch (error) {
    assert.equal(queried, false, 'Denied requests must not query classmates');
    throw error;
  }
}
for (const overrides of [
  { user: { profile: { role: 'instructor' } } },
  { enrollment: { studentId: 'other' } },
  { enrollment: { courseId: 'other' } },
  { enrollment: { status: 'removed' } },
  { course: { status: 'inactive' } },
  { missingApp: true },
  { badApp: true },
]) await assert.rejects(run(overrides), error => error.status === 403);
const row = (studentId, studentName, sectionId = 'A', status = 'active') => ({ studentId, studentName, sectionId, status, studentCampusId: 'private', email: 'private' });
const { result } = await run({ rows: [row('me', 'Zoe'), row('peer', 'Amy'), row('peer', 'Duplicate'), row('other', 'Other section', 'B'), row('removed', 'Removed', 'A', 'removed')] });
assert.deepEqual(result.students, [{ name: 'Amy', isCurrentStudent: false }, { name: 'Zoe', isCurrentStudent: true }]);
const legacy = await run({ enrollment: { sectionId: '' }, rows: [row('me', 'Zoe', ''), row('peer', 'Amy', 'legacy'), row('other', 'Other', 'B')] });
assert.equal(legacy.result.students.length, 2);
console.log('Student roster checks passed: authorization, App Check, section isolation, deduplication, sorting, and minimal fields.');
