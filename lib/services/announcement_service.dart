import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final NotificationService _notificationService = NotificationService();

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> _getCurrentRole() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    final profile = (await _firestore.collection('users').doc(user.uid).get())
        .data();
    return (profile?['role'] ?? '').toString().toLowerCase();
  }

  // ============================================================
  // GET CURRENT INSTRUCTOR COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>> getInstructorCourses() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'No instructor is currently logged in.',
        );
      }

      final role = await _getCurrentRole();
      final Query<Map<String, dynamic>> query = role == 'admin'
          ? _firestore.collection('courses')
          : _firestore
                .collection('courses')
                .where('instructorId', isEqualTo: user.uid);
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      final List<Map<String, dynamic>> courses = snapshot.docs
          .map((document) {
            return {...document.data(), 'id': document.id};
          })
          .where((course) {
            final String status = (course['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            return status == 'active';
          })
          .toList();

      courses.sort((a, b) {
        final String codeA = (a['code'] ?? '').toString();

        final String codeB = (b['code'] ?? '').toString();

        return codeA.compareTo(codeB);
      });

      return courses;
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ?? 'Unable to load instructor courses.',
      );
    } catch (_) {
      throw AnnouncementServiceException('Unable to load instructor courses.');
    }
  }

  // ============================================================
  // GET CURRENT INSTRUCTOR NAME
  // ============================================================

  Future<String> _getCurrentInstructorName() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return 'Instructor';
    }

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final Map<String, dynamic>? data = document.data();

    final String firestoreName = (data?['name'] ?? '').toString().trim();

    if (firestoreName.isNotEmpty) {
      return firestoreName;
    }

    final String authName = (user.displayName ?? '').trim();

    if (authName.isNotEmpty) {
      return authName;
    }

    return 'Instructor';
  }

  // ============================================================
  // CREATE ANNOUNCEMENT
  // ============================================================

  Future<String> createAnnouncement({
    required String title,
    required String message,
    required String courseId,
    required String courseCode,
    required String courseTitle,
    required bool isUrgent,
  }) async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'You must be logged in to post an announcement.',
        );
      }

      if (title.trim().isEmpty || title.trim().length > 150) {
        throw AnnouncementServiceException(
          'Enter an announcement title of up to 150 characters.',
        );
      }

      if (message.trim().isEmpty || message.trim().length > 5000) {
        throw AnnouncementServiceException(
          'Enter an announcement message of up to 5,000 characters.',
        );
      }

      final String instructorName = await _getCurrentInstructorName();
      final role = await _getCurrentRole();

      // “All classes” for an instructor means each class they own. Creating
      // one course-scoped document per class keeps student access enforceable
      // in Firestore rules. Administrators may publish a true school-wide note.
      if (role == 'instructor' && courseId.trim().isEmpty) {
        final courses = await getInstructorCourses();
        if (courses.isEmpty) {
          throw AnnouncementServiceException(
            'Create an active course before publishing to all classes.',
          );
        }
        String? firstId;
        for (final course in courses) {
          final id = await createAnnouncement(
            title: title,
            message: message,
            courseId: (course['id'] ?? '').toString(),
            courseCode: (course['code'] ?? '').toString(),
            courseTitle: (course['title'] ?? '').toString(),
            isUrgent: isUrgent,
          );
          firstId ??= id;
        }
        return firstId!;
      }

      // ----------------------------------------------------------
      // CREATE ANNOUNCEMENT
      // ----------------------------------------------------------

      final DocumentReference<Map<String, dynamic>> announcementDocument =
          await _firestore.collection('announcements').add({
            'title': title.trim(),

            'message': message.trim(),

            'courseId': courseId.trim(),

            'courseCode': courseCode.trim(),

            'courseTitle': courseTitle.trim(),

            'targetType': courseId.trim().isEmpty ? 'all_classes' : 'course',

            'targetRole': 'student',

            'createdBy': user.uid,

            'createdByName': instructorName,

            'createdByRole': role,

            'priority': isUrgent ? 'urgent' : 'normal',

            'isUrgent': isUrgent,

            'status': 'published',

            'createdAt': FieldValue.serverTimestamp(),

            'updatedAt': FieldValue.serverTimestamp(),
          });

      // ----------------------------------------------------------
      // CREATE NOTIFICATION RECORDS FOR STUDENTS
      // ----------------------------------------------------------

      if (role == 'instructor') {
        await _notificationService.createAnnouncementNotifications(
          announcementId: announcementDocument.id,
          instructorId: user.uid,
          instructorName: instructorName,
          courseId: courseId.trim(),
          courseCode: courseCode.trim(),
          courseTitle: courseTitle.trim(),
          title: title.trim(),
          message: message.trim(),
          isUrgent: isUrgent,
        );
      }

      return announcementDocument.id;
    } on AnnouncementServiceException {
      rethrow;
    } on NotificationServiceException catch (e) {
      throw AnnouncementServiceException(e.message);
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ?? 'Unable to post announcement.',
      );
    } catch (_) {
      throw AnnouncementServiceException('Unable to post announcement.');
    }
  }

  // ============================================================
  // GET INSTRUCTOR ANNOUNCEMENTS
  // ============================================================

  Future<List<Map<String, dynamic>>> getInstructorAnnouncements() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'No instructor is currently logged in.',
        );
      }

      final role = await _getCurrentRole();
      final Query<Map<String, dynamic>> query = role == 'admin'
          ? _firestore.collection('announcements')
          : _firestore
                .collection('announcements')
                .where('createdBy', isEqualTo: user.uid);
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      final List<Map<String, dynamic>> announcements = snapshot.docs
          .map((document) {
            return {...document.data(), 'id': document.id};
          })
          .where((announcement) {
            final String status = (announcement['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            return status != 'deleted';
          })
          .toList();

      announcements.sort((a, b) {
        final dynamic createdA = a['createdAt'];

        final dynamic createdB = b['createdAt'];

        if (createdA is Timestamp && createdB is Timestamp) {
          return createdB.toDate().compareTo(createdA.toDate());
        }

        if (createdA is Timestamp) {
          return -1;
        }

        if (createdB is Timestamp) {
          return 1;
        }

        return 0;
      });

      return announcements;
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ?? 'Unable to load announcements.',
      );
    } catch (_) {
      throw AnnouncementServiceException('Unable to load announcements.');
    }
  }

  // ============================================================
  // DELETE ANNOUNCEMENT
  // ============================================================

  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'No instructor is currently logged in.',
        );
      }

      if (announcementId.trim().isEmpty) {
        throw AnnouncementServiceException('Announcement ID is missing.');
      }

      final DocumentReference<Map<String, dynamic>> reference = _firestore
          .collection('announcements')
          .doc(announcementId);

      final DocumentSnapshot<Map<String, dynamic>> document = await reference
          .get();

      if (!document.exists) {
        throw AnnouncementServiceException('Announcement could not be found.');
      }

      final Map<String, dynamic>? data = document.data();

      if (data == null) {
        throw AnnouncementServiceException('Announcement data is missing.');
      }

      final String creatorId = (data['createdBy'] ?? '').toString();

      if (creatorId != user.uid) {
        if (await _getCurrentRole() != 'admin') {
          throw AnnouncementServiceException(
            'You cannot delete this announcement.',
          );
        }
      }

      await reference.update({
        'status': 'deleted',

        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ?? 'Unable to delete announcement.',
      );
    } catch (_) {
      throw AnnouncementServiceException('Unable to delete announcement.');
    }
  }

  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String message,
    required bool isUrgent,
  }) async {
    final user = _auth.currentUser;
    final cleanTitle = title.trim();
    final cleanMessage = message.trim();
    if (user == null) {
      throw AnnouncementServiceException('Please sign in again.');
    }
    if (cleanTitle.isEmpty || cleanTitle.length > 150) {
      throw AnnouncementServiceException(
        'Enter an announcement title of up to 150 characters.',
      );
    }
    if (cleanMessage.isEmpty || cleanMessage.length > 5000) {
      throw AnnouncementServiceException(
        'Enter an announcement message of up to 5,000 characters.',
      );
    }
    try {
      final reference = _firestore
          .collection('announcements')
          .doc(announcementId);
      final snapshot = await reference.get();
      final data = snapshot.data();
      if (data == null || data['status'] == 'deleted') {
        throw AnnouncementServiceException(
          'This announcement is no longer available.',
        );
      }
      if (data['createdBy'] != user.uid) {
        final profile =
            (await _firestore.collection('users').doc(user.uid).get()).data();
        if (profile?['role'] != 'admin') {
          throw AnnouncementServiceException(
            'You cannot edit this announcement.',
          );
        }
      }
      await reference.update({
        'title': cleanTitle,
        'message': cleanMessage,
        'priority': isUrgent ? 'urgent' : 'normal',
        'isUrgent': isUrgent,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AnnouncementServiceException(
        error.message ?? 'Unable to update the announcement.',
      );
    }
  }

  // ============================================================
  // CURRENT STUDENT ACTIVE COURSE IDS
  // ============================================================

  Future<List<String>> _getCurrentStudentCourseIds() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: user.uid)
        .get();

    final List<String> courseIds = [];

    for (final document in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String status = (data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (status != 'active') {
        continue;
      }

      final String courseId = (data['courseId'] ?? '').toString().trim();

      if (courseId.isNotEmpty && !courseIds.contains(courseId)) {
        courseIds.add(courseId);
      }
    }

    return courseIds;
  }

  // ============================================================
  // GET STUDENT ANNOUNCEMENTS
  // ============================================================

  Future<List<Map<String, dynamic>>> getStudentAnnouncements() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'No student is currently logged in.',
        );
      }

      final List<String> studentCourseIds = await _getCurrentStudentCourseIds();

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('announcements')
          .where('status', isEqualTo: 'published')
          .get();

      final List<Map<String, dynamic>> results = [];

      for (final document in snapshot.docs) {
        final Map<String, dynamic> announcement = document.data();

        final String targetRole = (announcement['targetRole'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (targetRole.isNotEmpty &&
            targetRole != 'student' &&
            targetRole != 'all') {
          continue;
        }

        final String targetType = (announcement['targetType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final String courseId = (announcement['courseId'] ?? '')
            .toString()
            .trim();

        bool shouldShow = false;

        if (targetType == 'all_classes' || courseId.isEmpty) {
          shouldShow = true;
        }

        if (courseId.isNotEmpty && studentCourseIds.contains(courseId)) {
          shouldShow = true;
        }

        if (!shouldShow) {
          continue;
        }

        results.add({...announcement, 'id': document.id});
      }

      results.sort((a, b) {
        final dynamic createdA = a['createdAt'];

        final dynamic createdB = b['createdAt'];

        if (createdA is Timestamp && createdB is Timestamp) {
          return createdB.toDate().compareTo(createdA.toDate());
        }

        if (createdA is Timestamp) {
          return -1;
        }

        if (createdB is Timestamp) {
          return 1;
        }

        return 0;
      });

      return results;
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ?? 'Unable to load announcements.',
      );
    } catch (_) {
      throw AnnouncementServiceException('Unable to load announcements.');
    }
  }

  Stream<List<StudentAnnouncementNote>> watchStudentNotes() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(
        AnnouncementServiceException('Please sign in again.'),
      );
    }

    late final StreamController<List<StudentAnnouncementNote>> controller;
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final announcementBuckets = <String, Map<String, Map<String, dynamic>>>{};
    final states = <String, Map<String, dynamic>>{};

    void emit() {
      if (controller.isClosed) return;
      final unique = <String, Map<String, dynamic>>{};
      for (final bucket in announcementBuckets.values) {
        unique.addAll(bucket);
      }
      final notes =
          unique.entries
              .map(
                (entry) => StudentAnnouncementNote.fromMap(
                  id: entry.key,
                  announcement: entry.value,
                  state: states[entry.key],
                ),
              )
              .toList()
            ..sort((a, b) {
              final first = a.createdAt;
              final second = b.createdAt;
              if (first == null && second == null) return 0;
              if (first == null) return 1;
              if (second == null) return -1;
              return second.compareTo(first);
            });
      controller.add(notes);
    }

    void listenTo(String key, Query<Map<String, dynamic>> query) {
      subscriptions.add(
        query.snapshots().listen((snapshot) {
          announcementBuckets[key] = {
            for (final document in snapshot.docs) document.id: document.data(),
          };
          emit();
        }, onError: controller.addError),
      );
    }

    Future<void> start() async {
      try {
        final courseIds = await _getCurrentStudentCourseIds();
        if (controller.isClosed) return;
        subscriptions.add(
          _firestore
              .collection('announcementStates')
              .where('userId', isEqualTo: user.uid)
              .snapshots()
              .listen((snapshot) {
                states
                  ..clear()
                  ..addEntries(
                    snapshot.docs.map((document) {
                      final data = document.data();
                      return MapEntry(
                        (data['announcementId'] ?? '').toString(),
                        data,
                      );
                    }),
                  );
                emit();
              }, onError: controller.addError),
        );
        listenTo(
          'all',
          _firestore
              .collection('announcements')
              .where('status', isEqualTo: 'published')
              .where('targetType', isEqualTo: 'all_classes')
              .where('targetRole', isEqualTo: 'student')
              .where('createdByRole', isEqualTo: 'admin'),
        );
        for (final courseId in courseIds) {
          listenTo(
            courseId,
            _firestore
                .collection('announcements')
                .where('status', isEqualTo: 'published')
                .where('targetType', isEqualTo: 'course')
                .where('targetRole', isEqualTo: 'student')
                .where('courseId', isEqualTo: courseId),
          );
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<StudentAnnouncementNote>>(
      onListen: start,
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<void> markAnnouncementRead(String announcementId) async {
    await _writeStudentState(announcementId, dismiss: false);
  }

  Future<void> dismissAnnouncement(String announcementId) async {
    await _writeStudentState(announcementId, dismiss: true);
  }

  Future<void> _writeStudentState(
    String announcementId, {
    required bool dismiss,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AnnouncementServiceException('Please sign in again.');
    }
    if (announcementId.trim().isEmpty) {
      throw AnnouncementServiceException(
        'Announcement information is missing.',
      );
    }
    try {
      final reference = _firestore
          .collection('announcementStates')
          .doc('${announcementId}_${user.uid}');
      final values = <String, dynamic>{
        'announcementId': announcementId,
        'userId': user.uid,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (dismiss) values['dismissedAt'] = FieldValue.serverTimestamp();
      await reference.set(values, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw AnnouncementServiceException(
        error.message ?? 'Unable to update the announcement.',
      );
    }
  }
}

class StudentAnnouncementNote {
  const StudentAnnouncementNote({
    required this.id,
    required this.title,
    required this.message,
    required this.author,
    required this.courseLabel,
    required this.priority,
    required this.createdAt,
    required this.readAt,
    required this.dismissedAt,
  });

  final String id;
  final String title;
  final String message;
  final String author;
  final String courseLabel;
  final String priority;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;

  bool get isRead => readAt != null;
  bool get isDismissed => dismissedAt != null;
  bool get isUrgent => priority == 'urgent';

  factory StudentAnnouncementNote.fromMap({
    required String id,
    required Map<String, dynamic> announcement,
    Map<String, dynamic>? state,
  }) {
    DateTime? date(dynamic value) => value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : null;
    final code = (announcement['courseCode'] ?? '').toString().trim();
    final title = (announcement['courseTitle'] ?? '').toString().trim();
    return StudentAnnouncementNote(
      id: id,
      title: (announcement['title'] ?? 'Announcement').toString(),
      message: (announcement['message'] ?? '').toString(),
      author: (announcement['createdByName'] ?? 'CASLMS').toString(),
      courseLabel: code.isNotEmpty
          ? title.isEmpty
                ? code
                : '$code · $title'
          : title.isNotEmpty
          ? title
          : 'All classes',
      priority: (announcement['priority'] ?? 'normal').toString().toLowerCase(),
      createdAt: date(announcement['createdAt']),
      readAt: date(state?['readAt']),
      dismissedAt: date(state?['dismissedAt']),
    );
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class AnnouncementServiceException implements Exception {
  final String message;

  AnnouncementServiceException(this.message);

  @override
  String toString() => message;
}
