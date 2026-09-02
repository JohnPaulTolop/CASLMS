import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class ProfilePictureResult {
  const ProfilePictureResult({
    required this.photoUrl,
    required this.photoPath,
  });

  final String photoUrl;
  final String photoPath;
}

class ProfilePictureServiceException implements Exception {
  const ProfilePictureServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfilePictureService {
  ProfilePictureService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    sb.SupabaseClient? supabaseClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _supabase = supabaseClient ?? sb.Supabase.instance.client;

  static const String bucketName = 'caslms-profile-pictures';
  static const int maximumBytes = 5 * 1024 * 1024;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final sb.SupabaseClient _supabase;

  Future<ProfilePictureResult?> pickAndUploadProfilePicture() async {
    final fb.User? user = _auth.currentUser;

    if (user == null) {
      throw const ProfilePictureServiceException(
        'You must be logged in to change your profile picture.',
      );
    }

    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (file == null) {
      return null;
    }

    final Uint8List bytes;

    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const ProfilePictureServiceException(
        'CASLMS could not read the selected image.',
      );
    }

    if (bytes.isEmpty) {
      throw const ProfilePictureServiceException(
        'CASLMS could not read the selected image.',
      );
    }

    if (bytes.length > maximumBytes) {
      throw const ProfilePictureServiceException(
        'Profile picture must be 5 MB or smaller.',
      );
    }

    final String extension =
        (file.extension ?? '').trim().toLowerCase();

    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw const ProfilePictureServiceException(
        'Choose a JPG, JPEG, PNG, or WEBP image.',
      );
    }

    final String mimeType;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'webp':
        mimeType = 'image/webp';
        break;
      default:
        mimeType = 'application/octet-stream';
    }

    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(user.uid);

    final DocumentSnapshot<Map<String, dynamic>> profileDoc =
        await userRef.get();

    if (!profileDoc.exists || profileDoc.data() == null) {
      throw const ProfilePictureServiceException(
        'Your CASLMS profile could not be found.',
      );
    }

    final String oldPath =
        (profileDoc.data()?['photoPath'] ?? '').toString().trim();

    final String newPath =
        'profiles/${user.uid}/profile_image.$extension';

    final bucket = _supabase.storage.from(bucketName);

    try {
      await bucket.uploadBinary(
        newPath,
        bytes,
        fileOptions: sb.FileOptions(
          contentType: mimeType,
          cacheControl: '3600',
          upsert: true,
        ),
      );
    } on sb.StorageException catch (e) {
      throw ProfilePictureServiceException(
        e.message.isEmpty
            ? 'Unable to upload your profile picture.'
            : e.message,
      );
    } catch (_) {
      throw const ProfilePictureServiceException(
        'Unable to upload your profile picture.',
      );
    }

    final String baseUrl = bucket.getPublicUrl(newPath);
    final String photoUrl =
        '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    try {
      await userRef.update({
        'photoUrl': photoUrl,
        'photoPath': newPath,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await user.updatePhotoURL(photoUrl);
      } catch (_) {}

      if (oldPath.isNotEmpty && oldPath != newPath) {
        try {
          await bucket.remove([oldPath]);
        } catch (_) {}
      }

      return ProfilePictureResult(
        photoUrl: photoUrl,
        photoPath: newPath,
      );
    } catch (_) {
      try {
        await bucket.remove([newPath]);
      } catch (_) {}

      throw const ProfilePictureServiceException(
        'The image was uploaded, but CASLMS could not save it to your profile.',
      );
    }
  }

  Future<void> removeProfilePicture() async {
    final fb.User? user = _auth.currentUser;

    if (user == null) {
      throw const ProfilePictureServiceException(
        'You must be logged in.',
      );
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final profileDoc = await userRef.get();

    final String photoPath =
        (profileDoc.data()?['photoPath'] ?? '').toString().trim();

    if (photoPath.isNotEmpty) {
      try {
        await _supabase.storage.from(bucketName).remove([photoPath]);
      } catch (_) {}
    }

    await userRef.update({
      'photoUrl': FieldValue.delete(),
      'photoPath': FieldValue.delete(),
      'photoUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await user.updatePhotoURL(null);
    } catch (_) {}
  }
}
