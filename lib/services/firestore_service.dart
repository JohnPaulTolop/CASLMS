import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> testConnection() async {
    await _firestore.collection('system_test').doc('connection_test').set({
      'message': 'CASLMS connected successfully',
      'status': 'connected',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}