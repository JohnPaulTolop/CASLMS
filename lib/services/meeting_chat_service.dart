import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeetingChatMessage {
  const MeetingChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime? createdAt;

  bool isMine(String uid) => senderId == uid;

  factory MeetingChatMessage.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['createdAt'];
    return MeetingChatMessage(
      id: document.id,
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? 'Participant').toString(),
      senderRole: (data['senderRole'] ?? 'student').toString(),
      text: (data['text'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class MeetingChatException implements Exception {
  const MeetingChatException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MeetingChatService {
  MeetingChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  Future<Map<String, String>>? _identity;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Stream<List<MeetingChatMessage>> watchMessages({
    required String courseId,
    required String sectionId,
    required String sessionId,
  }) {
    if (courseId.isEmpty || sectionId.isEmpty || sessionId.isEmpty) {
      return Stream.error(
        const MeetingChatException('Meeting information is incomplete.'),
      );
    }

    return _firestore
        .collection('meetingMessages')
        .where('courseId', isEqualTo: courseId)
        .where('sectionId', isEqualTo: sectionId)
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('createdAt')
        .limit(500)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(MeetingChatMessage.fromDocument).toList(),
        );
  }

  Future<void> sendMessage({
    required String courseId,
    required String sectionId,
    required String sessionId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    final clean = text.trim();
    if (user == null) {
      throw const MeetingChatException('Please sign in again.');
    }
    if (clean.isEmpty) {
      throw const MeetingChatException('Enter a message first.');
    }
    if (clean.length > 2000) {
      throw const MeetingChatException(
        'Meeting messages must be 2,000 characters or fewer.',
      );
    }
    if (courseId.isEmpty || sectionId.isEmpty || sessionId.isEmpty) {
      throw const MeetingChatException('Meeting information is incomplete.');
    }

    try {
      final identity = await (_identity ??= _loadIdentity(user.uid));
      if (_auth.currentUser?.uid != user.uid) {
        throw const MeetingChatException(
          'Your session changed. Rejoin the meeting.',
        );
      }
      final nonce = DateTime.now().microsecondsSinceEpoch.toString();
      final documentId = '${user.uid}_$nonce';
      await _firestore.collection('meetingMessages').doc(documentId).set({
        'courseId': courseId,
        'sectionId': sectionId,
        'sessionId': sessionId,
        'senderId': user.uid,
        'senderName': identity['name'],
        'senderRole': identity['role'],
        'text': clean,
        'clientNonce': nonce,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on MeetingChatException {
      rethrow;
    } on FirebaseException catch (error) {
      throw MeetingChatException(
        error.code == 'permission-denied'
            ? 'You no longer have access to this meeting chat.'
            : 'Unable to send the message. Check your connection.',
      );
    }
  }

  Future<Map<String, String>> _loadIdentity(String uid) async {
    final profile = (await _firestore.collection('users').doc(uid).get())
        .data();
    final role = (profile?['role'] ?? '').toString();
    final name = (profile?['name'] ?? _auth.currentUser?.displayName ?? '')
        .toString()
        .trim();
    if (!['student', 'instructor'].contains(role)) {
      throw const MeetingChatException(
        'Only meeting participants can use meeting chat.',
      );
    }
    return {
      'name': name.isEmpty
          ? role == 'instructor'
                ? 'Instructor'
                : 'Student'
          : name,
      'role': role,
    };
  }
}
