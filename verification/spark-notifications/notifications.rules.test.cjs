const {before, after, beforeEach, test} = require("node:test");
const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const {join} = require("node:path");
const {initializeTestEnvironment, assertFails, assertSucceeds} =
  require("@firebase/rules-unit-testing");
const {doc, setDoc, getDoc, updateDoc, collection, query, where,
  getDocs, runTransaction, serverTimestamp} = require("firebase/firestore");

let env;
const db = uid => env.authenticatedContext(uid).firestore();
const id = notice => notice.sourceType + "_" + notice.sourceId + "_" + notice.userId;
const notice = (changes = {}) => ({
  userId: "s1", type: "module", sourceType: "module", sourceId: "m1",
  title: "New module: Networking", message: "Teacher published Networking.",
  courseId: "c1", authorizationCourseId: "c1", courseCode: "IT123",
  courseTitle: "Networking", moduleId: "m1", activityType: "",
  actorId: "t1", actorName: "Teacher", priority: "normal", isUrgent: false,
  isRead: false, readAt: null, createdAt: serverTimestamp(), ...changes,
});
const create = (uid, data) => setDoc(doc(db(uid), "notifications", id(data)), data);
const adminSet = (path, data) => env.withSecurityRulesDisabled(
  context => setDoc(doc(context.firestore(), path), data));

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Use npm test; emulator required");
  env = await initializeTestEnvironment({
    projectId: "demo-caslms-spark",
    firestore: {rules: readFileSync(join(__dirname, "../../firestore.rules"), "utf8")},
  });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const seed = {
      "users/t1": {role: "instructor", status: "active", name: "Teacher"},
      "users/t2": {role: "instructor", status: "active", name: "Other"},
      "users/s1": {role: "student", status: "active"},
      "users/s2": {role: "student", status: "active"},
      "courses/c1": {instructorId: "t1", status: "active"},
      "courses/c2": {instructorId: "t2", status: "active"},
      "enrollments/c1_s1": {courseId: "c1", studentId: "s1", status: "active"},
      "enrollments/c1_s2": {courseId: "c1", studentId: "s2", status: "inactive"},
      "modules/m1": {courseId: "c1", status: "published", title: "Networking"},
      "assessments/a1": {courseId: "c1", moduleId: "m1", title: "Exam",
        totalPoints: 100, assessmentType: "exam", status: "published"},
      "assessmentSubmissions/a1_s1": {assessmentId: "a1", courseId: "c1",
        moduleId: "m1", studentId: "s1", status: "graded", score: 90, gradedBy: "t1"},
      "assignments/l1": {courseId: "c1", moduleId: "m1", title: "Task", points: 10},
      "submissions/l1_s1": {assignmentId: "l1", courseId: "c1",
        studentId: "s1", status: "submitted"},
      "announcements/n1": {courseId: "", createdBy: "t1", targetType: "all_classes",
        status: "published", title: "News", message: "Class news", isUrgent: false},
    };
    for (const [path, data] of Object.entries(seed)) {
      await setDoc(doc(context.firestore(), path), data);
    }
  });
});

test("owner can deliver; another teacher, inactive enrollee and actor spoof fail", async () => {
  await assertSucceeds(create("t1", notice()));
  await assertFails(create("t2", notice({actorId: "t2", sourceId: "different"})));
  await assertFails(create("t1", notice({userId: "s2"})));
  await assertFails(create("t1", notice({actorId: "t2", userId: "s2"})));
});
test("draft, wrong course, source type and ID mismatch are rejected", async () => {
  await adminSet("modules/m1", {courseId: "c1", status: "draft"});
  await assertFails(create("t1", notice()));
  await adminSet("modules/m1", {courseId: "c2", status: "published"});
  await assertFails(create("t1", notice()));
  await adminSet("modules/m1", {courseId: "c1", status: "published"});
  await assertFails(create("t1", notice({type: "grade"})));
  await assertFails(setDoc(doc(db("t1"), "notifications", "random"), notice()));
});
test("published resource and all assessment types are supported", async () => {
  await adminSet("moduleResources/r1", {courseId: "c1", moduleId: "m1",
    status: "published", resourceType: "pdf"});
  await assertSucceeds(create("t1", notice({
    sourceType: "moduleResource", sourceId: "r1", type: "resource"})));
  for (const type of ["quiz", "activity", "assignment", "exam", "summative"]) {
    await adminSet("assessments/" + type, {courseId: "c1", moduleId: "m1",
      status: "published", assessmentType: type, title: type});
    await assertSucceeds(create("t1", notice({
      sourceType: "assessment", sourceId: type, type: "assessment", activityType: type})));
  }
});
test("delivery transaction can read missing ID; retry preserves the read state", async () => {
  const data = notice();
  const instructorDb = db("t1");
  const ref = doc(instructorDb, "notifications", id(data));
  const deliver = () => runTransaction(instructorDb, async txn => {
    if (!(await txn.get(ref)).exists()) txn.set(ref, notice());
  });
  await assertSucceeds(deliver());
  await assertSucceeds(updateDoc(doc(db("s1"), "notifications", id(data)),
    {isRead: true, readAt: serverTimestamp()}));
  await assertSucceeds(deliver());
  assert.equal((await getDoc(doc(db("s1"), "notifications", id(data)))).data().isRead, true);
  await assertFails(getDoc(doc(db("s2"), "notifications", id(data))));
  await assertFails(getDoc(doc(db("t2"), "notifications", id(data))));
  await assertSucceeds(getDocs(query(collection(db("s1"), "notifications"),
    where("userId", "==", "s1"))));
  await assertFails(updateDoc(doc(db("s1"), "notifications", id(data)), {message: "spoof"}));
  await assertFails(updateDoc(doc(db("s1"), "notifications", id(data)), {isRead: false}));
});
test("grade targets exactly the submitted student, including after unenrollment", async () => {
  const grade = notice({type: "grade", sourceType: "assessmentSubmission",
    sourceId: "a1_s1", title: "Graded: Exam"});
  await assertFails(create("t1", {...grade, userId: "s2"}));
  await adminSet("enrollments/c1_s1", {courseId: "c1", studentId: "s1", status: "inactive"});
  await assertSucceeds(create("t1", grade));
});
test("automatic grading cannot impersonate instructor grading", async () => {
  await adminSet("assessmentSubmissions/a1_s1", {assessmentId: "a1", courseId: "c1",
    moduleId: "m1", studentId: "s1", status: "graded", gradedBy: "system:auto-score",
    gradingMode: "automatic"});
  await assertFails(create("t1", notice({type: "grade",
    sourceType: "assessmentSubmission", sourceId: "a1_s1", title: "Graded: Exam"})));
});
test("all-classes announcement needs a concrete owned course and active recipient", async () => {
  const data = notice({type: "announcement", sourceType: "announcement", sourceId: "n1",
    courseId: "", moduleId: "", title: "News", message: "Class news"});
  await assertSucceeds(create("t1", data));
  await assertFails(create("t1", {...data, userId: "s2"}));
  await assertFails(create("t2", {...data, actorId: "t2", userId: "s2"}));
  await assertSucceeds(setDoc(doc(db("t1"), "announcements", "new"), {
    courseId: "", createdBy: "t1", targetType: "all_classes", status: "published"}));
});
test("manual grading cannot reassign recipients or cross another teacher's course", async () => {
  const grade = {status: "graded", score: 8, feedback: "Good", gradedBy: "t1",
    gradedAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertFails(updateDoc(doc(db("t2"), "submissions", "l1_s1"),
    {...grade, gradedBy: "t2"}));
  await assertFails(updateDoc(doc(db("t1"), "submissions", "l1_s1"),
    {...grade, studentId: "s2"}));
  await assertSucceeds(updateDoc(doc(db("t1"), "submissions", "l1_s1"), grade));
  await assertSucceeds(create("t1", notice({type: "grade", sourceType: "submission",
    sourceId: "l1_s1", title: "Graded: Task"})));
});
