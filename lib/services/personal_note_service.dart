import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PersonalStudentNote {
  const PersonalStudentNote({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PersonalStudentNote.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    DateTime? date(dynamic value) => value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : null;
    return PersonalStudentNote(
      id: document.id,
      ownerId: (data['ownerId'] ?? '').toString(),
      title: (data['title'] ?? 'Untitled note').toString(),
      content: (data['content'] ?? '').toString(),
      createdAt: date(data['createdAt']),
      updatedAt: date(data['updatedAt']),
    );
  }
}

class PersonalNoteException implements Exception {
  const PersonalNoteException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PersonalNoteService {
  PersonalNoteService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _notesFor(String uid) =>
      _firestore.collection('users').doc(uid).collection('personalNotes');

  User _student() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PersonalNoteException('Please sign in again.');
    }
    return user;
  }

  Stream<List<PersonalStudentNote>> watchMyNotes() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(const PersonalNoteException('Please sign in again.'));
    }
    return _notesFor(user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(PersonalStudentNote.fromDocument)
              .where((note) => note.ownerId == user.uid)
              .toList(),
        );
  }

  Future<String> createNote({
    required String title,
    required String content,
  }) async {
    final user = _student();
    final values = _validated(title: title, content: content);
    try {
      final reference = await _notesFor(user.uid).add({
        'ownerId': user.uid,
        ...values,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return reference.id;
    } on FirebaseException catch (error) {
      throw PersonalNoteException(
        error.code == 'permission-denied'
            ? 'Your account cannot save personal notes.'
            : 'Unable to save the note. Check your connection.',
      );
    }
  }

  Future<void> updateNote({
    required String noteId,
    required String title,
    required String content,
  }) async {
    final user = _student();
    final values = _validated(title: title, content: content);
    if (noteId.trim().isEmpty || noteId.contains('/')) {
      throw const PersonalNoteException('The selected note is invalid.');
    }
    try {
      await _notesFor(user.uid)
          .doc(noteId)
          .update({...values, 'updatedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (error) {
      throw PersonalNoteException(
        error.code == 'not-found'
            ? 'This note no longer exists.'
            : error.code == 'permission-denied'
            ? 'You can only edit your own notes.'
            : 'Unable to update the note. Check your connection.',
      );
    }
  }

  Future<void> deleteNote(String noteId) async {
    final user = _student();
    if (noteId.trim().isEmpty || noteId.contains('/')) {
      throw const PersonalNoteException('The selected note is invalid.');
    }
    try {
      await _notesFor(user.uid).doc(noteId).delete();
    } on FirebaseException catch (error) {
      throw PersonalNoteException(
        error.code == 'permission-denied'
            ? 'You can only delete your own notes.'
            : 'Unable to delete the note. Check your connection.',
      );
    }
  }

  Map<String, String> _validated({
    required String title,
    required String content,
  }) {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 150) {
      throw const PersonalNoteException(
        'Enter a note title of up to 150 characters.',
      );
    }
    if (cleanContent.isEmpty || cleanContent.length > 10000) {
      throw const PersonalNoteException(
        'Enter note content of up to 10,000 characters.',
      );
    }
    return {'title': cleanTitle, 'content': cleanContent};
  }
}
