import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../config/supabase_config.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final sb.SupabaseClient _supabase = sb.Supabase.instance.client;

  static const int maximumAttachmentBytes = 15 * 1024 * 1024;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // DIRECT CONVERSATION ID
  //
  // A conversation belongs to exactly one instructor/student pair. The
  // optional courseId remains in the signature for compatibility with older
  // screens, but it never participates in the document identity.
  // ============================================================

  String buildConversationId({
    String? courseId,
    required String instructorId,
    required String studentId,
  }) {
    final String cleanInstructorId = instructorId.trim();

    final String cleanStudentId = studentId.trim();

    if (cleanInstructorId.isEmpty || cleanStudentId.isEmpty) {
      return '';
    }

    return 'direct_${cleanInstructorId}_$cleanStudentId';
  }

  // ============================================================
  // CURRENT USER PROFILE
  // ============================================================

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      return {...document.data()!, 'id': document.id};
    } on FirebaseException catch (e) {
      throw ChatServiceException(e.message ?? 'Unable to load user profile.');
    } catch (_) {
      throw ChatServiceException('Unable to load user profile.');
    }
  }

  // ============================================================
  // GET USER BY ID
  // ============================================================

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final String cleanUserId = userId.trim();

      if (cleanUserId.isEmpty) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('users')
          .doc(cleanUserId)
          .get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      return {...document.data()!, 'id': document.id};
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ?? 'Unable to load user information.',
      );
    } catch (_) {
      throw ChatServiceException('Unable to load user information.');
    }
  }

  // ============================================================
  // GET COURSE BY ID
  // ============================================================

  Future<Map<String, dynamic>?> getCourseById(String courseId) async {
    try {
      final String cleanCourseId = courseId.trim();

      if (cleanCourseId.isEmpty) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('courses')
          .doc(cleanCourseId)
          .get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      return {...document.data()!, 'id': document.id};
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ?? 'Unable to load course information.',
      );
    } catch (_) {
      throw ChatServiceException('Unable to load course information.');
    }
  }

  // ============================================================
  // GET STUDENT CHAT CONTACTS
  //
  // Active enrollments are grouped by instructor. A student sees one contact
  // per instructor even when they share several courses.
  // ============================================================

  Future<List<Map<String, dynamic>>> getStudentChatContacts() async {
    try {
      final User? studentUser = _auth.currentUser;

      if (studentUser == null) {
        throw ChatServiceException('No student is currently logged in.');
      }

      // ----------------------------------------------------------
      // STUDENT PROFILE
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> studentDocument =
          await _firestore.collection('users').doc(studentUser.uid).get();

      final Map<String, dynamic>? studentData = studentDocument.data();

      final String studentName = (studentData?['name'] ?? 'Student').toString();

      // ----------------------------------------------------------
      // STUDENT ENROLLMENTS
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where('studentId', isEqualTo: studentUser.uid)
              .get();

      final List<Map<String, dynamic>> contacts = [];

      final Map<String, int> contactIndexByInstructor = <String, int>{};

      for (final enrollmentDocument in enrollmentSnapshot.docs) {
        final Map<String, dynamic> enrollment = enrollmentDocument.data();

        // --------------------------------------------------------
        // ACTIVE ENROLLMENTS ONLY
        // --------------------------------------------------------

        final String enrollmentStatus = (enrollment['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (enrollmentStatus != 'active') {
          continue;
        }

        final String courseId = (enrollment['courseId'] ?? '')
            .toString()
            .trim();

        if (courseId.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // COURSE
        // --------------------------------------------------------

        final DocumentSnapshot<Map<String, dynamic>> courseDocument =
            await _firestore.collection('courses').doc(courseId).get();

        if (!courseDocument.exists || courseDocument.data() == null) {
          continue;
        }

        final Map<String, dynamic> course = courseDocument.data()!;

        final String courseStatus = (course['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (courseStatus != 'active') {
          continue;
        }

        final String instructorId = (course['instructorId'] ?? '')
            .toString()
            .trim();

        if (instructorId.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // MERGE COURSES THAT SHARE THE SAME INSTRUCTOR
        // --------------------------------------------------------

        final int? existingContactIndex =
            contactIndexByInstructor[instructorId];

        if (existingContactIndex != null) {
          final Map<String, dynamic> existingContact =
              contacts[existingContactIndex];

          final List<String> courseIds = List<String>.from(
            existingContact['courseIds'] as List<dynamic>? ?? const <dynamic>[],
          );
          final List<String> courseCodes = List<String>.from(
            existingContact['courseCodes'] as List<dynamic>? ??
                const <dynamic>[],
          );
          final List<String> courseTitles = List<String>.from(
            existingContact['courseTitles'] as List<dynamic>? ??
                const <dynamic>[],
          );

          if (!courseIds.contains(courseId)) {
            courseIds.add(courseId);
          }

          final String courseCode = (course['code'] ?? '').toString().trim();
          final String courseTitle = (course['title'] ?? '').toString().trim();

          if (courseCode.isNotEmpty && !courseCodes.contains(courseCode)) {
            courseCodes.add(courseCode);
          }
          if (courseTitle.isNotEmpty && !courseTitles.contains(courseTitle)) {
            courseTitles.add(courseTitle);
          }

          existingContact
            ..['courseIds'] = courseIds
            ..['courseCodes'] = courseCodes
            ..['courseTitles'] = courseTitles
            ..['courseCode'] = courseCodes.join(', ')
            ..['courseTitle'] = courseTitles.join(', ');

          continue;
        }

        // --------------------------------------------------------
        // INSTRUCTOR
        // --------------------------------------------------------

        final DocumentSnapshot<Map<String, dynamic>> instructorDocument =
            await _firestore.collection('users').doc(instructorId).get();

        if (!instructorDocument.exists || instructorDocument.data() == null) {
          continue;
        }

        final Map<String, dynamic> instructor = instructorDocument.data()!;

        final String instructorRole = (instructor['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (instructorRole != 'instructor') {
          continue;
        }

        final String instructorStatus = (instructor['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

        if (instructorStatus != 'active') {
          continue;
        }

        contactIndexByInstructor[instructorId] = contacts.length;

        final String courseCode = (course['code'] ?? '').toString().trim();
        final String courseTitle = (course['title'] ?? 'Course')
            .toString()
            .trim();

        contacts.add({
          // ------------------------------------------------------
          // COURSE
          // ------------------------------------------------------

          'courseId': courseId,

          'courseCode': courseCode,

          'courseTitle': courseTitle,

          'courseIds': <String>[courseId],

          'courseCodes': courseCode.isEmpty ? <String>[] : <String>[courseCode],

          'courseTitles': courseTitle.isEmpty
              ? <String>[]
              : <String>[courseTitle],

          // ------------------------------------------------------
          // STUDENT
          // ------------------------------------------------------
          'studentId': studentUser.uid,

          'studentName': studentName,

          // ------------------------------------------------------
          // INSTRUCTOR
          // ------------------------------------------------------
          'instructorId': instructorId,

          'instructorName':
              (instructor['name'] ?? course['instructorName'] ?? 'Instructor')
                  .toString(),

          'instructorEmail': (instructor['email'] ?? '').toString(),

          'profileImageUrl': (instructor['profileImageUrl'] ?? '').toString(),
        });
      }

      // ----------------------------------------------------------
      // SORT CONTACTS
      // ----------------------------------------------------------

      contacts.sort((a, b) {
        final String instructorA = (a['instructorName'] ?? '')
            .toString()
            .toLowerCase();

        final String instructorB = (b['instructorName'] ?? '')
            .toString()
            .toLowerCase();

        return instructorA.compareTo(instructorB);
      });

      return contacts;
    } on ChatServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChatServiceException(e.message ?? 'Unable to load instructors.');
    } catch (_) {
      throw ChatServiceException('Unable to load instructors.');
    }
  }

  // ============================================================
  // DIRECT CONVERSATION LOOKUP
  // ============================================================

  Query<Map<String, dynamic>> _conversationQueryForPair({
    required String instructorId,
    required String studentId,
  }) {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw ChatServiceException('You must be logged in to open a chat.');
    }

    if (user.uid != instructorId && user.uid != studentId) {
      throw ChatServiceException('You are not part of this conversation.');
    }

    return _firestore
        .collection('conversations')
        .where('instructorId', isEqualTo: instructorId)
        .where('studentId', isEqualTo: studentId);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getPairConversationDocuments({
    required String instructorId,
    required String studentId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _conversationQueryForPair(
          instructorId: instructorId,
          studentId: studentId,
        ).get();

    return snapshot.docs.where((document) {
      final Map<String, dynamic> data = document.data();
      return (data['instructorId'] ?? '').toString() == instructorId &&
          (data['studentId'] ?? '').toString() == studentId;
    }).toList();
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _selectPrimaryConversation(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
    required String canonicalId,
  }) {
    if (documents.isEmpty) {
      return null;
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(documents);

    sorted.sort((a, b) {
      if (a.id == canonicalId && b.id != canonicalId) {
        return -1;
      }
      if (b.id == canonicalId && a.id != canonicalId) {
        return 1;
      }

      final dynamic aCreatedAt = a.data()['createdAt'];
      final dynamic bCreatedAt = b.data()['createdAt'];

      if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
        final int timeComparison = aCreatedAt.compareTo(bCreatedAt);
        if (timeComparison != 0) {
          return timeComparison;
        }
      } else if (aCreatedAt is Timestamp) {
        return -1;
      } else if (bCreatedAt is Timestamp) {
        return 1;
      }

      return a.id.compareTo(b.id);
    });

    return sorted.first;
  }

  // ============================================================
  // ENSURE ONE CONVERSATION EXISTS FOR THE USER PAIR
  //
  // Legacy course-based documents are recognized and reused. If several
  // legacy documents already exist, a deterministic primary is selected and
  // all new messages are written only to it.
  // ============================================================

  Future<String> ensureConversation({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
  }) async {
    try {
      final String cleanCourseId = courseId.trim();

      final String cleanStudentId = studentId.trim();

      final String cleanInstructorId = instructorId.trim();

      if (cleanCourseId.isEmpty) {
        throw ChatServiceException('Course ID is missing.');
      }

      if (cleanStudentId.isEmpty) {
        throw ChatServiceException('Student ID is missing.');
      }

      if (cleanInstructorId.isEmpty) {
        throw ChatServiceException('Instructor ID is missing.');
      }

      final String canonicalId = buildConversationId(
        instructorId: cleanInstructorId,
        studentId: cleanStudentId,
      );

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> pairDocuments =
          await _getPairConversationDocuments(
            instructorId: cleanInstructorId,
            studentId: cleanStudentId,
          );

      final QueryDocumentSnapshot<Map<String, dynamic>>? primaryDocument =
          _selectPrimaryConversation(pairDocuments, canonicalId: canonicalId);

      final DocumentReference<Map<String, dynamic>> conversationReference =
          primaryDocument?.reference ??
          _firestore.collection('conversations').doc(canonicalId);

      // ----------------------------------------------------------
      // NEW CONVERSATION
      // ----------------------------------------------------------

      if (primaryDocument == null) {
        await conversationReference.set({
          'courseId': cleanCourseId,

          'courseIds': <String>[cleanCourseId],

          'conversationType': 'direct',

          'participantIds': [cleanInstructorId, cleanStudentId],

          'instructorId': cleanInstructorId,

          'instructorName': instructorName.trim().isEmpty
              ? 'Instructor'
              : instructorName.trim(),

          'studentId': cleanStudentId,

          'studentName': studentName.trim().isEmpty
              ? 'Student'
              : studentName.trim(),

          'lastMessage': '',

          'lastMessageAt': null,

          'createdAt': FieldValue.serverTimestamp(),

          'updatedAt': FieldValue.serverTimestamp(),
        });

        return conversationReference.id;
      }

      // ----------------------------------------------------------
      // EXISTING CONVERSATION
      //
      // Update names/participant info without overwriting
      // lastMessage, lastMessageAt, createdAt, etc.
      // ----------------------------------------------------------

      await conversationReference.set({
        'participantIds': [cleanInstructorId, cleanStudentId],

        'courseIds': FieldValue.arrayUnion(<String>[cleanCourseId]),

        'conversationType': 'direct',

        'instructorId': cleanInstructorId,

        'instructorName': instructorName.trim().isEmpty
            ? 'Instructor'
            : instructorName.trim(),

        'studentId': cleanStudentId,

        'studentName': studentName.trim().isEmpty
            ? 'Student'
            : studentName.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return conversationReference.id;
    } on ChatServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChatServiceException(e.message ?? 'Unable to open conversation.');
    } catch (_) {
      throw ChatServiceException('Unable to open conversation.');
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
      final User? user = _auth.currentUser;

      if (user == null) {
        throw ChatServiceException('You must be logged in to send a message.');
      }

      final String cleanCourseId = courseId.trim();

      final String cleanStudentId = studentId.trim();

      final String cleanInstructorId = instructorId.trim();

      final String cleanReceiverId = receiverId.trim();

      final String cleanText = text.trim();

      if (cleanText.isEmpty) {
        return;
      }

      if (cleanCourseId.isEmpty ||
          cleanStudentId.isEmpty ||
          cleanInstructorId.isEmpty) {
        throw ChatServiceException('Conversation information is incomplete.');
      }

      // ----------------------------------------------------------
      // CURRENT USER MUST BE A PARTICIPANT
      // ----------------------------------------------------------

      if (user.uid != cleanStudentId && user.uid != cleanInstructorId) {
        throw ChatServiceException('You are not part of this conversation.');
      }

      // ----------------------------------------------------------
      // DETERMINE CORRECT RECEIVER
      // ----------------------------------------------------------

      final String expectedReceiverId = user.uid == cleanInstructorId
          ? cleanStudentId
          : cleanInstructorId;

      if (cleanReceiverId != expectedReceiverId) {
        throw ChatServiceException('Invalid message receiver.');
      }

      // ----------------------------------------------------------
      // ENSURE CONVERSATION
      // ----------------------------------------------------------

      final String conversationId = await ensureConversation(
        courseId: cleanCourseId,
        studentId: cleanStudentId,
        studentName: studentName,
        instructorId: cleanInstructorId,
        instructorName: instructorName,
      );

      final DocumentReference<Map<String, dynamic>> conversationReference =
          _firestore.collection('conversations').doc(conversationId);

      final DocumentReference<Map<String, dynamic>> messageReference =
          conversationReference.collection('messages').doc();

      // ----------------------------------------------------------
      // ATOMIC MESSAGE + CONVERSATION UPDATE
      // ----------------------------------------------------------

      final WriteBatch batch = _firestore.batch();

      batch.set(messageReference, {
        'senderId': user.uid,

        'receiverId': cleanReceiverId,

        'text': cleanText,

        'sentAt': FieldValue.serverTimestamp(),

        'isRead': false,
      });

      batch.update(conversationReference, {
        'lastMessage': cleanText,

        'lastMessageAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on ChatServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChatServiceException(e.message ?? 'Unable to send message.');
    } catch (_) {
      throw ChatServiceException('Unable to send message.');
    }
  }

  // ============================================================
  // SEND ATTACHMENT
  // ============================================================

  Future<void> sendAttachment({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
    required String receiverId,
    required String fileName,
    required Uint8List fileBytes,
    String caption = '',
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw ChatServiceException(
        'You must be logged in to send an attachment.',
      );
    }

    final String cleanCourseId = courseId.trim();
    final String cleanStudentId = studentId.trim();
    final String cleanInstructorId = instructorId.trim();
    final String cleanReceiverId = receiverId.trim();
    final String cleanFileName = fileName.trim();
    final String cleanCaption = caption.trim();

    if (cleanCourseId.isEmpty ||
        cleanStudentId.isEmpty ||
        cleanInstructorId.isEmpty) {
      throw ChatServiceException('Conversation information is incomplete.');
    }
    if (user.uid != cleanStudentId && user.uid != cleanInstructorId) {
      throw ChatServiceException('You are not part of this conversation.');
    }

    final String expectedReceiverId = user.uid == cleanInstructorId
        ? cleanStudentId
        : cleanInstructorId;

    if (cleanReceiverId != expectedReceiverId) {
      throw ChatServiceException('Invalid message receiver.');
    }
    if (cleanFileName.isEmpty || fileBytes.isEmpty) {
      throw ChatServiceException('The selected attachment is empty.');
    }
    if (fileBytes.length > maximumAttachmentBytes) {
      throw ChatServiceException('Chat attachments must be 15 MB or smaller.');
    }

    final String extension = _extensionFromFileName(cleanFileName);
    const Set<String> allowedExtensions = {
      'pdf',
      'doc',
      'docx',
      'ppt',
      'pptx',
      'xls',
      'xlsx',
      'txt',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
    };

    if (!allowedExtensions.contains(extension)) {
      throw ChatServiceException(
        'Choose a PDF, document, presentation, spreadsheet, text file, or image.',
      );
    }

    final String conversationId = await ensureConversation(
      courseId: cleanCourseId,
      studentId: cleanStudentId,
      studentName: studentName,
      instructorId: cleanInstructorId,
      instructorName: instructorName,
    );

    final DocumentReference<Map<String, dynamic>> conversationReference =
        _firestore.collection('conversations').doc(conversationId);
    final DocumentReference<Map<String, dynamic>> messageReference =
        conversationReference.collection('messages').doc();

    final DocumentSnapshot<Map<String, dynamic>> conversationSnapshot =
        await conversationReference.get();
    final String storageCourseId =
        (conversationSnapshot.data()?['courseId'] ?? cleanCourseId)
            .toString()
            .trim();

    final String safeName = _safeFileName(cleanFileName);
    final String storagePath =
        'courses/$storageCourseId/chats/$conversationId/${messageReference.id}/$safeName';
    final String mimeType = _mimeTypeForExtension(extension);
    final String attachmentKind = _isImageExtension(extension)
        ? 'image'
        : 'file';
    final bucket = _supabase.storage.from(
      SupabaseConfig.learningMaterialsBucket,
    );

    bool uploaded = false;

    try {
      await bucket.uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: sb.FileOptions(
          contentType: mimeType,
          cacheControl: '3600',
          upsert: false,
        ),
      );
      uploaded = true;

      final String attachmentUrl = bucket.getPublicUrl(storagePath);
      final String preview = attachmentKind == 'image'
          ? 'Photo: $cleanFileName'
          : 'File: $cleanFileName';
      final WriteBatch batch = _firestore.batch();

      batch.set(messageReference, {
        'senderId': user.uid,
        'receiverId': cleanReceiverId,
        'text': cleanCaption,
        'messageType': 'attachment',
        'attachmentKind': attachmentKind,
        'attachmentName': cleanFileName,
        'attachmentUrl': attachmentUrl,
        'attachmentPath': storagePath,
        'attachmentMimeType': mimeType,
        'attachmentSizeBytes': fileBytes.length,
        'storageProvider': 'supabase',
        'storageBucket': SupabaseConfig.learningMaterialsBucket,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      batch.update(conversationReference, {
        'lastMessage': cleanCaption.isEmpty
            ? preview
            : '$preview — $cleanCaption',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on sb.StorageException catch (error) {
      throw ChatServiceException(
        error.message.isEmpty
            ? 'Unable to upload the attachment.'
            : error.message,
      );
    } on FirebaseException catch (error) {
      if (uploaded) {
        try {
          await bucket.remove([storagePath]);
        } catch (_) {}
      }
      throw ChatServiceException(
        error.message ??
            'The file uploaded, but the message could not be sent.',
      );
    } catch (error) {
      if (uploaded) {
        try {
          await bucket.remove([storagePath]);
        } catch (_) {}
      }
      if (error is ChatServiceException) rethrow;
      throw ChatServiceException('Unable to send the attachment.');
    }
  }

  String _extensionFromFileName(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _safeFileName(String fileName) {
    final String normalized = fileName
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return normalized.isEmpty ? 'attachment' : normalized;
  }

  bool _isImageExtension(String extension) {
    return const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(extension);
  }

  String _mimeTypeForExtension(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
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
    if (courseId.trim().isEmpty ||
        instructorId.trim().isEmpty ||
        studentId.trim().isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    final Query<Map<String, dynamic>> conversationQuery;

    try {
      conversationQuery = _conversationQueryForPair(
        instructorId: instructorId,
        studentId: studentId,
      );
    } on ChatServiceException catch (error) {
      return Stream.error(error);
    }

    late final StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    conversationSubscription;
    final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
    messageSubscriptions =
        <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final Map<String, List<Map<String, dynamic>>> messagesByConversation =
        <String, List<Map<String, dynamic>>>{};

    void emitMessages() {
      if (controller.isClosed) {
        return;
      }

      final List<Map<String, dynamic>> messages = messagesByConversation.values
          .expand((items) => items)
          .toList();

      messages.sort((a, b) {
        final dynamic aSentAt = a['sentAt'];
        final dynamic bSentAt = b['sentAt'];

        if (aSentAt is Timestamp && bSentAt is Timestamp) {
          final int timeComparison = aSentAt.compareTo(bSentAt);
          if (timeComparison != 0) {
            return timeComparison;
          }
        } else if (aSentAt is Timestamp) {
          return -1;
        } else if (bSentAt is Timestamp) {
          return 1;
        }

        final String aKey = '${a['conversationId'] ?? ''}_${a['id'] ?? ''}';
        final String bKey = '${b['conversationId'] ?? ''}_${b['id'] ?? ''}';
        return aKey.compareTo(bKey);
      });

      controller.add(messages);
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        conversationSubscription = conversationQuery.snapshots().listen((
          conversationSnapshot,
        ) {
          final List<QueryDocumentSnapshot<Map<String, dynamic>>>
          pairDocuments = conversationSnapshot.docs.where((document) {
            final Map<String, dynamic> data = document.data();
            return (data['instructorId'] ?? '').toString() == instructorId &&
                (data['studentId'] ?? '').toString() == studentId;
          }).toList();

          final Set<String> activeIds = pairDocuments
              .map((document) => document.id)
              .toSet();

          final List<String> removedIds = messageSubscriptions.keys
              .where((id) => !activeIds.contains(id))
              .toList();

          for (final String removedId in removedIds) {
            messageSubscriptions.remove(removedId)?.cancel();
            messagesByConversation.remove(removedId);
          }

          for (final document in pairDocuments) {
            if (messageSubscriptions.containsKey(document.id)) {
              continue;
            }

            messageSubscriptions[document.id] = document.reference
                .collection('messages')
                .orderBy('sentAt', descending: false)
                .snapshots()
                .listen((messageSnapshot) {
                  messagesByConversation[document.id] = messageSnapshot.docs
                      .map(
                        (messageDocument) => <String, dynamic>{
                          ...messageDocument.data(),
                          'id': messageDocument.id,
                          'conversationId': document.id,
                        },
                      )
                      .toList();
                  emitMessages();
                }, onError: controller.addError);
          }

          emitMessages();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await conversationSubscription?.cancel();
        for (final subscription in messageSubscriptions.values) {
          await subscription.cancel();
        }
        messageSubscriptions.clear();
        messagesByConversation.clear();
      },
    );

    return controller.stream;
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
      final User? user = _auth.currentUser;

      if (user == null) {
        return;
      }

      // ----------------------------------------------------------
      // USER MUST BELONG TO CONVERSATION
      // ----------------------------------------------------------

      if (user.uid != instructorId && user.uid != studentId) {
        throw ChatServiceException('You are not part of this conversation.');
      }

      if (courseId.trim().isEmpty ||
          instructorId.trim().isEmpty ||
          studentId.trim().isEmpty) {
        return;
      }

      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
      conversationDocuments = await _getPairConversationDocuments(
        instructorId: instructorId,
        studentId: studentId,
      );

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> unreadMessages =
          <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final conversationDocument in conversationDocuments) {
        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await conversationDocument.reference
                .collection('messages')
                .where('receiverId', isEqualTo: user.uid)
                .get();

        unreadMessages.addAll(
          snapshot.docs.where((document) {
            return document.data()['isRead'] != true;
          }),
        );
      }

      if (unreadMessages.isEmpty) {
        return;
      }

      // ----------------------------------------------------------
      // FIRESTORE MAX BATCH = 500
      // Keep safe margin using 400.
      // ----------------------------------------------------------

      const int chunkSize = 400;

      for (int start = 0; start < unreadMessages.length; start += chunkSize) {
        final int end = start + chunkSize > unreadMessages.length
            ? unreadMessages.length
            : start + chunkSize;

        final WriteBatch batch = _firestore.batch();

        for (int index = start; index < end; index++) {
          batch.update(unreadMessages[index].reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }
    } on ChatServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ChatServiceException(
        e.message ?? 'Unable to update message status.',
      );
    } catch (_) {
      throw ChatServiceException('Unable to update message status.');
    }
  }

  // ============================================================
  // WATCH MY CONVERSATIONS
  //
  // Works for both instructor and student.
  // ============================================================

  Stream<List<Map<String, dynamic>>> watchMyConversations() {
    return _watchMyConversations();
  }

  /// Watches only conversations where the signed-in user is the student.
  ///
  /// Using the explicit participant field keeps this query aligned with the
  /// Firestore list rule. It is more reliable than asking Firestore to prove
  /// access through membership of the `participantIds` array.
  Stream<List<Map<String, dynamic>>> watchStudentConversations() {
    return _watchMyConversations(participantField: 'studentId');
  }

  /// Watches only conversations where the signed-in user is the instructor.
  Stream<List<Map<String, dynamic>>> watchInstructorConversations() {
    return _watchMyConversations(participantField: 'instructorId');
  }

  Stream<List<Map<String, dynamic>>> _watchMyConversations({
    String? participantField,
  }) {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    Query<Map<String, dynamic>> query = _firestore.collection('conversations');

    if (participantField == null) {
      query = query.where('participantIds', arrayContains: user.uid);
    } else {
      query = query.where(participantField, isEqualTo: user.uid);
    }

    return query.snapshots().map((snapshot) {
      final List<Map<String, dynamic>> conversations = snapshot.docs.map((
        document,
      ) {
        return {...document.data(), 'id': document.id};
      }).toList();

      // --------------------------------------------------------
      // LATEST CONVERSATION FIRST
      // --------------------------------------------------------

      conversations.sort((a, b) {
        final dynamic aTime = a['lastMessageAt'];

        final dynamic bTime = b['lastMessageAt'];

        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.toDate().compareTo(aTime.toDate());
        }

        if (aTime is Timestamp) {
          return -1;
        }

        if (bTime is Timestamp) {
          return 1;
        }

        return 0;
      });

      return conversations;
    });
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
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream.value(0);
    }

    // ----------------------------------------------------------
    // ONLY PARTICIPANTS SHOULD READ THIS COUNT
    // ----------------------------------------------------------

    if (user.uid != instructorId && user.uid != studentId) {
      return Stream.value(0);
    }

    return watchMessages(
      courseId: courseId,
      instructorId: instructorId,
      studentId: studentId,
    ).map((messages) {
      int count = 0;

      for (final message in messages) {
        if ((message['receiverId'] ?? '').toString() == user.uid &&
            message['isRead'] != true) {
          count++;
        }
      }

      return count;
    });
  }

  // ============================================================
  // GLOBAL UNREAD MESSAGE COUNT
  //
  // Used by:
  // Student dashboard badge
  // Instructor dashboard badge
  // ============================================================

  Stream<int> watchUnreadMessageCount() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          int unreadCount = 0;

          for (final document in snapshot.docs) {
            if (document.data()['isRead'] != true) {
              unreadCount++;
            }
          }

          return unreadCount;
        });
  }
}

// ============================================================
// CHAT SERVICE EXCEPTION
// ============================================================

class ChatServiceException implements Exception {
  final String message;

  ChatServiceException(this.message);

  @override
  String toString() => message;
}
