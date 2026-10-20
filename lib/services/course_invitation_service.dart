import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseInvitationService {
  CourseInvitationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String normalizeCampusId(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '');
  }

  Future<Map<String, dynamic>> inviteStudentByCampusId({
    required String courseId,
    required String campusId,
  }) async {
    final user = _auth.currentUser;
    final cleanCourseId = courseId.trim();
    final cleanCampusId = normalizeCampusId(campusId);

    if (user == null) {
      throw CourseInvitationException('No instructor is currently logged in.');
    }
    if (cleanCourseId.isEmpty) {
      throw CourseInvitationException('Course information is missing.');
    }
    if (!RegExp(r'^\d{5,12}$').hasMatch(cleanCampusId)) {
      throw CourseInvitationException(
        'Campus ID must contain 5–12 numeric digits.',
      );
    }

    try {
      final instructorDocument = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final instructor = instructorDocument.data();

      if (instructor == null ||
          (instructor['role'] ?? '').toString().toLowerCase() != 'instructor' ||
          (instructor['status'] ?? '').toString().toLowerCase() != 'active') {
        throw CourseInvitationException(
          'Only an active instructor can invite students.',
        );
      }

      final courseDocument = await _firestore
          .collection('courses')
          .doc(cleanCourseId)
          .get();
      final course = courseDocument.data();

      if (course == null) {
        throw CourseInvitationException('Course could not be found.');
      }
      if ((course['instructorId'] ?? '').toString() != user.uid) {
        throw CourseInvitationException(
          'You can only invite students to your own course.',
        );
      }
      if ((course['status'] ?? '').toString().toLowerCase() != 'active') {
        throw CourseInvitationException(
          'Students cannot be invited to an inactive course.',
        );
      }

      final studentSnapshot = await _firestore
          .collection('users')
          .where('universityId', isEqualTo: cleanCampusId)
          .limit(2)
          .get();

      if (studentSnapshot.docs.isEmpty) {
        throw CourseInvitationException(
          'No registered student uses Campus ID $cleanCampusId.',
        );
      }

      final matchingStudents = studentSnapshot.docs.where((document) {
        final data = document.data();
        return (data['role'] ?? '').toString().toLowerCase() == 'student' &&
            (data['status'] ?? '').toString().toLowerCase() == 'active';
      }).toList();

      if (matchingStudents.isEmpty) {
        throw CourseInvitationException(
          'That Campus ID does not belong to an active student account.',
        );
      }
      if (matchingStudents.length > 1) {
        throw CourseInvitationException(
          'More than one student uses this Campus ID. Ask an administrator to correct the accounts.',
        );
      }

      final studentDocument = matchingStudents.single;
      final student = studentDocument.data();
      final studentId = studentDocument.id;
      final invitationId = '${cleanCourseId}_$studentId';
      final invitationReference = _firestore
          .collection('courseInvitations')
          .doc(invitationId);
      final enrollmentReference = _firestore
          .collection('enrollments')
          .doc(invitationId);

      await _firestore.runTransaction<void>((transaction) async {
        final currentInvitation = await transaction.get(invitationReference);
        final currentEnrollment = await transaction.get(enrollmentReference);

        final enrollmentStatus = (currentEnrollment.data()?['status'] ?? '')
            .toString()
            .toLowerCase();
        if (enrollmentStatus == 'active') {
          throw CourseInvitationException(
            'This student is already enrolled in the course.',
          );
        }

        final invitationStatus = (currentInvitation.data()?['status'] ?? '')
            .toString()
            .toLowerCase();
        if (invitationStatus == 'pending') {
          throw CourseInvitationException(
            'This student already has a pending invitation.',
          );
        }
        if (currentInvitation.exists) {
          transaction.update(invitationReference, {
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'respondedAt': null,
          });
        } else {
          transaction.set(invitationReference, {
            'courseId': cleanCourseId,
            'courseCode': (course['code'] ?? '').toString().trim(),
            'courseTitle': (course['title'] ?? 'Course').toString().trim(),
            'instructorId': user.uid,
            'instructorName':
                (instructor['name'] ?? course['instructorName'] ?? 'Instructor')
                    .toString()
                    .trim(),
            'studentId': studentId,
            'studentCampusId': cleanCampusId,
            'studentName': (student['name'] ?? 'Student').toString().trim(),
            'studentEmail': (student['email'] ?? '').toString().trim(),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'respondedAt': null,
          });
        }
      });

      return {
        'id': invitationId,
        'invitationId': invitationId,
        'courseId': cleanCourseId,
        'courseCode': (course['code'] ?? '').toString().trim(),
        'courseTitle': (course['title'] ?? 'Course').toString().trim(),
        'studentId': studentId,
        'studentCampusId': cleanCampusId,
        'studentName': (student['name'] ?? 'Student').toString().trim(),
        'studentEmail': (student['email'] ?? '').toString().trim(),
        'status': 'pending',
      };
    } on CourseInvitationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw CourseInvitationException(
        error.message ?? 'Unable to send the course invitation.',
      );
    } catch (_) {
      throw CourseInvitationException('Unable to send the course invitation.');
    }
  }

  Future<List<Map<String, dynamic>>> getCourseInvitations({
    required String courseId,
  }) async {
    final cleanCourseId = courseId.trim();
    if (cleanCourseId.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('courseInvitations')
          .where('courseId', isEqualTo: cleanCourseId)
          .get();
      final invitations = snapshot.docs
          .map(
            (document) => {
              ...document.data(),
              'id': document.id,
              'invitationId': document.id,
            },
          )
          .toList();

      invitations.sort((left, right) {
        final leftDate = _dateFrom(left['updatedAt']);
        final rightDate = _dateFrom(right['updatedAt']);
        if (leftDate == null && rightDate == null) return 0;
        if (leftDate == null) return 1;
        if (rightDate == null) return -1;
        return rightDate.compareTo(leftDate);
      });
      return invitations;
    } on FirebaseException catch (error) {
      throw CourseInvitationException(
        error.message ?? 'Unable to load course invitations.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getMyPendingInvitations() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw CourseInvitationException('No student is currently logged in.');
    }

    try {
      final snapshot = await _firestore
          .collection('courseInvitations')
          .where('studentId', isEqualTo: user.uid)
          .get();

      final invitations = snapshot.docs
          .where(
            (document) =>
                (document.data()['status'] ?? '').toString().toLowerCase() ==
                'pending',
          )
          .map(
            (document) => {
              ...document.data(),
              'id': document.id,
              'invitationId': document.id,
            },
          )
          .toList();

      invitations.sort((left, right) {
        final leftDate = _dateFrom(left['createdAt']);
        final rightDate = _dateFrom(right['createdAt']);
        if (leftDate == null && rightDate == null) return 0;
        if (leftDate == null) return 1;
        if (rightDate == null) return -1;
        return rightDate.compareTo(leftDate);
      });
      return invitations;
    } on FirebaseException catch (error) {
      throw CourseInvitationException(
        error.message ?? 'Unable to load your course invitations.',
      );
    }
  }

  Future<Map<String, dynamic>> acceptInvitation(String invitationId) async {
    return _respondToInvitation(invitationId: invitationId, accept: true);
  }

  Future<Map<String, dynamic>> declineInvitation(String invitationId) async {
    return _respondToInvitation(invitationId: invitationId, accept: false);
  }

  Future<Map<String, dynamic>> _respondToInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    final user = _auth.currentUser;
    final cleanInvitationId = invitationId.trim();
    if (user == null) {
      throw CourseInvitationException('No student is currently logged in.');
    }
    if (cleanInvitationId.isEmpty) {
      throw CourseInvitationException('Invitation information is missing.');
    }

    final invitationReference = _firestore
        .collection('courseInvitations')
        .doc(cleanInvitationId);

    try {
      return await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final invitationDocument = await transaction.get(invitationReference);
        final invitation = invitationDocument.data();

        if (invitation == null) {
          throw CourseInvitationException('This invitation no longer exists.');
        }
        if ((invitation['studentId'] ?? '').toString() != user.uid) {
          throw CourseInvitationException(
            'This invitation belongs to another student.',
          );
        }
        if ((invitation['status'] ?? '').toString().toLowerCase() !=
            'pending') {
          throw CourseInvitationException(
            'This invitation has already been answered.',
          );
        }

        final courseId = (invitation['courseId'] ?? '').toString().trim();
        if (courseId.isEmpty ||
            cleanInvitationId != '${courseId}_${user.uid}') {
          throw CourseInvitationException('This invitation is invalid.');
        }

        final profileReference = _firestore.collection('users').doc(user.uid);
        final courseReference = _firestore.collection('courses').doc(courseId);
        final enrollmentReference = _firestore
            .collection('enrollments')
            .doc('${courseId}_${user.uid}');

        final profileDocument = await transaction.get(profileReference);
        final courseDocument = await transaction.get(courseReference);
        final enrollmentDocument = await transaction.get(enrollmentReference);
        final profile = profileDocument.data();
        final course = courseDocument.data();

        if (profile == null ||
            (profile['role'] ?? '').toString().toLowerCase() != 'student' ||
            (profile['status'] ?? '').toString().toLowerCase() != 'active' ||
            (profile['universityId'] ?? '').toString() !=
                (invitation['studentCampusId'] ?? '').toString()) {
          throw CourseInvitationException(
            'Your student profile no longer matches this invitation.',
          );
        }
        if (course == null ||
            (course['status'] ?? '').toString().toLowerCase() != 'active' ||
            (course['instructorId'] ?? '').toString() !=
                (invitation['instructorId'] ?? '').toString()) {
          throw CourseInvitationException(
            'This course is no longer accepting invitations.',
          );
        }

        if (accept) {
          transaction.set(enrollmentReference, {
            'courseId': courseId,
            'studentId': user.uid,
            'studentName': (profile['name'] ?? 'Student').toString().trim(),
            'studentCampusId': (profile['universityId'] ?? '')
                .toString()
                .trim(),
            'status': 'active',
            'enrollmentSource': 'instructor_invitation',
            'sectionId': (course['classCode'] ?? '').toString().trim(),
            'invitationId': cleanInvitationId,
            'invitedBy': (invitation['instructorId'] ?? '').toString(),
            'enrolledAt': FieldValue.serverTimestamp(),
            'acceptedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: enrollmentDocument.exists));
        }

        transaction.update(invitationReference, {
          'status': accept ? 'accepted' : 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return {
          ...invitation,
          'id': cleanInvitationId,
          'invitationId': cleanInvitationId,
          'status': accept ? 'accepted' : 'declined',
        };
      });
    } on CourseInvitationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw CourseInvitationException(
        error.message ?? 'Unable to answer the course invitation.',
      );
    } catch (_) {
      throw CourseInvitationException(
        'Unable to answer the course invitation.',
      );
    }
  }

  Future<void> cancelInvitation(String invitationId) async {
    final cleanId = invitationId.trim();
    if (cleanId.isEmpty) {
      throw CourseInvitationException('Invitation information is missing.');
    }

    try {
      await _firestore.collection('courseInvitations').doc(cleanId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw CourseInvitationException(
        error.message ?? 'Unable to cancel the invitation.',
      );
    }
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class CourseInvitationException implements Exception {
  const CourseInvitationException(this.message);

  final String message;

  @override
  String toString() => message;
}
