import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../config/supabase_config.dart';

class LearningMaterialService {
  LearningMaterialService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    sb.SupabaseClient? supabaseClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? fb.FirebaseAuth.instance,
       _supabase = supabaseClient ?? sb.Supabase.instance.client;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final sb.SupabaseClient _supabase;

  static const String collectionName = 'moduleResources';

  // ============================================================
  // CURRENT FIREBASE USER
  // ============================================================

  fb.User _requireAuthenticatedUser() {
    final fb.User? user = _auth.currentUser;

    if (user == null) {
      throw LearningMaterialException('You must be logged in.');
    }

    return user;
  }

  // ============================================================
  // CURRENT USER PROFILE
  // ============================================================

  Future<Map<String, dynamic>> _getCurrentUserProfile() async {
    final fb.User user = _requireAuthenticatedUser();

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!document.exists || document.data() == null) {
      throw LearningMaterialException('User profile could not be found.');
    }

    return {...document.data()!, 'uid': user.uid, 'id': user.uid};
  }

  // ============================================================
  // REQUIRE ACTIVE INSTRUCTOR
  // ============================================================

  Future<Map<String, dynamic>> _requireInstructor() async {
    final Map<String, dynamic> profile = await _getCurrentUserProfile();

    final String role = (profile['role'] ?? '').toString().trim().toLowerCase();

    if (role != 'instructor') {
      throw LearningMaterialException(
        'Only instructors can manage learning materials.',
      );
    }

    final String status = (profile['status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();

    if (status != 'active') {
      throw LearningMaterialException('Your instructor account is not active.');
    }

    return profile;
  }

  // ============================================================
  // VERIFY COURSE OWNERSHIP
  // ============================================================

  Future<Map<String, dynamic>> _requireOwnedCourse(String courseId) async {
    final Map<String, dynamic> instructor = await _requireInstructor();

    final String cleanCourseId = courseId.trim();

    if (cleanCourseId.isEmpty) {
      throw LearningMaterialException('Course ID is required.');
    }

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('courses')
        .doc(cleanCourseId)
        .get();

    if (!document.exists || document.data() == null) {
      throw LearningMaterialException('Course could not be found.');
    }

    final Map<String, dynamic> course = document.data()!;

    final String instructorId = (course['instructorId'] ?? '')
        .toString()
        .trim();

    if (instructorId != instructor['uid'].toString()) {
      throw LearningMaterialException(
        'You can only manage materials in your own courses.',
      );
    }

    return {...course, 'id': document.id, 'courseId': document.id};
  }

  // ============================================================
  // VERIFY MODULE
  // ============================================================

  Future<Map<String, dynamic>> _requireOwnedModule({
    required String courseId,
    required String moduleId,
  }) async {
    await _requireOwnedCourse(courseId);

    final String cleanModuleId = moduleId.trim();

    if (cleanModuleId.isEmpty) {
      throw LearningMaterialException('Module ID is required.');
    }

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('modules')
        .doc(cleanModuleId)
        .get();

    if (!document.exists || document.data() == null) {
      throw LearningMaterialException('Module could not be found.');
    }

    final Map<String, dynamic> module = document.data()!;

    final String moduleCourseId = (module['courseId'] ?? '').toString().trim();

    if (moduleCourseId != courseId.trim()) {
      throw LearningMaterialException(
        'This module does not belong to the selected course.',
      );
    }

    return {...module, 'id': document.id, 'moduleId': document.id};
  }

  // ============================================================
  // VERIFY STUDENT ENROLLMENT
  // ============================================================

  Future<void> _requireEnrollment({
    required String courseId,
    required String studentId,
  }) async {
    final String enrollmentId = '${courseId.trim()}_${studentId.trim()}';

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('enrollments')
        .doc(enrollmentId)
        .get();

    if (!document.exists || document.data() == null) {
      throw LearningMaterialException('You are not enrolled in this course.');
    }

    final String status = (document.data()!['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (status != 'active') {
      throw LearningMaterialException(
        'Your enrollment in this course is not active.',
      );
    }
  }

  // ============================================================
  // SAFE FILE NAME
  // ============================================================

  String _safeFileName(String fileName) {
    String name = fileName.trim();

    if (name.isEmpty) {
      name = 'learning_material';
    }

    name = name.replaceAll(RegExp(r'[^\w\-. ]'), '_');

    name = name.replaceAll(RegExp(r'\s+'), '_');

    return name;
  }

  // ============================================================
  // FILE EXTENSION
  // ============================================================

  String _extensionFromFileName(String fileName) {
    final String cleanName = fileName.trim();

    if (!cleanName.contains('.')) {
      return '';
    }

    return cleanName.split('.').last.trim().toLowerCase();
  }

  // ============================================================
  // MIME TYPE
  // ============================================================

  String contentTypeFromFileName(String fileName) {
    final String extension = _extensionFromFileName(fileName);

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

      case 'mp4':
        return 'video/mp4';

      case 'webm':
        return 'video/webm';

      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================
  // RESOURCE TYPE
  // ============================================================

  String resourceTypeFromFileName(String fileName) {
    final String extension = _extensionFromFileName(fileName);

    switch (extension) {
      case 'pdf':
        return 'pdf';

      case 'doc':
      case 'docx':
      case 'txt':
        return 'document';

      case 'ppt':
      case 'pptx':
        return 'presentation';

      case 'xls':
      case 'xlsx':
        return 'spreadsheet';

      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image';

      case 'mp4':
      case 'webm':
        return 'video';

      default:
        return 'file';
    }
  }

  // ============================================================
  // AI ELIGIBILITY
  //
  // Phase 7C-6 only PREPARES learning materials for future AI.
  // It does not call any AI API and does not extract text yet.
  // ============================================================

  bool isAiEligibleFile(String fileName) {
    final String extension = _extensionFromFileName(fileName);

    const Set<String> aiSupportedExtensions = {
      'pdf',
      'txt',
      'doc',
      'docx',
      'ppt',
      'pptx',
    };

    return aiSupportedExtensions.contains(extension);
  }

  // ============================================================
  // AI METADATA FOR UPLOADED FILE
  // ============================================================

  Map<String, dynamic> _aiMetadataForUploadedFile(String fileName) {
    final bool eligible = isAiEligibleFile(fileName);

    return {
      'aiEligible': eligible,

      // Future values:
      // pending | processing | ready | failed | unsupported
      'aiProcessingStatus': eligible ? 'pending' : 'unsupported',

      'aiTextExtracted': false,

      'aiTextLength': 0,

      'aiProcessedAt': null,

      'aiError': null,
    };
  }

  // ============================================================
  // AI METADATA FOR EXTERNAL LINK
  // ============================================================

  Map<String, dynamic> _aiMetadataForExternalLink() {
    return {
      'aiEligible': false,

      'aiProcessingStatus': 'unsupported',

      'aiTextExtracted': false,

      'aiTextLength': 0,

      'aiProcessedAt': null,

      'aiError': null,
    };
  }

  // ============================================================
  // VALIDATE FILE TYPE
  // ============================================================

  void _validateFileType(String fileName) {
    final String extension = _extensionFromFileName(fileName);

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
      'mp4',
      'webm',
    };

    if (!allowedExtensions.contains(extension)) {
      throw LearningMaterialException(
        extension.isEmpty
            ? 'The selected file has no supported extension.'
            : 'Unsupported file type: .$extension',
      );
    }
  }

  // ============================================================
  // UPLOAD LEARNING MATERIAL
  //
  // Actual file:
  // Supabase Storage
  //
  // Metadata:
  // Firestore
  // ============================================================

  Future<Map<String, dynamic>> uploadLearningMaterial({
    required String courseId,
    required String moduleId,
    required String title,
    String description = '',
    required String fileName,
    required Uint8List fileBytes,
    String status = 'published',
  }) async {
    final Map<String, dynamic> instructor = await _requireInstructor();

    await _requireOwnedModule(courseId: courseId, moduleId: moduleId);

    final String cleanCourseId = courseId.trim();
    final String cleanModuleId = moduleId.trim();
    final String cleanTitle = title.trim();
    final String cleanFileName = fileName.trim();

    if (cleanTitle.isEmpty) {
      throw LearningMaterialException('Learning material title is required.');
    }

    if (cleanFileName.isEmpty) {
      throw LearningMaterialException('File name is missing.');
    }

    if (fileBytes.isEmpty) {
      throw LearningMaterialException('The selected file is empty.');
    }

    _validateFileType(cleanFileName);

    // 50 MB development limit.
    const int maximumFileSize = 50 * 1024 * 1024;

    if (fileBytes.length > maximumFileSize) {
      throw LearningMaterialException('File size must not exceed 50 MB.');
    }

    final String normalizedStatus = status.trim().toLowerCase();

    if (normalizedStatus != 'draft' && normalizedStatus != 'published') {
      throw LearningMaterialException('Invalid learning material status.');
    }

    // ----------------------------------------------------------
    // CREATE FIRESTORE ID FIRST
    // ----------------------------------------------------------

    final DocumentReference<Map<String, dynamic>> resourceReference = _firestore
        .collection(collectionName)
        .doc();

    final String resourceId = resourceReference.id;

    final String safeFileName = _safeFileName(cleanFileName);

    // ----------------------------------------------------------
    // SUPABASE STORAGE PATH
    // ----------------------------------------------------------

    final String storagePath =
        'courses/'
        '$cleanCourseId/'
        'modules/'
        '$cleanModuleId/'
        '$resourceId/'
        '$safeFileName';

    final bucket = _supabase.storage.from(
      SupabaseConfig.learningMaterialsBucket,
    );

    bool uploadedToSupabase = false;

    try {
      final String mimeType = contentTypeFromFileName(cleanFileName);

      // --------------------------------------------------------
      // SUPABASE UPLOAD
      // --------------------------------------------------------

      await bucket.uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: sb.FileOptions(
          contentType: mimeType,
          cacheControl: '3600',
          upsert: false,
        ),
      );

      uploadedToSupabase = true;

      // --------------------------------------------------------
      // PUBLIC STORAGE URL
      // --------------------------------------------------------

      final String fileUrl = bucket.getPublicUrl(storagePath);

      final String resourceType = resourceTypeFromFileName(cleanFileName);

      // --------------------------------------------------------
      // FIRESTORE METADATA
      // --------------------------------------------------------

      final Map<String, dynamic> data = {
        'courseId': cleanCourseId,

        'moduleId': cleanModuleId,

        'createdBy': instructor['uid'].toString(),

        'title': cleanTitle,

        'description': description.trim(),

        'resourceType': resourceType,

        'deliveryType': 'uploaded_file',

        'storageProvider': 'supabase',

        'storageBucket': SupabaseConfig.learningMaterialsBucket,

        'storagePath': storagePath,

        'fileName': cleanFileName,

        'fileUrl': fileUrl,

        'externalUrl': null,

        'mimeType': mimeType,

        'sizeBytes': fileBytes.length,

        'status': normalizedStatus,

        // ------------------------------------------------------
        // PHASE 7C-6 AI PREPARATION
        // ------------------------------------------------------
        ..._aiMetadataForUploadedFile(cleanFileName),

        'createdAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),
      };

      await resourceReference.set(data);

      return {...data, 'id': resourceId, 'resourceId': resourceId};
    } catch (e) {
      // --------------------------------------------------------
      // REMOVE ORPHAN FILE IF FIRESTORE SAVE FAILED
      // --------------------------------------------------------

      if (uploadedToSupabase) {
        try {
          await bucket.remove([storagePath]);
        } catch (_) {}
      }

      if (e is LearningMaterialException) {
        rethrow;
      }

      throw LearningMaterialException('Unable to upload learning material: $e');
    }
  }

  // ============================================================
  // CREATE EXTERNAL LINK MATERIAL
  // ============================================================

  Future<Map<String, dynamic>> createLinkMaterial({
    required String courseId,
    required String moduleId,
    required String title,
    String description = '',
    required String url,
    String resourceType = 'link',
    String status = 'published',
  }) async {
    final Map<String, dynamic> instructor = await _requireInstructor();

    await _requireOwnedModule(courseId: courseId, moduleId: moduleId);

    final String cleanTitle = title.trim();
    final String cleanUrl = url.trim();

    if (cleanTitle.isEmpty) {
      throw LearningMaterialException('Learning material title is required.');
    }

    final Uri? uri = Uri.tryParse(cleanUrl);

    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw LearningMaterialException('Enter a valid HTTP or HTTPS URL.');
    }

    final String normalizedStatus = status.trim().toLowerCase();

    if (normalizedStatus != 'draft' && normalizedStatus != 'published') {
      throw LearningMaterialException('Invalid learning material status.');
    }

    final String normalizedType = resourceType.trim().toLowerCase();

    const Set<String> allowedTypes = {'link', 'video'};

    if (!allowedTypes.contains(normalizedType)) {
      throw LearningMaterialException('Invalid external resource type.');
    }

    final DocumentReference<Map<String, dynamic>> document = _firestore
        .collection(collectionName)
        .doc();

    final Map<String, dynamic> data = {
      'courseId': courseId.trim(),

      'moduleId': moduleId.trim(),

      'createdBy': instructor['uid'].toString(),

      'title': cleanTitle,

      'description': description.trim(),

      'resourceType': normalizedType,

      'deliveryType': 'external_link',

      'storageProvider': null,

      'storageBucket': null,

      'storagePath': null,

      'fileName': null,

      'fileUrl': null,

      'externalUrl': cleanUrl,

      'mimeType': null,

      'sizeBytes': null,

      'status': normalizedStatus,

      // External links are not AI-eligible in the first version.
      ..._aiMetadataForExternalLink(),

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    };

    await document.set(data);

    return {...data, 'id': document.id, 'resourceId': document.id};
  }

  // ============================================================
  // GET MATERIAL BY ID
  // ============================================================

  Future<Map<String, dynamic>?> getMaterialById(String resourceId) async {
    final String cleanId = resourceId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection(collectionName)
        .doc(cleanId)
        .get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return {...document.data()!, 'id': document.id, 'resourceId': document.id};
  }

  // ============================================================
  // GET MODULE MATERIALS
  // ============================================================

  Future<List<Map<String, dynamic>>> getModuleMaterials({
    required String courseId,
    required String moduleId,
    bool publishedOnly = true,
  }) async {
    final Map<String, dynamic> user = await _getCurrentUserProfile();

    final String userId = user['uid'].toString();

    final String role = (user['role'] ?? '').toString().trim().toLowerCase();

    final String cleanCourseId = courseId.trim();

    final String cleanModuleId = moduleId.trim();

    // ----------------------------------------------------------
    // PERMISSION CHECK
    // ----------------------------------------------------------

    if (role == 'instructor') {
      await _requireOwnedModule(
        courseId: cleanCourseId,
        moduleId: cleanModuleId,
      );
    } else if (role == 'student') {
      final String status = (user['status'] ?? 'active')
          .toString()
          .trim()
          .toLowerCase();

      if (status != 'active') {
        throw LearningMaterialException('Your student account is not active.');
      }

      await _requireEnrollment(courseId: cleanCourseId, studentId: userId);

      // Students never receive draft materials.
      publishedOnly = true;
    } else {
      throw LearningMaterialException(
        'You do not have permission to view these learning materials.',
      );
    }

    // ----------------------------------------------------------
    // FIRESTORE QUERY
    // ----------------------------------------------------------

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(collectionName)
        .where('moduleId', isEqualTo: cleanModuleId)
        .get();

    final List<Map<String, dynamic>> materials = [];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      if ((data['courseId'] ?? '').toString().trim() != cleanCourseId) {
        continue;
      }

      final String materialStatus = (data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (publishedOnly && materialStatus != 'published') {
        continue;
      }

      materials.add({...data, 'id': document.id, 'resourceId': document.id});
    }

    // Newest first.
    materials.sort((a, b) {
      final DateTime? aDate = _dateFrom(a['createdAt']);

      final DateTime? bDate = _dateFrom(b['createdAt']);

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return 1;
      }

      if (bDate == null) {
        return -1;
      }

      return bDate.compareTo(aDate);
    });

    return materials;
  }

  // ============================================================
  // GET AI-ELIGIBLE MODULE MATERIALS
  //
  // Instructor only.
  //
  // These are possible sources for the future AI features.
  // ============================================================

  Future<List<Map<String, dynamic>>> getAiEligibleModuleMaterials({
    required String courseId,
    required String moduleId,
  }) async {
    await _requireOwnedModule(courseId: courseId, moduleId: moduleId);

    final List<Map<String, dynamic>> materials = await getModuleMaterials(
      courseId: courseId,
      moduleId: moduleId,
      publishedOnly: false,
    );

    return materials.where((Map<String, dynamic> material) {
      final bool eligible = material['aiEligible'] == true;

      final String deliveryType = (material['deliveryType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      return eligible && deliveryType == 'uploaded_file';
    }).toList();
  }

  // ============================================================
  // PREPARE EXISTING MATERIALS FOR AI
  //
  // Materials uploaded before Phase 7C-6 do not yet have the
  // AI metadata fields. This method safely backfills them.
  //
  // Already prepared materials are skipped so future processing
  // results are never reset accidentally.
  // ============================================================

  Future<int> prepareModuleMaterialsForAi({
    required String courseId,
    required String moduleId,
  }) async {
    await _requireOwnedModule(courseId: courseId, moduleId: moduleId);

    final String cleanCourseId = courseId.trim();

    final String cleanModuleId = moduleId.trim();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(collectionName)
        .where('moduleId', isEqualTo: cleanModuleId)
        .get();

    final WriteBatch batch = _firestore.batch();

    int updatedCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      if ((data['courseId'] ?? '').toString().trim() != cleanCourseId) {
        continue;
      }

      final bool alreadyPrepared =
          data.containsKey('aiEligible') &&
          data.containsKey('aiProcessingStatus') &&
          data.containsKey('aiTextExtracted') &&
          data.containsKey('aiTextLength') &&
          data.containsKey('aiProcessedAt') &&
          data.containsKey('aiError');

      if (alreadyPrepared) {
        continue;
      }

      final String deliveryType = (data['deliveryType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      late final Map<String, dynamic> aiMetadata;

      if (deliveryType == 'uploaded_file') {
        final String fileName = (data['fileName'] ?? '').toString().trim();

        aiMetadata = _aiMetadataForUploadedFile(fileName);
      } else {
        aiMetadata = _aiMetadataForExternalLink();
      }

      batch.update(document.reference, {
        ...aiMetadata,

        'updatedAt': FieldValue.serverTimestamp(),
      });

      updatedCount++;
    }

    if (updatedCount > 0) {
      await batch.commit();
    }

    return updatedCount;
  }

  // ============================================================
  // UPDATE MATERIAL STATUS
  // ============================================================

  Future<void> updateMaterialStatus({
    required String resourceId,
    required String status,
  }) async {
    await _requireInstructor();

    final String cleanId = resourceId.trim();

    if (cleanId.isEmpty) {
      throw LearningMaterialException('Learning material ID is required.');
    }

    final String normalizedStatus = status.trim().toLowerCase();

    if (normalizedStatus != 'draft' && normalizedStatus != 'published') {
      throw LearningMaterialException('Invalid learning material status.');
    }

    final DocumentReference<Map<String, dynamic>> reference = _firestore
        .collection(collectionName)
        .doc(cleanId);

    final DocumentSnapshot<Map<String, dynamic>> document = await reference
        .get();

    if (!document.exists || document.data() == null) {
      throw LearningMaterialException('Learning material could not be found.');
    }

    final Map<String, dynamic> material = document.data()!;

    await _requireOwnedModule(
      courseId: (material['courseId'] ?? '').toString(),
      moduleId: (material['moduleId'] ?? '').toString(),
    );

    await reference.update({
      'status': normalizedStatus,

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DELETE MATERIAL
  // ============================================================

  Future<void> deleteMaterial(String resourceId) async {
    await _requireInstructor();

    final String cleanId = resourceId.trim();

    if (cleanId.isEmpty) {
      throw LearningMaterialException('Learning material ID is required.');
    }

    final DocumentReference<Map<String, dynamic>> resourceReference = _firestore
        .collection(collectionName)
        .doc(cleanId);

    final DocumentSnapshot<Map<String, dynamic>> document =
        await resourceReference.get();

    if (!document.exists || document.data() == null) {
      throw LearningMaterialException('Learning material could not be found.');
    }

    final Map<String, dynamic> material = document.data()!;

    await _requireOwnedModule(
      courseId: (material['courseId'] ?? '').toString(),
      moduleId: (material['moduleId'] ?? '').toString(),
    );

    final String deliveryType = (material['deliveryType'] ?? '')
        .toString()
        .trim();

    final String storagePath = (material['storagePath'] ?? '')
        .toString()
        .trim();

    // ----------------------------------------------------------
    // REMOVE ACTUAL SUPABASE FILE
    // ----------------------------------------------------------

    if (deliveryType == 'uploaded_file' && storagePath.isNotEmpty) {
      try {
        final bucket = _supabase.storage.from(
          SupabaseConfig.learningMaterialsBucket,
        );

        await bucket.remove([storagePath]);
      } catch (e) {
        throw LearningMaterialException(
          'Unable to remove file from Supabase Storage: $e',
        );
      }
    }

    // ----------------------------------------------------------
    // REMOVE FIRESTORE METADATA
    // ----------------------------------------------------------

    await resourceReference.delete();
  }

  // ============================================================
  // DATE HELPER
  // ============================================================

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}

// ============================================================
// EXCEPTION
// ============================================================

class LearningMaterialException implements Exception {
  LearningMaterialException(this.message);

  final String message;

  @override
  String toString() => message;
}
