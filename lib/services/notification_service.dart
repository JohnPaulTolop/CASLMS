import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;

  static const _collections = {
    'module': 'modules',
    'moduleResource': 'moduleResources',
    'assessment': 'assessments',
    'assignment': 'assignments',
    'announcement': 'announcements',
    'assessmentSubmission': 'assessmentSubmissions',
    'submission': 'submissions',
  };

  String _text(dynamic value) {
    return (value ?? '').toString().trim();
  }

  Future<Map<String, dynamic>> _document(String collection, String id) async {
    if (id.isEmpty || id.contains('/')) {
      throw NotificationServiceException('Missing or invalid $collection ID.');
    }

    final snapshot = await _firestore.collection(collection).doc(id).get();

    final data = snapshot.data();

    if (data == null) {
      throw NotificationServiceException(
        'The $collection item no longer exists.',
      );
    }

    return data;
  }

  // New published module.
  Future<void> createModuleNotifications({required String moduleId}) {
    return createSourceNotifications(sourceType: 'module', sourceId: moduleId);
  }

  // New published file, link, or video.
  Future<void> createLearningMaterialNotifications({
    required String resourceId,
  }) {
    return createSourceNotifications(
      sourceType: 'moduleResource',
      sourceId: resourceId,
    );
  }

  // Published quiz, assignment, activity, exam, or summative assessment.
  Future<void> createAssessmentNotifications({required String assessmentId}) {
    return createSourceNotifications(
      sourceType: 'assessment',
      sourceId: assessmentId,
    );
  }

  // Notify only the student whose assessment submission was graded.
  Future<void> createAssessmentGradeNotification({
    required String submissionId,
  }) {
    return createSourceNotifications(
      sourceType: 'assessmentSubmission',
      sourceId: submissionId,
    );
  }

  // Support the older assignments/submissions collections.
  Future<void> createLegacyAssignmentGradeNotification({
    required String submissionId,
  }) {
    return createSourceNotifications(
      sourceType: 'submission',
      sourceId: submissionId,
    );
  }

  // Preserve compatibility with your existing AnnouncementService.
  // Authoritative content and recipients are loaded from Firestore.
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
  }) {
    return createSourceNotifications(
      sourceType: 'announcement',
      sourceId: announcementId,
    );
  }

  // Retry missing notifications without duplicating existing ones.
  Future<void> retryModuleNotifications({required String moduleId}) async {
    final module = await _document('modules', moduleId);

    final course = await _document('courses', _text(module['courseId']));

    if (currentUserId == null || course['instructorId'] != currentUserId) {
      throw NotificationServiceException(
        'Only the course instructor can retry delivery.',
      );
    }

    await createModuleNotifications(moduleId: moduleId);

    const sources = {
      'moduleResources': 'moduleResource',
      'assessments': 'assessment',
      'assessmentSubmissions': 'assessmentSubmission',
    };

    for (final entry in sources.entries) {
      final snapshot = await _firestore
          .collection(entry.key)
          .where('moduleId', isEqualTo: moduleId)
          .get();

      for (final document in snapshot.docs) {
        if (document.data()['courseId'] != module['courseId']) {
          continue;
        }

        await createSourceNotifications(
          sourceType: entry.value,
          sourceId: document.id,
        );
      }
    }
  }

  Future<void> createSourceNotifications({
    required String sourceType,
    required String sourceId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw NotificationServiceException('Sign in to send notifications.');
    }

    final collection = _collections[sourceType];

    if (collection == null) {
      throw NotificationServiceException('Invalid notification source.');
    }

    final profile = await _document('users', user.uid);

    if (profile['role'] != 'instructor' || profile['status'] != 'active') {
      throw NotificationServiceException(
        'An active instructor account is required.',
      );
    }

    final source = await _document(collection, sourceId);

    final isGrade =
        sourceType == 'assessmentSubmission' || sourceType == 'submission';

    final isAnnouncement = sourceType == 'announcement';

    Map<String, dynamic> item = source;

    if (isGrade) {
      // Only manually graded work from this instructor is eligible.
      if (source['status'] != 'graded' ||
          source['gradedBy'] != user.uid ||
          source['gradingMode'] == 'automatic') {
        return;
      }

      final isLegacySubmission = sourceType == 'submission';

      item = await _document(
        isLegacySubmission ? 'assignments' : 'assessments',
        _text(source[isLegacySubmission ? 'assignmentId' : 'assessmentId']),
      );

      if (source['courseId'] != item['courseId']) {
        throw NotificationServiceException(
          'Submission course does not match its activity.',
        );
      }
    } else if (source['status'] != 'published') {
      // Draft activities must not notify students.
      return;
    }

    if (isAnnouncement && source['createdBy'] != user.uid) {
      throw NotificationServiceException(
        'Only the author can send announcement notices.',
      );
    }

    final courseId = _text(item['courseId']);

    // Only students in the published AI quiz's section
    // should receive its assessment notification.
    final bool isSectionScopedAiQuiz =
        sourceType == 'assessment' &&
        _text(item['assessmentType']).toLowerCase() == 'quiz' &&
        _text(item['deliveryType']).toLowerCase() == 'ai_generated';

    final String targetSectionId = isSectionScopedAiQuiz
        ? _text(item['sectionId'])
        : '';

    if (isSectionScopedAiQuiz && targetSectionId.isEmpty) {
      throw NotificationServiceException(
        'This AI quiz has no section assignment. '
        'Notifications were not sent.',
      );
    }

    final allClasses =
        isAnnouncement &&
        source['targetType'] == 'all_classes' &&
        courseId.isEmpty;

    final courses = <String, Map<String, dynamic>>{};

    if (allClasses) {
      final snapshot = await _firestore
          .collection('courses')
          .where('instructorId', isEqualTo: user.uid)
          .get();

      for (final document in snapshot.docs) {
        if (document.data()['status'] == 'active') {
          courses[document.id] = document.data();
        }
      }
    } else {
      courses[courseId] = await _document('courses', courseId);
    }

    // studentId -> courseId proving the instructor's audience.
    final recipients = <String, String>{};

    final courseIds = courses.keys.toList()..sort();

    for (final id in courseIds) {
      final course = courses[id]!;

      if (course['instructorId'] != user.uid) {
        throw NotificationServiceException(
          'You can only notify your own courses.',
        );
      }

      if (isGrade) {
        final studentId = _text(source['studentId']);

        if (studentId.isEmpty) {
          throw NotificationServiceException('Submission student is missing.');
        }

        // A grade belongs only to this submission's student.
        recipients[studentId] = id;
      } else {
        final enrollments = await _firestore
            .collection('enrollments')
            .where('courseId', isEqualTo: id)
            .get();

        for (final enrollment in enrollments.docs) {
          final data = enrollment.data();
          final studentId = _text(data['studentId']);

          if (data['status'] == 'active' &&
              studentId.isNotEmpty &&
              enrollment.id == '${id}_$studentId' &&
              (!isSectionScopedAiQuiz ||
                  _text(data['sectionId']) == targetSectionId)) {
            recipients.putIfAbsent(studentId, () => id);
          }
        }
      }
    }

    final profileName = _text(profile['name']);

    final actorName = profileName.isEmpty ? 'Your instructor' : profileName;

    final itemTitle = _text(item['title']);

    final type = isGrade
        ? 'grade'
        : sourceType == 'moduleResource'
        ? 'resource'
        : sourceType;

    for (final recipient in recipients.entries) {
      final course = courses[recipient.value]!;
      final courseCode = _text(course['code']);
      final courseTitle = _text(course['title']);

      final courseLabel = courseCode.isEmpty ? courseTitle : courseCode;

      final activityType = _text(item['assessmentType']);

      final String title;

      if (isGrade) {
        title = 'Graded: $itemTitle';
      } else if (isAnnouncement) {
        title = itemTitle;
      } else {
        final activityLabel = type == 'assessment' && activityType.isNotEmpty
            ? activityType
            : type;

        title = 'New $activityLabel: $itemTitle';
      }

      final totalPoints =
          item[sourceType == 'submission' ? 'points' : 'totalPoints'];

      final score = _text(source['score']);

      final String message;

      if (isGrade) {
        final totalLabel = totalPoints == null ? '' : '/$totalPoints';

        message =
            '$actorName graded your work. '
            'Score: $score$totalLabel.';
      } else if (isAnnouncement) {
        message = _text(source['message']);
      } else {
        message =
            '$actorName published "$itemTitle" '
            'in $courseLabel.';
      }

      final notificationId = '${sourceType}_${sourceId}_${recipient.key}';

      final reference = _firestore
          .collection('notifications')
          .doc(notificationId);

      final isUrgent = isAnnouncement && source['isUrgent'] == true;

      // Stable IDs prevent duplicate notifications.
      // Retrying never resets an existing notification's read status.
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);

        if (existing.exists) {
          return;
        }

        transaction.set(reference, {
          'userId': recipient.key,
          'type': type,
          'sourceType': sourceType,
          'sourceId': sourceId,
          'title': title,
          'message': message,
          'courseId': allClasses ? '' : recipient.value,
          'authorizationCourseId': recipient.value,
          'courseCode': allClasses ? '' : courseCode,
          'courseTitle': allClasses ? '' : courseTitle,
          'moduleId': sourceType == 'module'
              ? sourceId
              : _text(item['moduleId']),
          'activityType': activityType,
          'actorId': user.uid,
          'actorName': actorName,
          'priority': isUrgent ? 'urgent' : 'normal',
          'isUrgent': isUrgent,
          'isRead': false,
          'readAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  Stream<List<Map<String, dynamic>>> watchMyNotifications() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs.map((document) {
            return <String, dynamic>{...document.data(), 'id': document.id};
          }).toList();

          notifications.sort((a, b) {
            final createdA = a['createdAt'];
            final createdB = b['createdAt'];

            if (createdA is Timestamp && createdB is Timestamp) {
              return createdB.compareTo(createdA);
            }

            if (createdA is Timestamp) return -1;
            if (createdB is Timestamp) return 1;

            return 0;
          });

          return notifications;
        });
  }

  Stream<int> watchUnreadCount() {
    return watchMyNotifications().map(
      (notifications) => notifications
          .where((notification) => notification['isRead'] != true)
          .length,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw NotificationServiceException('No user is currently logged in.');
    }

    if (notificationId.trim().isEmpty) {
      return;
    }

    final reference = _firestore
        .collection('notifications')
        .doc(notificationId);

    final document = await reference.get();
    final data = document.data();

    if (data == null) {
      return;
    }

    if (data['userId'] != user.uid) {
      throw NotificationServiceException(
        'You cannot modify this notification.',
      );
    }

    if (data['isRead'] == true) {
      return;
    }

    await reference.update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw NotificationServiceException('No user is currently logged in.');
    }

    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .get();

    final unread = snapshot.docs
        .where((document) => document.data()['isRead'] != true)
        .toList();

    const chunkSize = 400;

    for (int start = 0; start < unread.length; start += chunkSize) {
      final end = start + chunkSize > unread.length
          ? unread.length
          : start + chunkSize;

      final batch = _firestore.batch();

      for (int index = start; index < end; index++) {
        batch.update(unread[index].reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }
}

class NotificationServiceException implements Exception {
  NotificationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
