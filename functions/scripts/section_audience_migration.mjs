import {writeFile, readFile} from 'node:fs/promises';
import {applicationDefault, getApps, initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore, Timestamp} from 'firebase-admin/firestore';

const migrationId = '202611090001';
const args = new Map(process.argv.slice(2).map((value, index, all) => {
  if (!value.startsWith('--')) return [value, true];
  const next = all[index + 1];
  return [value, next && !next.startsWith('--') ? next : true];
}));
const mode = args.has('--apply') ? 'apply' : args.has('--rollback') ? 'rollback' : 'dry-run';
const productionAllowed = args.has('--allow-production');
const emulator = process.env.FIRESTORE_EMULATOR_HOST;
if (!emulator && mode !== 'dry-run' && !productionAllowed) {
  throw new Error('Production writes require --allow-production after report review.');
}
if (!getApps().length) initializeApp({credential: applicationDefault()});
const db = getFirestore();

function audience(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > 50 ||
      value.some((id) => typeof id !== 'string' || !id || id !== id.trim() || id.includes('/')) ||
      new Set(value).size !== value.length || (value.includes('*') && value.length !== 1)) return null;
  return value;
}
function subset(parent, child) {
  return parent.includes('*') || (!child.includes('*') && child.every((id) => parent.includes(id)));
}
function same(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

async function inspect() {
  const [coursesSnap, sectionsSnap, modulesSnap, resourcesSnap, assessmentsSnap] = await Promise.all([
    db.collection('courses').get(), db.collection('courseSections').get(), db.collection('modules').get(),
    db.collection('moduleResources').get(), db.collection('assessments').get(),
  ]);
  const courses = new Map(coursesSnap.docs.map((doc) => [doc.id, doc.data()]));
  const sections = new Map(sectionsSnap.docs.map((doc) => [doc.id, doc.data()]));
  const modules = new Map(modulesSnap.docs.map((doc) => [doc.id, doc.data()]));
  const findings = [];
  const changes = [];
  const inspectAudience = (collection, doc, parent) => {
    const data = doc.data();
    const hasField = Object.hasOwn(data, 'sectionIds');
    const parsed = hasField ? audience(data.sectionIds) : null;
    if (hasField && !parsed) {
      findings.push({severity: 'error', collection, id: doc.id, issue: 'malformed_audience'});
      return;
    }
    let effective = parsed;
    if (!hasField) {
      effective = parent ?? ['*'];
      findings.push({severity: 'change', collection, id: doc.id, issue: 'legacy_missing_audience', proposed: effective});
      changes.push({collection, id: doc.id, beforePresent: false, before: null, after: effective,
        updateTime: doc.updateTime.toDate().toISOString()});
    }
    const course = courses.get(data.courseId);
    if (!course) findings.push({severity: 'error', collection, id: doc.id, issue: 'missing_course'});
    for (const id of effective ?? []) {
      if (id === '*') continue;
      const section = sections.get(id);
      const legacy = id === String(course?.classCode ?? '').trim();
      if (!legacy && (!section || section.courseId !== data.courseId || section.status !== 'active')) {
        findings.push({severity: 'warning', collection, id: doc.id, issue: 'inactive_or_foreign_section', sectionId: id});
      }
    }
    if (parent && effective && !subset(parent, effective)) {
      findings.push({severity: 'error', collection, id: doc.id, issue: 'child_expands_parent'});
    }
    if (collection === 'assessments' && data.sectionId && effective &&
        !effective.includes('*') && !effective.includes(data.sectionId)) {
      findings.push({severity: 'error', collection, id: doc.id, issue: 'sectionId_outside_audience'});
    }
  };
  for (const doc of modulesSnap.docs) inspectAudience('modules', doc, null);
  for (const [collection, snapshot] of [['moduleResources', resourcesSnap], ['assessments', assessmentsSnap]]) {
    for (const doc of snapshot.docs) {
      const module = modules.get(doc.data().moduleId);
      if (!module) {
        findings.push({severity: 'error', collection, id: doc.id, issue: 'missing_parent_module'});
        continue;
      }
      const parent = Object.hasOwn(module, 'sectionIds') ? audience(module.sectionIds) : ['*'];
      if (!parent) {
        findings.push({severity: 'error', collection, id: doc.id, issue: 'malformed_parent_audience'});
        continue;
      }
      inspectAudience(collection, doc, parent);
    }
  }
  return {migrationId, generatedAt: new Date().toISOString(), projectId: db.projectId, findings, changes};
}

async function apply(report, backupPath) {
  if (!backupPath) throw new Error('--backup <path> is required for --apply.');
  await writeFile(backupPath, JSON.stringify(report, null, 2), {flag: 'wx'});
  for (let offset = 0; offset < report.changes.length; offset += 300) {
    const batch = db.batch();
    for (const change of report.changes.slice(offset, offset + 300)) {
      const ref = db.collection(change.collection).doc(change.id);
      batch.update(ref, {sectionIds: change.after}, {
        lastUpdateTime: Timestamp.fromDate(new Date(change.updateTime)),
      });
    }
    await batch.commit();
  }
}

async function rollback(backupPath) {
  if (!backupPath) throw new Error('--backup <path> is required for --rollback.');
  const report = JSON.parse(await readFile(backupPath, 'utf8'));
  if (report.migrationId !== migrationId) throw new Error('Backup belongs to another migration.');
  for (let offset = 0; offset < report.changes.length; offset += 300) {
    const group = report.changes.slice(offset, offset + 300);
    const snapshots = await Promise.all(group.map((change) => db.collection(change.collection).doc(change.id).get()));
    const batch = db.batch();
    for (let index = 0; index < group.length; index += 1) {
      const change = group[index];
      const snapshot = snapshots[index];
      if (!snapshot.exists || !same(snapshot.data().sectionIds, change.after)) {
        throw new Error(`Refusing rollback: ${change.collection}/${change.id} changed after migration.`);
      }
      batch.update(snapshot.ref, {sectionIds: change.beforePresent ? change.before : FieldValue.delete()},
        {lastUpdateTime: snapshot.updateTime});
    }
    await batch.commit();
  }
}

if (mode === 'rollback') {
  await rollback(args.get('--backup'));
  console.log('Rollback completed after concurrency checks.');
} else {
  const report = await inspect();
  if (args.get('--report')) await writeFile(args.get('--report'), JSON.stringify(report, null, 2), {flag: 'wx'});
  const summary = report.findings.reduce((result, item) => ({...result, [item.issue]: (result[item.issue] ?? 0) + 1}), {});
  console.log(JSON.stringify({migrationId, mode, documentsToChange: report.changes.length, summary}, null, 2));
  if (mode === 'apply') {
    if (report.findings.some((item) => item.severity === 'error')) {
      throw new Error('Resolve all error findings before applying the backfill.');
    }
    await apply(report, args.get('--backup'));
    console.log(`Applied ${report.changes.length} legacy audience updates.`);
  }
}
