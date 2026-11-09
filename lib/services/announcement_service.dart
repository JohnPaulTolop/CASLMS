import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final NotificationService _notificationService =
      NotificationService();

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId =>
      _auth.currentUser?.uid;

  // ============================================================
  // GET CURRENT INSTRUCTOR COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getInstructorCourses() async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'No instructor is currently logged in.',
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('courses')
              .where(
                'instructorId',
                isEqualTo: user.uid,
              )
              .get();

      final List<Map<String, dynamic>> courses =
          snapshot.docs
              .map(
                (document) {
                  return {
                    ...document.data(),
                    'id': document.id,
                  };
                },
              )
              .where(
                (course) {
                  final String status =
                      (course['status'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();

                  return status == 'active';
                },
              )
              .toList();

      courses.sort(
        (a, b) {
          final String codeA =
              (a['code'] ?? '')
                  .toString();

          final String codeB =
              (b['code'] ?? '')
                  .toString();

          return codeA.compareTo(
            codeB,
          );
        },
      );

      return courses;
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ??
            'Unable to load instructor courses.',
      );
    } catch (_) {
      throw AnnouncementServiceException(
        'Unable to load instructor courses.',
      );
    }
  }

  // ============================================================
  // GET CURRENT INSTRUCTOR NAME
  // ============================================================

  Future<String>
      _getCurrentInstructorName() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return 'Instructor';
    }

    final DocumentSnapshot<Map<String, dynamic>>
        document =
        await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

    final Map<String, dynamic>? data =
        document.data();

    final String firestoreName =
        (data?['name'] ?? '')
            .toString()
            .trim();

    if (firestoreName.isNotEmpty) {
      return firestoreName;
    }

    final String authName =
        (user.displayName ?? '')
            .trim();

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
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'You must be logged in to post an announcement.',
        );
      }

      if (title.trim().isEmpty) {
        throw AnnouncementServiceException(
          'Announcement title is required.',
        );
      }

      if (message.trim().isEmpty) {
        throw AnnouncementServiceException(
          'Announcement message is required.',
        );
      }

      final String instructorName =
          await _getCurrentInstructorName();

      // ----------------------------------------------------------
      // CREATE ANNOUNCEMENT
      // ----------------------------------------------------------

      final DocumentReference<Map<String, dynamic>>
          announcementDocument =
          await _firestore
              .collection('announcements')
              .add({
        'title':
            title.trim(),

        'message':
            message.trim(),

        'courseId':
            courseId.trim(),

        'courseCode':
            courseCode.trim(),

        'courseTitle':
            courseTitle.trim(),

        'targetType':
            courseId.trim().isEmpty
                ? 'all_classes'
                : 'course',

        'targetRole':
            'student',

        'createdBy':
            user.uid,

        'createdByName':
            instructorName,

        'priority':
            isUrgent
                ? 'urgent'
                : 'normal',

        'isUrgent':
            isUrgent,

        'status':
            'published',

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      // ----------------------------------------------------------
      // CREATE NOTIFICATION RECORDS FOR STUDENTS
      // ----------------------------------------------------------

      await _notificationService
          .createAnnouncementNotifications(
        announcementId:
            announcementDocument.id,

        instructorId:
            user.uid,

        instructorName:
            instructorName,

        courseId:
            courseId.trim(),

        courseCode:
            courseCode.trim(),

        courseTitle:
            courseTitle.trim(),

        title:
            title.trim(),

        message:
            message.trim(),

        isUrgent:
            isUrgent,
      );

      return announcementDocument.id;
    } on AnnouncementServiceException {
      rethrow;
    } on NotificationServiceException catch (e) {
      throw AnnouncementServiceException(
        e.message,
      );
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ??
            'Unable to post announcement.',
      );
    } catch (_) {
      throw AnnouncementServiceException(
        'Unable to post announcement.',
      );
    }
  }

  // ============================================================
  // GET INSTRUCTOR ANNOUNCEMENTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getInstructorAnnouncements() async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'No instructor is currently logged in.',
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('announcements')
              .where(
                'createdBy',
                isEqualTo: user.uid,
              )
              .get();

      final List<Map<String, dynamic>> announcements =
          snapshot.docs
              .map(
                (document) {
                  return {
                    ...document.data(),
                    'id': document.id,
                  };
                },
              )
              .where(
                (announcement) {
                  final String status =
                      (announcement['status'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();

                  return status != 'deleted';
                },
              )
              .toList();

      announcements.sort(
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

      return announcements;
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ??
            'Unable to load announcements.',
      );
    } catch (_) {
      throw AnnouncementServiceException(
        'Unable to load announcements.',
      );
    }
  }

  // ============================================================
  // DELETE ANNOUNCEMENT
  // ============================================================

  Future<void> deleteAnnouncement(
    String announcementId,
  ) async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'No instructor is currently logged in.',
        );
      }

      if (announcementId.trim().isEmpty) {
        throw AnnouncementServiceException(
          'Announcement ID is missing.',
        );
      }

      final DocumentReference<Map<String, dynamic>>
          reference =
          _firestore
              .collection('announcements')
              .doc(announcementId);

      final DocumentSnapshot<Map<String, dynamic>>
          document =
          await reference.get();

      if (!document.exists) {
        throw AnnouncementServiceException(
          'Announcement could not be found.',
        );
      }

      final Map<String, dynamic>? data =
          document.data();

      if (data == null) {
        throw AnnouncementServiceException(
          'Announcement data is missing.',
        );
      }

      final String creatorId =
          (data['createdBy'] ?? '')
              .toString();

      if (creatorId != user.uid) {
        throw AnnouncementServiceException(
          'You cannot delete this announcement.',
        );
      }

      await reference.update({
        'status':
            'deleted',

        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ??
            'Unable to delete announcement.',
      );
    } catch (_) {
      throw AnnouncementServiceException(
        'Unable to delete announcement.',
      );
    }
  }

  // ============================================================
  // CURRENT STUDENT ACTIVE COURSE IDS
  // ============================================================

  Future<List<String>>
      _getCurrentStudentCourseIds() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return [];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore
            .collection('enrollments')
            .where(
              'studentId',
              isEqualTo: user.uid,
            )
            .get();

    final List<String> courseIds =
        [];

    for (final document
        in snapshot.docs) {
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

      final String courseId =
          (data['courseId'] ?? '')
              .toString()
              .trim();

      if (courseId.isNotEmpty &&
          !courseIds.contains(
            courseId,
          )) {
        courseIds.add(
          courseId,
        );
      }
    }

    return courseIds;
  }

  // ============================================================
  // GET STUDENT ANNOUNCEMENTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getStudentAnnouncements() async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw AnnouncementServiceException(
          'No student is currently logged in.',
        );
      }

      final List<String> studentCourseIds =
          await _getCurrentStudentCourseIds();

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('announcements')
              .where(
                'status',
                isEqualTo: 'published',
              )
              .get();

      final List<Map<String, dynamic>> results =
          [];

      for (final document
          in snapshot.docs) {
        final Map<String, dynamic> announcement =
            document.data();

        final String targetRole =
            (announcement['targetRole'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (targetRole.isNotEmpty &&
            targetRole != 'student' &&
            targetRole != 'all') {
          continue;
        }

        final String targetType =
            (announcement['targetType'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        final String courseId =
            (announcement['courseId'] ?? '')
                .toString()
                .trim();

        bool shouldShow =
            false;

        if (targetType == 'all_classes' ||
            courseId.isEmpty) {
          shouldShow =
              true;
        }

        if (courseId.isNotEmpty &&
            studentCourseIds.contains(
              courseId,
            )) {
          shouldShow =
              true;
        }

        if (!shouldShow) {
          continue;
        }

        results.add({
          ...announcement,
          'id': document.id,
        });
      }

      results.sort(
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

      return results;
    } on AnnouncementServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AnnouncementServiceException(
        e.message ??
            'Unable to load announcements.',
      );
    } catch (_) {
      throw AnnouncementServiceException(
        'Unable to load announcements.',
      );
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class AnnouncementServiceException
    implements Exception {
  final String message;

  AnnouncementServiceException(
    this.message,
  );

  @override
  String toString() =>
      message;
}