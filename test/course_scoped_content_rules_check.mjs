import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const host = process.env.FIRESTORE_EMULATOR_HOST;
assert.match(
  host ?? '',
  /^(127\.0\.0\.1|localhost):\d+$/,
  'Use the local Firestore emulator.',
);
const project = 'demo-caslms-course-scoped';
const database = `projects/${project}/databases/(default)`;
const base = `http://${host}/v1/${database}/documents`;

const rulesText = readFileSync(
  new URL('../firestore.rules', import.meta.url),
  'utf8',
);
const rulesResponse = await fetch(
  `http://${host}/emulator/v1/projects/${project}:securityRules`,
  {
    method: 'PUT',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      rules: {files: [{name: 'firestore.rules', content: rulesText}]},
    }),
  },
);
assert.equal(rulesResponse.status, 200, await rulesResponse.text());
await fetch(
  `http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,
  {method: 'DELETE'},
);

function value(item) {
  if (typeof item === 'boolean') return {booleanValue: item};
  if (Array.isArray(item)) {
    return {arrayValue: {values: item.map(value)}};
  }
  return {stringValue: String(item)};
}
const fields = (data) =>
  Object.fromEntries(
    Object.entries(data).map(([key, item]) => [key, value(item)]),
  );
function token(uid, email) {
  const encode = (data) =>
    Buffer.from(JSON.stringify(data)).toString('base64url');
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
    headers: {
      Authorization: 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({fields: fields(data)}),
  });
  assert.equal(response.status, 200, await response.text());
}
async function get(uid, email, path, expected, label) {
  const response = await fetch(`${base}/${path}`, {
    headers: {Authorization: `Bearer ${token(uid, email)}`},
  });
  assert.equal(response.status, expected, `${label}: ${await response.text()}`);
}
async function write(uid, email, path, data, expected, label) {
  const response = await fetch(`${base}/${path}`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token(uid, email)}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({fields: fields(data)}),
  });
  assert.equal(response.status, expected, `${label}: ${await response.text()}`);
}
async function query(uid, email, parent, structuredQuery, expected, label) {
  const response = await fetch(`${base}/${parent}:runQuery`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token(uid, email)}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({structuredQuery}),
  });
  assert.equal(response.status, expected, `${label}: ${await response.text()}`);
}

await seed('users/student', {
  uid: 'student',
  role: 'student',
  status: 'active',
  email: 'student@example.com',
});
await seed('users/outsider', {
  uid: 'outsider',
  role: 'student',
  status: 'active',
  email: 'outsider@example.com',
});
await seed('users/teacher', {
  uid: 'teacher',
  role: 'instructor',
  status: 'active',
  email: 'teacher@example.com',
});
await seed('courses/course', {
  status: 'active',
  instructorId: 'teacher',
  classCode: '4C',
});
await seed('enrollments/course_student', {
  courseId: 'course',
  studentId: 'student',
  sectionId: '4C',
  status: 'active',
});
await seed('modules/module', {
  courseId: 'course',
  status: 'published',
  sectionIds: ['4C'],
});
await seed('courses/course/modules/module', {
  courseId: 'course',
  status: 'published',
  sectionIds: ['4C'],
});
await seed('courses/course/modules/module/resources/resource', {
  courseId: 'course',
  moduleId: 'module',
  status: 'published',
  sectionIds: ['4C'],
});
await seed('courses/course/modules/module/assessments/assessment', {
  courseId: 'course',
  moduleId: 'module',
  sectionId: '4C',
  status: 'published',
  sectionIds: ['4C'],
});
await seed('courses/course/calendarEvents/event', {
  courseId: 'course',
  ownerId: 'teacher',
});

const modulesQuery = {
  from: [{collectionId: 'modules'}],
  where: {
    compositeFilter: {
      op: 'AND',
      filters: [
        {
          fieldFilter: {
            field: {fieldPath: 'courseId'},
            op: 'EQUAL',
            value: {stringValue: 'course'},
          },
        },
        {
          fieldFilter: {
            field: {fieldPath: 'status'},
            op: 'EQUAL',
            value: {stringValue: 'published'},
          },
        },
        {
          fieldFilter: {
            field: {fieldPath: 'sectionIds'},
            op: 'ARRAY_CONTAINS_ANY',
            value: {
              arrayValue: {
                values: [{stringValue: '*'}, {stringValue: '4C'}],
              },
            },
          },
        },
      ],
    },
  },
};
const childQuery = (collectionId) => ({
  from: [{collectionId}],
  where: {
    compositeFilter: {
      op: 'AND',
      filters: [
        {
          fieldFilter: {
            field: {fieldPath: 'courseId'},
            op: 'EQUAL',
            value: {stringValue: 'course'},
          },
        },
        {
          fieldFilter: {
            field: {fieldPath: 'moduleId'},
            op: 'EQUAL',
            value: {stringValue: 'module'},
          },
        },
        {
          fieldFilter: {
            field: {fieldPath: 'status'},
            op: 'EQUAL',
            value: {stringValue: 'published'},
          },
        },
        {
          fieldFilter: {
            field: {fieldPath: 'sectionIds'},
            op: 'ARRAY_CONTAINS_ANY',
            value: {
              arrayValue: {
                values: [{stringValue: '*'}, {stringValue: '4C'}],
              },
            },
          },
        },
      ],
    },
  },
});

await query(
  'student',
  'student@example.com',
  'courses/course',
  modulesQuery,
  200,
  'enrolled student lists scoped modules',
);
await query(
  'student',
  'student@example.com',
  'courses/course/modules/module',
  childQuery('resources'),
  200,
  'enrolled student lists scoped resources',
);
await get(
  'student',
  'student@example.com',
  'courses/course/modules/module/assessments/assessment',
  200,
  'enrolled student reads scoped assessment',
);
await get(
  'student',
  'student@example.com',
  'courses/course/calendarEvents/event',
  200,
  'enrolled student reads scoped course event',
);
await get(
  'outsider',
  'outsider@example.com',
  'courses/course/modules/module',
  403,
  'unenrolled student cannot read scoped module',
);
await write(
  'teacher',
  'teacher@example.com',
  'courses/course/modules/module/resources/instructor-resource',
  {
    courseId: 'course',
    moduleId: 'module',
    status: 'published',
    sectionIds: ['4C'],
  },
  200,
  'course instructor can mirror scoped material',
);
await write(
  'student',
  'student@example.com',
  'courses/course/modules/module/resources/student-resource',
  {
    courseId: 'course',
    moduleId: 'module',
    status: 'published',
    sectionIds: ['4C'],
  },
  403,
  'student cannot write scoped material',
);

console.log('Passed 7 course-scoped permission checks.');
