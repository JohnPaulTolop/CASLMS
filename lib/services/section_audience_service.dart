import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical section-audience policy shared by Flutter services.
///
/// New records always persist [sectionIds]. A missing field is accepted only
/// for legacy records and means all sections. Invalid stored values fail closed.
class SectionAudienceService {
  SectionAudienceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String allSections = '*';
  static const List<String> legacySharedAudience = <String>[allSections];

  final FirebaseFirestore _firestore;

  static List<String> validate(Object? value) {
    if (value is! List || value.isEmpty || value.length > 50) {
      throw const FormatException('Choose at least one section.');
    }
    final ids = <String>[];
    for (final value in value) {
      if (value is! String ||
          value.isEmpty ||
          value != value.trim() ||
          value.contains('/')) {
        throw const FormatException('Invalid section audience.');
      }
      ids.add(value);
    }
    if (ids.toSet().length != ids.length ||
        ids.contains(allSections) && ids.length != 1) {
      throw const FormatException('Invalid section audience.');
    }
    return List<String>.unmodifiable(ids);
  }

  static List<String> stored(Map<String, dynamic> record) {
    if (!record.containsKey('sectionIds')) return legacySharedAudience;
    return validate(record['sectionIds']);
  }

  static bool allows(List<String> audience, String sectionId) {
    return sectionId.isNotEmpty &&
        (audience.contains(allSections) || audience.contains(sectionId));
  }

  /// Instructor display filtering only; server authorization remains authoritative.
  /// All sections keeps every record available for management, including drafts.
  static bool visibleInInstructorSection(
    Map<String, dynamic> record,
    String? sectionId, {
    Map<String, dynamic>? parent,
  }) {
    if (sectionId == null || sectionId.isEmpty) return true;
    try {
      if (!allows(stored(record), sectionId)) return false;
      final singleSection = (record['sectionId'] ?? '').toString();
      if (singleSection.isNotEmpty && singleSection != sectionId) return false;
      if (parent == null) return true;
      return record['courseId'] == parent['courseId'] &&
          record['moduleId'] == (parent['moduleId'] ?? parent['id']) &&
          allows(stored(parent), sectionId);
    } on FormatException {
      return false;
    }
  }

  static List<Map<String, dynamic>> filterInstructorChildren(
    Iterable<Map<String, dynamic>> records,
    Iterable<Map<String, dynamic>> modules,
    String? sectionId,
  ) {
    if (sectionId == null || sectionId.isEmpty) return records.toList();
    final parents = {
      for (final module in modules)
        (module['moduleId'] ?? module['id']): module,
    };
    return records.where((record) {
      final parent = parents[record['moduleId']];
      return parent != null &&
          visibleInInstructorSection(record, sectionId, parent: parent);
    }).toList();
  }

  static void assertChild({
    required List<String> parent,
    required List<String> child,
  }) {
    if (!parent.contains(allSections) &&
        (child.contains(allSections) ||
            child.any((sectionId) => !parent.contains(sectionId)))) {
      throw const FormatException(
        'Content cannot be shared outside its module sections.',
      );
    }
  }

  static String label(
    List<String> audience,
    Iterable<Map<String, dynamic>> sections,
  ) {
    if (audience.contains(allSections)) return 'All sections';
    final namesById = <String, String>{
      for (final section in sections)
        (section['id'] ?? '').toString():
            (section['name'] ?? section['identifier'] ?? 'Section').toString(),
    };
    return audience
        .map((id) => namesById[id] ?? 'Unavailable section')
        .join(', ');
  }

  /// Validates every selected ID against canonical active course sections.
  /// The original course class code is an active virtual legacy section.
  Future<List<String>> requireActiveCourseSections({
    required String courseId,
    required Map<String, dynamic> course,
    required Object? sectionIds,
  }) async {
    final audience = validate(sectionIds);
    if (audience.contains(allSections)) return audience;

    final snapshot = await _firestore
        .collection('courseSections')
        .where('courseId', isEqualTo: courseId)
        .get();
    final activeIds = snapshot.docs
        .where((doc) => doc.data()['status'] == 'active')
        .map((doc) => doc.id)
        .toSet();
    final legacyId = (course['classCode'] ?? '').toString().trim();
    if (legacyId.isNotEmpty) activeIds.add(legacyId);

    if (audience.any((id) => !activeIds.contains(id))) {
      throw const FormatException(
        'Choose active sections belonging to this course.',
      );
    }
    return audience;
  }

  Future<Map<String, dynamic>> requireActiveEnrollment({
    required String courseId,
    required String studentId,
  }) async {
    final document = await _firestore
        .collection('enrollments')
        .doc('${courseId}_$studentId')
        .get(const GetOptions(source: Source.server));
    final data = document.data();
    if (data == null ||
        data['studentId'] != studentId ||
        data['courseId'] != courseId ||
        data['status'] != 'active') {
      throw const FormatException('An active section enrollment is required.');
    }
    var sectionId = (data['sectionId'] ?? '').toString().trim();
    if (sectionId.isEmpty) {
      final course = await _firestore
          .collection('courses')
          .doc(courseId)
          .get(const GetOptions(source: Source.server));
      final courseData = course.data();
      if (courseData?['status'] != 'active') {
        throw const FormatException(
          'An active section enrollment is required.',
        );
      }
      sectionId = (courseData?['classCode'] ?? '').toString().trim();
    }
    if (sectionId.isEmpty) {
      throw const FormatException('An active section enrollment is required.');
    }
    return <String, dynamic>{
      ...data,
      'id': document.id,
      'sectionId': sectionId,
    };
  }

  static bool studentCanAccess({
    required Map<String, dynamic> enrollment,
    required Map<String, dynamic> module,
    Map<String, dynamic>? child,
  }) {
    try {
      final courseId = (module['courseId'] ?? '').toString();
      final sectionId = (enrollment['sectionId'] ?? '').toString();
      if (courseId.isEmpty ||
          enrollment['courseId'] != courseId ||
          enrollment['status'] != 'active' ||
          module['status'] != 'published' ||
          !allows(stored(module), sectionId)) {
        return false;
      }
      if (child == null) return true;
      if (child['courseId'] != courseId ||
          child['moduleId'] == null ||
          !const <String>['published', 'closed'].contains(child['status']) ||
          !allows(stored(child), sectionId)) {
        return false;
      }
      final singleSection = (child['sectionId'] ?? '').toString();
      return singleSection.isEmpty || singleSection == sectionId;
    } on FormatException {
      return false;
    }
  }
}
