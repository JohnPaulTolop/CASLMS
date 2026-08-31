import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
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
  // CONVERSATION ID
  //
  // Format:
  // courseId_instructorId_studentId
  //
  // This prevents the same instructor/student pair from mixing
  // conversations when they share multiple courses.
  // ============================================================

  String buildConversationId({
    required String courseId,
    required String instructorId,
    required String studentId,
  }) {
    final String cleanCourseId =
        courseId.trim();

    final String cleanInstructorId =
        instructorId.trim();

    final String cleanStudentId =
        studentId.trim();

    if (cleanCourseId.isEmpty ||
        cleanInstructorId.isEmpty ||
        cleanStudentId.isEmpty) {
      return '';
    }

    return '${cleanCourseId}_${cleanInstructorId}_$cleanStudentId';
  }

  // ============================================================
  // CURRENT USER PROFILE
  // ============================================================

  Future<Map<String, dynamic>?>
      getCurrentUserProfile() async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>>
          document =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      if (!document.exists ||
          document.data() == null) {
        return null;
      }

      return {
        ...document.data()!,
        'id': document.id,
      };
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ??
            'Unable to load user profile.',
      );
    } catch (_) {
      throw ChatServiceException(
        'Unable to load user profile.',
      );
    }
  }

  // ============================================================
  // GET USER BY ID
  // ============================================================

  Future<Map<String, dynamic>?> getUserById(
    String userId,
  ) async {
    try {
      final String cleanUserId =
          userId.trim();

      if (cleanUserId.isEmpty) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>>
          document =
          await _firestore
              .collection('users')
              .doc(cleanUserId)
              .get();

      if (!document.exists ||
          document.data() == null) {
        return null;
      }

      return {
        ...document.data()!,
        'id': document.id,
      };
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ??
            'Unable to load user information.',
      );
    } catch (_) {
      throw ChatServiceException(
        'Unable to load user information.',
      );
    }
  }

  // ============================================================
  // GET COURSE BY ID
  // ============================================================

  Future<Map<String, dynamic>?> getCourseById(
    String courseId,
  ) async {
    try {
      final String cleanCourseId =
          courseId.trim();

      if (cleanCourseId.isEmpty) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>>
          document =
          await _firestore
              .collection('courses')
              .doc(cleanCourseId)
              .get();

      if (!document.exists ||
          document.data() == null) {
        return null;
      }

      return {
        ...document.data()!,
        'id': document.id,
      };
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ??
            'Unable to load course information.',
      );
    } catch (_) {
      throw ChatServiceException(
        'Unable to load course information.',
      );
    }
  }

  // ============================================================
  // GET STUDENT CHAT CONTACTS
  //
  // Each active enrollment becomes one possible course chat.
  //
  // Example:
  //
  // IT301 -> Instructor A
  // IT401 -> Instructor A
  //
  // These remain separate conversations.
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getStudentChatContacts() async {
    try {
      final User? studentUser =
          _auth.currentUser;

      if (studentUser == null) {
        throw ChatServiceException(
          'No student is currently logged in.',
        );
      }

      // ----------------------------------------------------------
      // STUDENT PROFILE
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>>
          studentDocument =
          await _firestore
              .collection('users')
              .doc(studentUser.uid)
              .get();

      final Map<String, dynamic>? studentData =
          studentDocument.data();

      final String studentName =
          (studentData?['name'] ??
                  'Student')
              .toString();

      // ----------------------------------------------------------
      // STUDENT ENROLLMENTS
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>>
          enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where(
                'studentId',
                isEqualTo: studentUser.uid,
              )
              .get();

      final List<Map<String, dynamic>>
          contacts =
          [];

      final Set<String>
          addedContactKeys =
          {};

      for (final enrollmentDocument
          in enrollmentSnapshot.docs) {
        final Map<String, dynamic>
            enrollment =
            enrollmentDocument.data();

        // --------------------------------------------------------
        // ACTIVE ENROLLMENTS ONLY
        // --------------------------------------------------------

        final String enrollmentStatus =
            (enrollment['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (enrollmentStatus != 'active') {
          continue;
        }

        final String courseId =
            (enrollment['courseId'] ?? '')
                .toString()
                .trim();

        if (courseId.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // COURSE
        // --------------------------------------------------------

        final DocumentSnapshot<Map<String, dynamic>>
            courseDocument =
            await _firestore
                .collection('courses')
                .doc(courseId)
                .get();

        if (!courseDocument.exists ||
            courseDocument.data() == null) {
          continue;
        }

        final Map<String, dynamic> course =
            courseDocument.data()!;

        final String courseStatus =
            (course['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (courseStatus != 'active') {
          continue;
        }

        final String instructorId =
            (course['instructorId'] ?? '')
                .toString()
                .trim();

        if (instructorId.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // PREVENT DUPLICATE COURSE/INSTRUCTOR CONTACTS
        // --------------------------------------------------------

        final String contactKey =
            '${courseId}_$instructorId';

        if (addedContactKeys
            .contains(contactKey)) {
          continue;
        }

        // --------------------------------------------------------
        // INSTRUCTOR
        // --------------------------------------------------------

        final DocumentSnapshot<Map<String, dynamic>>
            instructorDocument =
            await _firestore
                .collection('users')
                .doc(instructorId)
                .get();

        if (!instructorDocument.exists ||
            instructorDocument.data() ==
                null) {
          continue;
        }

        final Map<String, dynamic>
            instructor =
            instructorDocument.data()!;

        final String instructorRole =
            (instructor['role'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (instructorRole !=
            'instructor') {
          continue;
        }

        final String instructorStatus =
            (instructor['status'] ??
                    'active')
                .toString()
                .trim()
                .toLowerCase();

        if (instructorStatus !=
            'active') {
          continue;
        }

        addedContactKeys.add(
          contactKey,
        );

        contacts.add({
          // ------------------------------------------------------
          // COURSE
          // ------------------------------------------------------

          'courseId':
              courseId,

          'courseCode':
              (course['code'] ?? '')
                  .toString(),

          'courseTitle':
              (course['title'] ??
                      'Course')
                  .toString(),

          // ------------------------------------------------------
          // STUDENT
          // ------------------------------------------------------

          'studentId':
              studentUser.uid,

          'studentName':
              studentName,

          // ------------------------------------------------------
          // INSTRUCTOR
          // ------------------------------------------------------

          'instructorId':
              instructorId,

          'instructorName':
              (instructor['name'] ??
                      course[
                          'instructorName'] ??
                      'Instructor')
                  .toString(),

          'instructorEmail':
              (instructor['email'] ?? '')
                  .toString(),

          'profileImageUrl':
              (instructor[
                          'profileImageUrl'] ??
                      '')
                  .toString(),
        });
      }

      // ----------------------------------------------------------
      // SORT CONTACTS
      // ----------------------------------------------------------

      contacts.sort(
        (
          a,
          b,
        ) {
          final String courseA =
              (a['courseCode'] ?? '')
                  .toString()
                  .toLowerCase();

          final String courseB =
              (b['courseCode'] ?? '')
                  .toString()
                  .toLowerCase();

          final int courseCompare =
              courseA.compareTo(
            courseB,
          );

          if (courseCompare != 0) {
            return courseCompare;
          }

          final String instructorA =
              (a['instructorName'] ??
                      '')
                  .toString()
                  .toLowerCase();

          final String instructorB =
              (b['instructorName'] ??
                      '')
                  .toString()
                  .toLowerCase();

          return instructorA.compareTo(
            instructorB,
          );
        },
      );

      return contacts;
    } on ChatServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ??
            'Unable to load instructors.',
      );
    } catch (_) {
      throw ChatServiceException(
        'Unable to load instructors.',
      );
    }
  }

  // ============================================================
  // ENSURE CONVERSATION EXISTS
  // ============================================================

  Future<String> ensureConversation({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
  }) async {
    try {
      final String cleanCourseId =
          courseId.trim();

      final String cleanStudentId =
          studentId.trim();

      final String cleanInstructorId =
          instructorId.trim();

      if (cleanCourseId.isEmpty) {
        throw ChatServiceException(
          'Course ID is missing.',
        );
      }

      if (cleanStudentId.isEmpty) {
        throw ChatServiceException(
          'Student ID is missing.',
        );
      }

      if (cleanInstructorId.isEmpty) {
        throw ChatServiceException(
          'Instructor ID is missing.',
        );
      }

      final String conversationId =
          buildConversationId(
        courseId:
            cleanCourseId,
        instructorId:
            cleanInstructorId,
        studentId:
            cleanStudentId,
      );

      final DocumentReference<Map<String, dynamic>>
          conversationReference =
          _firestore
              .collection('conversations')
              .doc(conversationId);

      final DocumentSnapshot<Map<String, dynamic>>
          existing =
          await conversationReference
              .get();

      // ----------------------------------------------------------
      // NEW CONVERSATION
      // ----------------------------------------------------------

      if (!existing.exists) {
        await conversationReference
            .set({
          'courseId':
              cleanCourseId,

          'participantIds': [
            cleanInstructorId,
            cleanStudentId,
          ],

          'instructorId':
              cleanInstructorId,

          'instructorName':
              instructorName
                      .trim()
                      .isEmpty
                  ? 'Instructor'
                  : instructorName
                      .trim(),

          'studentId':
              cleanStudentId,

          'studentName':
              studentName
                      .trim()
                      .isEmpty
                  ? 'Student'
                  : studentName
                      .trim(),

          'lastMessage':
              '',

          'lastMessageAt':
              null,

          'createdAt':
              FieldValue
                  .serverTimestamp(),

          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        });

        return conversationId;
      }

      // ----------------------------------------------------------
      // EXISTING CONVERSATION
      //
      // Update names/participant info without overwriting
      // lastMessage, lastMessageAt, createdAt, etc.
      // ----------------------------------------------------------

      await conversationReference.set(
        {
          'courseId':
              cleanCourseId,

          'participantIds': [
            cleanInstructorId,
            cleanStudentId,
          ],

          'instructorId':
              cleanInstructorId,

          'instructorName':
              instructorName
                      .trim()
                      .isEmpty
                  ? 'Instructor'
                  : instructorName
                      .trim(),

          'studentId':
              cleanStudentId,

          'studentName':
              studentName
                      .trim()
                      .isEmpty
                  ? 'Student'
                  : studentName
                      .trim(),

          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      return conversationId;
    } on ChatServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ??
            'Unable to open conversation.',
      );
    } catch (_) {
      throw ChatServiceException(
        'Unable to open conversation.',
      );
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> sendMessage({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
    required String receiverId,
    required String text,
  }) async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw ChatServiceException(
          'You must be logged in to send a message.',
        );
      }

      final String cleanCourseId =
          courseId.trim();

      final String cleanStudentId =
          studentId.trim();

      final String cleanInstructorId =
          instructorId.trim();

      final String cleanReceiverId =
          receiverId.trim();

      final String cleanText =
          text.trim();

      if (cleanText.isEmpty) {
        return;
      }

      if (cleanCourseId.isEmpty ||
          cleanStudentId.isEmpty ||
          cleanInstructorId.isEmpty) {
        throw ChatServiceException(
          'Conversation information is incomplete.',
        );
      }

      // ----------------------------------------------------------
      // CURRENT USER MUST BE A PARTICIPANT
      // ----------------------------------------------------------

      if (user.uid != cleanStudentId &&
          user.uid !=
              cleanInstructorId) {
        throw ChatServiceException(
          'You are not part of this conversation.',
        );
      }

      // ----------------------------------------------------------
      // DETERMINE CORRECT RECEIVER
      // ----------------------------------------------------------

      final String expectedReceiverId =
          user.uid == cleanInstructorId
              ? cleanStudentId
              : cleanInstructorId;

      if (cleanReceiverId !=
          expectedReceiverId) {
        throw ChatServiceException(
          'Invalid message receiver.',
        );
      }

      // ----------------------------------------------------------
      // ENSURE CONVERSATION
      // ----------------------------------------------------------

      final String conversationId =
          await ensureConversation(
        courseId:
            cleanCourseId,
        studentId:
            cleanStudentId,
        studentName:
            studentName,
        instructorId:
            cleanInstructorId,
        instructorName:
            instructorName,
      );

      final DocumentReference<Map<String, dynamic>>
          conversationReference =
          _firestore
              .collection('conversations')
              .doc(conversationId);

      final DocumentReference<Map<String, dynamic>>
          messageReference =
          conversationReference
              .collection('messages')
              .doc();

      // ----------------------------------------------------------
      // ATOMIC MESSAGE + CONVERSATION UPDATE
      // ----------------------------------------------------------

      final WriteBatch batch =
          _firestore.batch();

      batch.set(
        messageReference,
        {
          'senderId':
              user.uid,

          'receiverId':
              cleanReceiverId,

          'text':
              cleanText,

          'sentAt':
              FieldValue
                  .serverTimestamp(),

          'isRead':
              false,
        },
      );

      batch.update(
        conversationReference,
        {
          'lastMessage':
              cleanText,

          'lastMessageAt':
              FieldValue
                  .serverTimestamp(),

          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      await batch.commit();
    } on ChatServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ??
            'Unable to send message.',
      );
    } catch (_) {
      throw ChatServiceException(
        'Unable to send message.',
      );
    }
  }

  // ============================================================
  // WATCH MESSAGES
  // ============================================================

  Stream<List<Map<String, dynamic>>> watchMessages({
    required String courseId,
    required String instructorId,
    required String studentId,
  }) {
    final String conversationId =
        buildConversationId(
      courseId:
          courseId,
      instructorId:
          instructorId,
      studentId:
          studentId,
    );

    if (conversationId.isEmpty) {
      return Stream.value(
        <Map<String, dynamic>>[],
      );
    }

    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy(
          'sentAt',
          descending: false,
        )
        .snapshots()
        .map(
      (
        snapshot,
      ) {
        return snapshot.docs
            .map(
          (
            document,
          ) {
            return {
              ...document.data(),
              'id': document.id,
            };
          },
        ).toList();
      },
    );
  }

  // ============================================================
  // MARK RECEIVED MESSAGES AS READ
  // ============================================================

  Future<void> markMessagesAsRead({
    required String courseId,
    required String instructorId,
    required String studentId,
  }) async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        return;
      }

      // ----------------------------------------------------------
      // USER MUST BELONG TO CONVERSATION
      // ----------------------------------------------------------

      if (user.uid != instructorId &&
          user.uid != studentId) {
        throw ChatServiceException(
          'You are not part of this conversation.',
        );
      }

      final String conversationId =
          buildConversationId(
        courseId:
            courseId,
        instructorId:
            instructorId,
        studentId:
            studentId,
      );

      if (conversationId.isEmpty) {
        return;
      }

      final QuerySnapshot<Map<String, dynamic>>
          snapshot =
          await _firestore
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .where(
                'receiverId',
                isEqualTo:
                    user.uid,
              )
              .get();

      final List<
              QueryDocumentSnapshot<
                  Map<String, dynamic>>>
          unreadMessages =
          snapshot.docs.where(
        (
          document,
        ) {
          return document
                  .data()['isRead'] !=
              true;
        },
      ).toList();

      if (unreadMessages.isEmpty) {
        return;
      }

      // ----------------------------------------------------------
      // FIRESTORE MAX BATCH = 500
      // Keep safe margin using 400.
      // ----------------------------------------------------------

      const int chunkSize =
          400;

      for (
        int start = 0;
        start <
            unreadMessages.length;
        start += chunkSize
      ) {
        final int end =
            start + chunkSize >
                    unreadMessages.length
                ? unreadMessages.length
                : start +
                    chunkSize;

        final WriteBatch batch =
            _firestore.batch();

        for (
          int index = start;
          index < end;
          index++
        ) {
          batch.update(
            unreadMessages[index]
                .reference,
            {
              'isRead':
                  true,
            },
          );
        }

        await batch.commit();
      }
    } on ChatServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ??
            'Unable to update message status.',
      );
    } catch (_) {
      throw ChatServiceException(
        'Unable to update message status.',
      );
    }
  }

  // ============================================================
  // WATCH MY CONVERSATIONS
  //
  // Works for both instructor and student.
  // ============================================================

  Stream<List<Map<String, dynamic>>>
      watchMyConversations() {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return Stream.value(
        <Map<String, dynamic>>[],
      );
    }

    return _firestore
        .collection('conversations')
        .where(
          'participantIds',
          arrayContains:
              user.uid,
        )
        .snapshots()
        .map(
      (
        snapshot,
      ) {
        final List<Map<String, dynamic>>
            conversations =
            snapshot.docs
                .map(
          (
            document,
          ) {
            return {
              ...document.data(),
              'id': document.id,
            };
          },
        ).toList();

        // --------------------------------------------------------
        // LATEST CONVERSATION FIRST
        // --------------------------------------------------------

        conversations.sort(
          (
            a,
            b,
          ) {
            final dynamic aTime =
                a['lastMessageAt'];

            final dynamic bTime =
                b['lastMessageAt'];

            if (aTime is Timestamp &&
                bTime is Timestamp) {
              return bTime
                  .toDate()
                  .compareTo(
                    aTime.toDate(),
                  );
            }

            if (aTime is Timestamp) {
              return -1;
            }

            if (bTime is Timestamp) {
              return 1;
            }

            return 0;
          },
        );

        return conversations;
      },
    );
  }

  // ============================================================
  // WATCH UNREAD COUNT FOR ONE CONVERSATION
  //
  // Used by InstructorMessagesScreen.
  // ============================================================

  Stream<int> watchConversationUnreadCount({
    required String courseId,
    required String instructorId,
    required String studentId,
  }) {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return Stream.value(
        0,
      );
    }

    // ----------------------------------------------------------
    // ONLY PARTICIPANTS SHOULD READ THIS COUNT
    // ----------------------------------------------------------

    if (user.uid != instructorId &&
        user.uid != studentId) {
      return Stream.value(
        0,
      );
    }

    final String conversationId =
        buildConversationId(
      courseId:
          courseId,
      instructorId:
          instructorId,
      studentId:
          studentId,
    );

    if (conversationId.isEmpty) {
      return Stream.value(
        0,
      );
    }

    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where(
          'receiverId',
          isEqualTo:
              user.uid,
        )
        .snapshots()
        .map(
      (
        snapshot,
      ) {
        int count =
            0;

        for (final document
            in snapshot.docs) {
          if (document
                  .data()['isRead'] !=
              true) {
            count++;
          }
        }

        return count;
      },
    );
  }

  // ============================================================
  // GLOBAL UNREAD MESSAGE COUNT
  //
  // Used by:
  // Student dashboard badge
  // Instructor dashboard badge
  // ============================================================

  Stream<int> watchUnreadMessageCount() {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return Stream.value(
        0,
      );
    }

    return _firestore
        .collectionGroup(
          'messages',
        )
        .where(
          'receiverId',
          isEqualTo:
              user.uid,
        )
        .snapshots()
        .map(
      (
        snapshot,
      ) {
        int unreadCount =
            0;

        for (final document
            in snapshot.docs) {
          if (document
                  .data()['isRead'] !=
              true) {
            unreadCount++;
          }
        }

        return unreadCount;
      },
    );
  }
}

// ============================================================
// CHAT SERVICE EXCEPTION
// ============================================================

class ChatServiceException implements Exception {
  final String message;

  ChatServiceException(
    this.message,
  );

  @override
  String toString() =>
      message;
}