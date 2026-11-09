import 'package:flutter/foundation.dart';

/// Session selection only. Callers must validate records through existing
/// authorized services before committing; this never grants access.
class InstructorWorkspaceContext extends ChangeNotifier {
  static final instance = InstructorWorkspaceContext();
  String? userId, courseId, sectionId;
  int _revision = 0;

  void bindUser(String? uid) {
    if (uid == userId) return;
    userId = uid;
    courseId = null;
    sectionId = null;
    _revision++;
    notifyListeners();
  }

  int beginCourse(String uid, String id) {
    bindUser(uid);
    if (courseId != id) {
      courseId = id;
      sectionId = null;
      notifyListeners();
    }
    return ++_revision;
  }

  bool commitSections(
    int revision,
    String uid,
    String course,
    List<Map<String, dynamic>> sections, {
    String? requested,
  }) {
    if (revision != _revision || userId != uid || courseId != course) {
      return false;
    }
    final candidate = requested ?? sectionId;
    sectionId =
        sections.any(
          (s) =>
              s['id'] == candidate &&
              s['courseId'] == course &&
              s['status'] == 'active',
        )
        ? candidate
        : null;
    notifyListeners();
    return true;
  }

  void clearCourse(String id, {int? revision}) {
    if (revision != null && revision != _revision) return;
    if (courseId != id) return;
    courseId = null;
    sectionId = null;
    _revision++;
    notifyListeners();
  }
}
