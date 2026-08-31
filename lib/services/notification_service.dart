import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId =>
      _auth.currentUser?.uid;

  // ============================================================
  // GET ACTIVE STUDENTS FOR ONE COURSE
  // ============================================================

  Future<Set<String>> _getActiveStudentIdsForCourse(
    String courseId,
  ) async {
    if (courseId.trim().isEmpty) {
      return <String>{};
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore
            .collection('enrollments')
            .where(
              'courseId',
              isEqualTo: courseId,
            )
            .get();

    final Set<String> studentIds =
        <String>{};

    for (final document in snapshot.docs) {
      final Map<String, dynamic> data =
          document.data();

      final String status =
          (data['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (status != 'active') {
        continue;
      }

      final String studentId =
          (data['studentId'] ?? '')
              .toString()
              .trim();

      if (studentId.isNotEmpty) {
        studentIds.add(
          studentId,
        );
      }
    }

    return studentIds;
  }

  // ============================================================
  // GET ALL STUDENTS FROM INSTRUCTOR ACTIVE COURSES
  // ============================================================

  Future<Set<String>> _getInstructorStudentIds(
    String instructorId,
  ) async {
    if (instructorId.trim().isEmpty) {
      return <String>{};
    }

    final QuerySnapshot<Map<String, dynamic>>
        courseSnapshot =
        await _firestore
            .collection('courses')
            .where(
              'instructorId',
              isEqualTo: instructorId,
            )
            .get();

    final Set<String> studentIds =
        <String>{};

    for (final courseDocument
        in courseSnapshot.docs) {
      final Map<String, dynamic> course =
          courseDocument.data();

      final String status =
          (course['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (status != 'active') {
        continue;
      }

      final Set<String> courseStudents =
          await _getActiveStudentIdsForCourse(
        courseDocument.id,
      );

      studentIds.addAll(
        courseStudents,
      );
    }

    return studentIds;
  }

  // ============================================================
  // CREATE NOTIFICATIONS FROM ANNOUNCEMENT
  // ============================================================

  Future<void> createAnnouncementNotifications({
    required String announcementId,
    required String instructorId,
    required String instructorName,
    required String courseId,
    required String courseCode,
    required String courseTitle,
    required String title,
    required String message,
    required bool isUrgent,
  }) async {
    try {
      if (announcementId.trim().isEmpty) {
        throw NotificationServiceException(
          'Announcement ID is missing.',
        );
      }

      Set<String> studentIds =
          <String>{};

      // ----------------------------------------------------------
      // SPECIFIC COURSE
      // ----------------------------------------------------------

      if (courseId.trim().isNotEmpty) {
        studentIds =
            await _getActiveStudentIdsForCourse(
          courseId,
        );
      }

      // ----------------------------------------------------------
      // ALL CLASSES OF INSTRUCTOR
      // ----------------------------------------------------------

      else {
        studentIds =
            await _getInstructorStudentIds(
          instructorId,
        );
      }

      if (studentIds.isEmpty) {
        return;
      }

      final List<String> recipients =
          studentIds.toList();

      // Firestore batch limit is 500 operations.
      const int chunkSize =
          400;

      for (
        int start = 0;
        start < recipients.length;
        start += chunkSize
      ) {
        final int end =
            start + chunkSize >
                    recipients.length
                ? recipients.length
                : start + chunkSize;

        final WriteBatch batch =
            _firestore.batch();

        for (
          int index = start;
          index < end;
          index++
        ) {
          final String studentId =
              recipients[index];

          final DocumentReference<
                  Map<String, dynamic>>
              notificationReference =
              _firestore
                  .collection(
                    'notifications',
                  )
                  .doc();

          batch.set(
            notificationReference,
            {
              // ----------------------------------------------
              // RECEIVER
              // ----------------------------------------------

              'userId':
                  studentId,

              // ----------------------------------------------
              // TYPE / SOURCE
              // ----------------------------------------------

              'type':
                  'announcement',

              'sourceType':
                  'announcement',

              'sourceId':
                  announcementId,

              // ----------------------------------------------
              // CONTENT
              // ----------------------------------------------

              'title':
                  title.trim(),

              'message':
                  message.trim(),

              // ----------------------------------------------
              // COURSE
              // ----------------------------------------------

              'courseId':
                  courseId.trim(),

              'courseCode':
                  courseCode.trim(),

              'courseTitle':
                  courseTitle.trim(),

              // ----------------------------------------------
              // CREATOR
              // ----------------------------------------------

              'actorId':
                  instructorId,

              'actorName':
                  instructorName,

              // ----------------------------------------------
              // PRIORITY
              // ----------------------------------------------

              'priority':
                  isUrgent
                      ? 'urgent'
                      : 'normal',

              'isUrgent':
                  isUrgent,

              // ----------------------------------------------
              // READ STATUS
              // ----------------------------------------------

              'isRead':
                  false,

              'readAt':
                  null,

              // ----------------------------------------------
              // TIMESTAMP
              // ----------------------------------------------

              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        }

        await batch.commit();
      }
    } on NotificationServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw NotificationServiceException(
        e.message ??
            'Unable to create notifications.',
      );
    } catch (_) {
      throw NotificationServiceException(
        'Unable to create notifications.',
      );
    }
  }

  // ============================================================
  // WATCH CURRENT USER NOTIFICATIONS
  // ============================================================

  Stream<List<Map<String, dynamic>>>
      watchMyNotifications() {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return Stream.value(
        <Map<String, dynamic>>[],
      );
    }

    return _firestore
        .collection('notifications')
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
      (snapshot) {
        final List<Map<String, dynamic>>
            notifications =
            snapshot.docs.map(
          (document) {
            return {
              ...document.data(),
              'id': document.id,
            };
          },
        ).toList();

        notifications.sort(
          (a, b) {
            final dynamic createdA =
                a['createdAt'];

            final dynamic createdB =
                b['createdAt'];

            if (createdA is Timestamp &&
                createdB is Timestamp) {
              return createdB
                  .toDate()
                  .compareTo(
                    createdA.toDate(),
                  );
            }

            if (createdA is Timestamp) {
              return -1;
            }

            if (createdB is Timestamp) {
              return 1;
            }

            return 0;
          },
        );

        return notifications;
      },
    );
  }

  // ============================================================
  // WATCH UNREAD COUNT
  // ============================================================

  Stream<int> watchUnreadCount() {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return Stream.value(
        0,
      );
    }

    return _firestore
        .collection('notifications')
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
      (snapshot) {
        int count =
            0;

        for (final document
            in snapshot.docs) {
          final Map<String, dynamic> data =
              document.data();

          if (data['isRead'] != true) {
            count++;
          }
        }

        return count;
      },
    );
  }

  // ============================================================
  // MARK ONE NOTIFICATION AS READ
  // ============================================================

  Future<void> markAsRead(
    String notificationId,
  ) async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw NotificationServiceException(
          'No user is currently logged in.',
        );
      }

      if (notificationId.trim().isEmpty) {
        return;
      }

      final DocumentReference<
              Map<String, dynamic>>
          reference =
          _firestore
              .collection('notifications')
              .doc(notificationId);

      final DocumentSnapshot<
              Map<String, dynamic>>
          document =
          await reference.get();

      if (!document.exists) {
        return;
      }

      final Map<String, dynamic>? data =
          document.data();

      if (data == null) {
        return;
      }

      final String receiverId =
          (data['userId'] ?? '')
              .toString();

      if (receiverId != user.uid) {
        throw NotificationServiceException(
          'You cannot modify this notification.',
        );
      }

      if (data['isRead'] == true) {
        return;
      }

      await reference.update({
        'isRead':
            true,

        'readAt':
            FieldValue.serverTimestamp(),
      });
    } on NotificationServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw NotificationServiceException(
        e.message ??
            'Unable to update notification.',
      );
    } catch (_) {
      throw NotificationServiceException(
        'Unable to update notification.',
      );
    }
  }

  // ============================================================
  // MARK ALL AS READ
  // ============================================================

  Future<void> markAllAsRead() async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw NotificationServiceException(
          'No user is currently logged in.',
        );
      }

      final QuerySnapshot<Map<String, dynamic>>
          snapshot =
          await _firestore
              .collection('notifications')
              .where(
                'userId',
                isEqualTo: user.uid,
              )
              .get();

      final List<
              QueryDocumentSnapshot<
                  Map<String, dynamic>>>
          unreadDocuments =
          snapshot.docs.where(
        (document) {
          return document.data()['isRead'] !=
              true;
        },
      ).toList();

      if (unreadDocuments.isEmpty) {
        return;
      }

      const int chunkSize =
          400;

      for (
        int start = 0;
        start < unreadDocuments.length;
        start += chunkSize
      ) {
        final int end =
            start + chunkSize >
                    unreadDocuments.length
                ? unreadDocuments.length
                : start + chunkSize;

        final WriteBatch batch =
            _firestore.batch();

        for (
          int index = start;
          index < end;
          index++
        ) {
          batch.update(
            unreadDocuments[index]
                .reference,
            {
              'isRead':
                  true,

              'readAt':
                  FieldValue.serverTimestamp(),
            },
          );
        }

        await batch.commit();
      }
    } on NotificationServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw NotificationServiceException(
        e.message ??
            'Unable to mark notifications as read.',
      );
    } catch (_) {
      throw NotificationServiceException(
        'Unable to mark notifications as read.',
      );
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class NotificationServiceException
    implements Exception {
  final String message;

  NotificationServiceException(
    this.message,
  );

  @override
  String toString() =>
      message;
}