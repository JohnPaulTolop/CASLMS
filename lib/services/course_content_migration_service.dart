import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'course_content_paths.dart';

/// Non-destructively copies legacy top-level course content into the
/// course-scoped hierarchy used by student-facing reads.
///
/// The migration is idempotent: running it again merges the same document IDs
/// and never deletes the legacy records that instructor/admin screens still
/// use during the transition.
class CourseContentMigrationService {
  CourseContentMigrationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<CourseContentMigrationResult> migrateLegacyContent() async {
    await _requireActiveAdmin();

    final writer = _MigrationBatchWriter(_firestore);
    final result = CourseContentMigrationResult();

    result.modules = await _copyCollection(
      collection: 'modules',
      writer: writer,
      targetFor: (document) {
        final data = document.data();
        final courseId = (data['courseId'] ?? '').toString().trim();
        if (courseId.isEmpty) return null;
        return CourseContentPaths.module(_firestore, courseId, document.id);
      },
      onSkipped: () => result.skipped++,
    );
    await writer.flush();

    result.resources = await _copyCollection(
      collection: 'moduleResources',
      writer: writer,
      targetFor: (document) {
        final data = document.data();
        final courseId = (data['courseId'] ?? '').toString().trim();
        final moduleId = (data['moduleId'] ?? '').toString().trim();
        if (courseId.isEmpty || moduleId.isEmpty) return null;
        return CourseContentPaths.resources(
          _firestore,
          courseId,
          moduleId,
        ).doc(document.id);
      },
      onSkipped: () => result.skipped++,
    );
    await writer.flush();

    result.assessments = await _copyCollection(
      collection: 'assessments',
      writer: writer,
      targetFor: (document) {
        final data = document.data();
        final courseId = (data['courseId'] ?? '').toString().trim();
        final moduleId = (data['moduleId'] ?? '').toString().trim();
        if (courseId.isEmpty || moduleId.isEmpty) return null;
        return CourseContentPaths.assessments(
          _firestore,
          courseId,
          moduleId,
        ).doc(document.id);
      },
      onSkipped: () => result.skipped++,
    );
    await writer.flush();

    result.calendarEvents = await _copyCollection(
      collection: 'calendarEvents',
      writer: writer,
      targetFor: (document) {
        final courseId = (document.data()['courseId'] ?? '').toString().trim();
        if (courseId.isEmpty) return null;
        return CourseContentPaths.calendarEvents(
          _firestore,
          courseId,
        ).doc(document.id);
      },
      onSkipped: () => result.skipped++,
    );
    await writer.flush();

    return result;
  }

  Future<int> _copyCollection({
    required String collection,
    required _MigrationBatchWriter writer,
    required DocumentReference<Map<String, dynamic>>? Function(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    )
    targetFor,
    required void Function() onSkipped,
  }) async {
    const pageSize = 200;
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
    var copied = 0;

    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collection)
          .orderBy(FieldPath.documentId)
          .limit(pageSize);
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final page = await query.get(const GetOptions(source: Source.server));
      if (page.docs.isEmpty) break;

      for (final document in page.docs) {
        final target = targetFor(document);
        if (target == null) {
          onSkipped();
          continue;
        }
        await writer.set(
          target,
          _normalizedLegacyData(collection, document.data()),
        );
        copied++;
      }

      lastDocument = page.docs.last;
      if (page.docs.length < pageSize) break;
    }

    return copied;
  }

  Map<String, dynamic> _normalizedLegacyData(
    String collection,
    Map<String, dynamic> data,
  ) {
    final normalized = <String, dynamic>{...data};
    if (collection == 'modules' ||
        collection == 'moduleResources' ||
        collection == 'assessments') {
      final audience = data['sectionIds'];
      if (audience is! List || audience.isEmpty) {
        // Legacy content without an explicit audience was course-wide under
        // the old rules. Preserve that meaning using the canonical wildcard.
        normalized['sectionIds'] = const <String>['*'];
      }
    }
    if (collection == 'assessments' && data['sectionId'] is! String) {
      normalized['sectionId'] = '';
    }
    return normalized;
  }

  Future<void> _requireActiveAdmin() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in as an administrator before migrating data.');
    }

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final data = profile.data();
    final role = (data?['role'] ?? '').toString().trim().toLowerCase();
    final status = (data?['status'] ?? '').toString().trim().toLowerCase();
    if (role != 'admin' || status != 'active') {
      throw StateError('Only an active administrator can migrate data.');
    }
  }
}

class CourseContentMigrationResult {
  int modules = 0;
  int resources = 0;
  int assessments = 0;
  int calendarEvents = 0;
  int skipped = 0;

  int get copied => modules + resources + assessments + calendarEvents;
}

class _MigrationBatchWriter {
  _MigrationBatchWriter(this._firestore) : _batch = _firestore.batch();

  // Nested resource and assessment rules read their parent module. Firestore
  // allows only 20 document-access calls for an entire batched write, so keep
  // migration batches deliberately small even though the SDK permits 500
  // writes per batch.
  static const _maximumWrites = 10;
  final FirebaseFirestore _firestore;
  late WriteBatch _batch;
  var _pendingWrites = 0;

  Future<void> set(
    DocumentReference<Map<String, dynamic>> target,
    Map<String, dynamic> data,
  ) async {
    _batch.set(target, data, SetOptions(merge: true));
    _pendingWrites++;
    if (_pendingWrites >= _maximumWrites) {
      await flush();
    }
  }

  Future<void> flush() async {
    if (_pendingWrites == 0) return;
    await _batch.commit();
    _batch = _firestore.batch();
    _pendingWrites = 0;
  }
}
