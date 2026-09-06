import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef ProgressRow = Map<String, dynamic>;

class ProgressService {
  ProgressService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;

  ProgressRow _row(String id, ProgressRow data) {
    return {
      for (final entry in data.entries)
        entry.key: entry.value is Timestamp
            ? (entry.value as Timestamp).toDate()
            : entry.value,
      'id': id,
    };
  }

  Stream<List<ProgressRow>> _rows(Query<ProgressRow> query) {
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((document) {
        return _row(document.id, document.data());
      }).toList();
    });
  }

  Stream<ProgressRow> watchStudentProgress() async* {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw ProgressServiceException('Please sign in.');
    }

    final profile = await _firestore.collection('users').doc(user.uid).get();

    final role = _ProgressCalculator.lower(profile.data()?['role']);

    final status = _ProgressCalculator.lower(
      profile.data()?['status'] ?? 'active',
    );

    if (role != 'student' || status != 'active') {
      throw ProgressServiceException('An active student account is required.');
    }

    final enrollmentStream = _rows(
      _firestore
          .collection('enrollments')
          .where('studentId', isEqualTo: user.uid),
    );

    final courseIds = enrollmentStream
        .map((rows) {
          final result = rows
              .where(
                (row) => _ProgressCalculator.lower(row['status']) == 'active',
              )
              .map((row) => _ProgressCalculator.text(row['courseId']))
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          result.sort();
          return result;
        })
        .distinct((previous, next) => previous.join('|') == next.join('|'));

    yield* _switchLatest(courseIds.map((ids) => _watchCourses(user.uid, ids)));
  }

  Stream<ProgressRow> _watchCourses(String studentId, List<String> courseIds) {
    if (courseIds.isEmpty) {
      return Stream.value(_ProgressCalculator.overall([]));
    }

    final streams = <Stream<List<ProgressRow>>>[
      _rows(
        _firestore
            .collection('assessmentSubmissions')
            .where('studentId', isEqualTo: studentId),
      ),
      _rows(
        _firestore
            .collection('submissions')
            .where('studentId', isEqualTo: studentId),
      ),
      _rows(
        _firestore
            .collection('quiz_attempts')
            .where('studentId', isEqualTo: studentId),
      ),
    ];

    for (final courseId in courseIds) {
      streams.add(
        _firestore.collection('courses').doc(courseId).snapshots().map((
          document,
        ) {
          final data = document.data();

          if (!document.exists || data == null) {
            return <ProgressRow>[];
          }

          return [_row(document.id, data)];
        }),
      );

      for (final collection in [
        'modules',
        'assessments',
        'assignments',
        'quizzes',
      ]) {
        streams.add(
          _rows(
            _firestore
                .collection(collection)
                .where('courseId', isEqualTo: courseId),
          ),
        );
      }
    }

    return _combineLatest(streams).map((data) {
      final courses = <ProgressRow>[];

      for (var index = 0; index < courseIds.length; index++) {
        final offset = 3 + index * 5;

        if (data[offset].isEmpty) {
          continue;
        }

        final course = data[offset].first;

        if (_ProgressCalculator.lower(course['status']) != 'active') {
          continue;
        }

        courses.add(
          _ProgressCalculator.course(
            course: course,
            modules: data[offset + 1],
            assessments: data[offset + 2],
            assignments: data[offset + 3],
            quizzes: data[offset + 4],
            assessmentSubmissions: data[0],
            assignmentSubmissions: data[1],
            quizAttempts: data[2],
          ),
        );
      }

      courses.sort((a, b) {
        return _ProgressCalculator.text(a['code'])
            .compareTo(_ProgressCalculator.text(b['code']));
      });

      return _ProgressCalculator.overall(courses);
    });
  }

  Future<ProgressRow> getProgressDashboard() {
    return watchStudentProgress().first;
  }

  Future<ProgressRow> getOverallLearningProgress() {
    return getProgressDashboard();
  }

  Future<ProgressRow> getOverallAcademicPerformance() {
    return getProgressDashboard();
  }

  Future<ProgressRow> getOverallModuleProgress() {
    return getProgressDashboard();
  }

  Future<List<ProgressRow>> getStudentCourses() async {
    final report = await getProgressDashboard();

    final dynamic rawCourses = report['courses'];

    if (rawCourses is! List) {
      return [];
    }

    return rawCourses
        .whereType<Map>()
        .map((course) => Map<String, dynamic>.from(course))
        .toList();
  }

  Future<ProgressRow> getCourseModuleProgress({
    required String courseId,
  }) async {
    final cleanCourseId = courseId.trim();

    if (cleanCourseId.isEmpty) {
      throw ProgressServiceException('Course ID is missing.');
    }

    final courses = await getStudentCourses();

    return courses.firstWhere(
      (course) => _ProgressCalculator.text(course['courseId']) == cleanCourseId,
      orElse: () {
        throw ProgressServiceException('No active enrollment for this course.');
      },
    );
  }

  Future<ProgressRow> getCourseLearningProgress({required String courseId}) {
    return getCourseModuleProgress(courseId: courseId);
  }

  Future<ProgressRow> getCourseAcademicPerformance({required String courseId}) {
    return getCourseModuleProgress(courseId: courseId);
  }

  Stream<ProgressRow> watchCourseProgress({required String courseId}) {
    final cleanCourseId = courseId.trim();

    return watchStudentProgress().map((report) {
      final dynamic rawCourses = report['courses'];

      if (rawCourses is List) {
        for (final rawCourse in rawCourses) {
          if (rawCourse is! Map) {
            continue;
          }

          final course = Map<String, dynamic>.from(rawCourse);

          if (_ProgressCalculator.text(course['courseId']) == cleanCourseId) {
            return course;
          }
        }
      }

      throw ProgressServiceException('No active enrollment for this course.');
    });
  }

  Future<List<ProgressRow>> getPublishedModulesForCourse({
    required String courseId,
  }) async {
    final course = await getCourseModuleProgress(courseId: courseId);

    final dynamic rawModules = course['modules'];

    if (rawModules is! List) {
      return [];
    }

    return rawModules
        .whereType<Map>()
        .map((module) => Map<String, dynamic>.from(module))
        .toList();
  }

  Future<ProgressRow> getCourseQuizProgress({required String courseId}) async {
    final course = await getCourseModuleProgress(courseId: courseId);

    return {
      ...course,
      'progress': course['quizProgress'],
      'earnedPoints': course['quizEarnedPoints'],
      'availablePoints': course['quizAvailablePoints'],
      'scorePercentage': course['quizPercentage'],
      'percentage': course['quizPercentage'],
    };
  }

  Future<ProgressRow> getCourseQuizPerformance({required String courseId}) {
    return getCourseQuizProgress(courseId: courseId);
  }

  Future<ProgressRow> getCourseAssignmentProgress({
    required String courseId,
  }) async {
    final course = await getCourseModuleProgress(courseId: courseId);

    return {
      ...course,
      'progress': course['assignmentProgress'],
      'earnedPoints': course['assignmentEarnedPoints'],
      'availablePoints': course['assignmentAvailablePoints'],
      'percentage': course['assignmentPercentage'],
    };
  }

  Future<ProgressRow> getCourseAssignmentPerformance({
    required String courseId,
  }) {
    return getCourseAssignmentProgress(courseId: courseId);
  }

  Stream<bool> watchModuleCompleted({required String moduleId}) {
    final cleanModuleId = moduleId.trim();

    return watchStudentProgress().map((report) {
      final dynamic rawCourses = report['courses'];

      if (rawCourses is! List) {
        return false;
      }

      for (final rawCourse in rawCourses) {
        if (rawCourse is! Map) {
          continue;
        }

        final dynamic rawModules = rawCourse['modules'];

        if (rawModules is! List) {
          continue;
        }

        for (final rawModule in rawModules) {
          if (rawModule is! Map) {
            continue;
          }

          if (_ProgressCalculator.text(rawModule['moduleId']) ==
                  cleanModuleId &&
              rawModule['completed'] == true) {
            return true;
          }
        }
      }

      return false;
    });
  }

  Stream<List<ProgressRow>> watchCompletedModulesForCourse({
    required String courseId,
  }) {
    return watchCourseProgress(courseId: courseId).map((course) {
      final dynamic rawModules = course['modules'];

      if (rawModules is! List) {
        return <ProgressRow>[];
      }

      return rawModules
          .whereType<Map>()
          .where((module) => module['completed'] == true)
          .map((module) => Map<String, dynamic>.from(module))
          .toList();
    });
  }

  String buildModuleProgressId({
    required String moduleId,
    required String studentId,
  }) {
    return '${moduleId.trim()}_${studentId.trim()}';
  }

  Future<void> markModuleComplete({
    required String moduleId,
    required String courseId,
  }) async {
    throw ProgressServiceException(
      'Module progress is calculated automatically from completed tasks.',
    );
  }

  Future<void> markModuleIncomplete({required String moduleId}) async {
    throw ProgressServiceException(
      'Module progress is calculated automatically from completed tasks.',
    );
  }
}

class _ProgressCalculator {
  static String text(dynamic value) => (value ?? '').toString().trim();

  static String lower(dynamic value) => text(value).toLowerCase();

  static double ratio(num completed, num total) {
    if (total <= 0) {
      return 0;
    }

    return (completed / total).clamp(0.0, 1.0).toDouble();
  }

  static int _time(ProgressRow row) {
    for (final key in ['gradedAt', 'submittedAt', 'updatedAt']) {
      final value = row[key];

      if (value is DateTime) {
        return value.millisecondsSinceEpoch;
      }

      if (value is Timestamp) {
        return value.millisecondsSinceEpoch;
      }

      if (value is int) {
        return value;
      }
    }

    return 0;
  }

  static num? _total(ProgressRow result, ProgressRow task) {
    final value =
        result['totalPoints'] ?? task['totalPoints'] ?? task['points'];

    if (value is num && value.isFinite && value > 0) {
      return value;
    }

    return null;
  }

  static bool _isScored(ProgressRow result, ProgressRow task, String source) {
    final status = lower(result['status']);

    final validStatus =
        status == 'graded' || (source == 'quiz' && status == 'submitted');

    final score = result['score'];

    final total = _total(result, task);

    return validStatus &&
        score is num &&
        score.isFinite &&
        total != null &&
        score >= 0 &&
        score <= total;
  }

  static ProgressRow course({
    required ProgressRow course,
    required List<ProgressRow> modules,
    required List<ProgressRow> assessments,
    required List<ProgressRow> assignments,
    required List<ProgressRow> quizzes,
    required List<ProgressRow> assessmentSubmissions,
    required List<ProgressRow> assignmentSubmissions,
    required List<ProgressRow> quizAttempts,
  }) {
    final courseId = text(course['id']);

    final publishedModules = modules.where((module) {
      return text(module['courseId']) == courseId &&
          lower(module['status']) == 'published';
    }).toList();

    final moduleIds = publishedModules
        .map((module) => text(module['id']))
        .toSet();

    final modernAssessmentIds = assessments
        .map((assessment) => text(assessment['id']))
        .toSet();

    final tasks = <ProgressRow>[];

    num quizEarned = 0;
    num quizAvailable = 0;

    num assignmentEarned = 0;
    num assignmentAvailable = 0;

    int gradedQuizzes = 0;
    int gradedAssignments = 0;
    int passedQuizzes = 0;

    void addTasks(
      List<ProgressRow> definitions,
      List<ProgressRow> results,
      String source,
      String parentKey,
    ) {
      for (final task in definitions) {
        if (text(task['courseId']) != courseId) {
          continue;
        }

        // Avoid counting a legacy task twice when
        // it is linked to a modern assessment.
        if (source != 'assessment' &&
            modernAssessmentIds.contains(text(task['assessmentId']))) {
          continue;
        }

        final taskStatus = lower(task['status']);

        final available =
            taskStatus == 'published' ||
            (source == 'assessment' && taskStatus == 'closed');

        if (!available) {
          continue;
        }

        final taskId = text(task['id']);

        final bool isQuiz =
            source == 'quiz' || lower(task['assessmentType']) == 'quiz';

        final matches = results.where((result) {
          return text(result['courseId']) == courseId &&
              text(result[parentKey]) == taskId;
        }).toList();

        matches.sort((a, b) {
          final timeOrder = _time(b).compareTo(_time(a));

          if (timeOrder != 0) {
            return timeOrder;
          }

          return text(a['id']).compareTo(text(b['id']));
        });

        ProgressRow? grade;

        for (final result in matches) {
          if (_isScored(result, task, source)) {
            grade = result;
            break;
          }
        }

        if (grade != null) {
          final score = grade['score'] as num;

          final total = _total(grade, task)!;

          if (isQuiz) {
            quizEarned += score;
            quizAvailable += total;
            gradedQuizzes++;

            final passingScore = task['passingScore'];

            if (passingScore is! num || score >= passingScore) {
              passedQuizzes++;
            }
          } else {
            assignmentEarned += score;

            assignmentAvailable += total;

            gradedAssignments++;
          }
        }

        final moduleId = text(task['moduleId']);

        // A task in an unpublished module is not
        // included in learning progress.
        if (moduleId.isNotEmpty && !moduleIds.contains(moduleId)) {
          continue;
        }

        final submittedAssignment =
            source == 'assignment' &&
            matches.any((result) {
              final status = lower(result['status']);

              final hasWork =
                  text(result['answerText']).isNotEmpty ||
                  text(result['fileUrl']).isNotEmpty;

              return ['submitted', 'graded'].contains(status) &&
                  result['submittedAt'] != null &&
                  hasWork;
            });

        // External assessments count as complete only
        // when the submission contains verifiable work.
        final submittedExternal =
            source == 'assessment' &&
            lower(task['deliveryType']) != 'ai_generated' &&
            matches.any((result) {
              final status = lower(result['status']);

              if (!['submitted', 'graded'].contains(status) ||
                  result['submittedAt'] == null) {
                return false;
              }

              final submissionType = lower(result['submissionType']);

              if (submissionType == 'github_repository') {
                final uri = Uri.tryParse(text(result['repositoryUrl']));

                return uri != null &&
                    uri.scheme == 'https' &&
                    uri.host.toLowerCase() == 'github.com' &&
                    uri.pathSegments.where((part) => part.isNotEmpty).length >=
                        2;
              }

              if (submissionType == 'zip_file' ||
                  submissionType == 'technical_document') {
                final size = result['sizeBytes'];

                return lower(result['storageProvider']) == 'supabase' &&
                    text(result['storageBucket']) ==
                        'caslms-assessment-submissions' &&
                    text(result['storagePath']).isNotEmpty &&
                    text(result['fileName']).isNotEmpty &&
                    size is num &&
                    size > 0 &&
                    size <= 20 * 1024 * 1024;
              }

              if (submissionType == 'google_form') {
                return lower(result['submissionSource']) ==
                        'google_forms_webhook' &&
                    text(result['googleFormResponseId']).isNotEmpty &&
                    text(result['studentEmail']).isNotEmpty;
              }

              return false;
            });

        final inProgress = matches.any((result) {
          return lower(result['status']) == 'in_progress';
        });

        tasks.add({
          'id': '$source:$taskId',
          'title': text(task['title']),
          'moduleId': moduleId,
          'isQuiz': isQuiz,
          'completed':
              grade != null || submittedAssignment || submittedExternal,
          'inProgress': inProgress,
          'graded': grade != null,
        });
      }
    }

    addTasks(assessments, assessmentSubmissions, 'assessment', 'assessmentId');

    addTasks(assignments, assignmentSubmissions, 'assignment', 'assignmentId');

    addTasks(quizzes, quizAttempts, 'quiz', 'quizId');

    final moduleReports = publishedModules.map((module) {
      final moduleId = text(module['id']);

      final moduleTasks = tasks
          .where((task) => text(task['moduleId']) == moduleId)
          .toList();

      final completedTasks = moduleTasks
          .where((task) => task['completed'] == true)
          .length;

      return <String, dynamic>{
        ...module,
        'moduleId': moduleId,
        'totalTasks': moduleTasks.length,
        'completedTasks': completedTasks,
        'taskProgress': ratio(completedTasks, moduleTasks.length),

        // Empty modules stay incomplete.
        'completed':
            moduleTasks.isNotEmpty && completedTasks == moduleTasks.length,
      };
    }).toList();

    moduleReports.sort((a, b) {
      final orderA = (a['order'] as num?) ?? 0;

      final orderB = (b['order'] as num?) ?? 0;

      return orderA.compareTo(orderB);
    });

    final completedModules = moduleReports
        .where((module) => module['completed'] == true)
        .length;

    final quizTasks = tasks.where((task) => task['isQuiz'] == true).toList();

    final assignmentTasks = tasks
        .where((task) => task['isQuiz'] != true)
        .toList();

    final completedQuizzes = quizTasks
        .where((task) => task['completed'] == true)
        .length;

    final inProgressQuizzes = quizTasks
        .where(
          (task) => task['completed'] != true && task['inProgress'] == true,
        )
        .length;

    final completedAssignments = assignmentTasks
        .where((task) => task['completed'] == true)
        .length;

    final completedTasks = tasks
        .where((task) => task['completed'] == true)
        .length;

    final earnedPoints = quizEarned + assignmentEarned;

    final availablePoints = quizAvailable + assignmentAvailable;

    return {
      ...course,
      'courseId': courseId,
      'modules': moduleReports,
      'tasks': tasks,

      'totalModules': moduleReports.length,
      'completedModules': completedModules,
      'remainingModules': moduleReports.length - completedModules,
      'moduleProgress': ratio(completedModules, moduleReports.length),
      'progress': ratio(completedModules, moduleReports.length),

      'totalItems': tasks.length,
      'completedItems': completedTasks,
      'remainingItems': tasks.length - completedTasks,
      'learningProgress': ratio(completedTasks, tasks.length),

      'totalQuizzes': quizTasks.length,
      'completedQuizzes': completedQuizzes,
      'inProgressQuizzes': inProgressQuizzes,
      'passedQuizzes': passedQuizzes,
      'remainingQuizzes': quizTasks.length - completedQuizzes,
      'quizProgress': ratio(completedQuizzes, quizTasks.length),

      'totalAssignments': assignmentTasks.length,
      'submittedAssignments': completedAssignments,
      'remainingAssignments': assignmentTasks.length - completedAssignments,
      'assignmentProgress': ratio(completedAssignments, assignmentTasks.length),

      'gradedAssignments': gradedAssignments,
      'gradedQuizzes': gradedQuizzes,
      'gradedItems': gradedAssignments + gradedQuizzes,

      'quizEarnedPoints': quizEarned,
      'quizAvailablePoints': quizAvailable,
      'quizPercentage': ratio(quizEarned, quizAvailable),

      'assignmentEarnedPoints': assignmentEarned,
      'assignmentAvailablePoints': assignmentAvailable,
      'assignmentPercentage': ratio(assignmentEarned, assignmentAvailable),

      'earnedPoints': earnedPoints,
      'availablePoints': availablePoints,
      'percentage': ratio(earnedPoints, availablePoints),
      'hasGrades': availablePoints > 0,

      'academicPerformance': ratio(earnedPoints, availablePoints),
      'academicEarnedPoints': earnedPoints,
      'academicAvailablePoints': availablePoints,
    };
  }

  static ProgressRow overall(List<ProgressRow> courses) {
    num sum(String key) {
      return courses.fold<num>(0, (total, course) {
        return total + ((course[key] as num?) ?? 0);
      });
    }

    final result = <String, dynamic>{
      'courses': courses,
      'courseCount': courses.length,
    };

    for (final key in [
      'totalModules',
      'completedModules',
      'remainingModules',
      'totalItems',
      'completedItems',
      'remainingItems',
      'totalQuizzes',
      'completedQuizzes',
      'inProgressQuizzes',
      'passedQuizzes',
      'remainingQuizzes',
      'totalAssignments',
      'submittedAssignments',
      'remainingAssignments',
      'gradedAssignments',
      'gradedQuizzes',
      'gradedItems',
      'quizEarnedPoints',
      'quizAvailablePoints',
      'assignmentEarnedPoints',
      'assignmentAvailablePoints',
      'earnedPoints',
      'availablePoints',
    ]) {
      result[key] = sum(key);
    }

    result.addAll({
      'moduleProgress': ratio(sum('completedModules'), sum('totalModules')),
      'progress': ratio(sum('completedModules'), sum('totalModules')),
      'learningProgress': ratio(sum('completedItems'), sum('totalItems')),
      'quizProgress': ratio(sum('completedQuizzes'), sum('totalQuizzes')),
      'assignmentProgress': ratio(
        sum('submittedAssignments'),
        sum('totalAssignments'),
      ),
      'quizPercentage': ratio(
        sum('quizEarnedPoints'),
        sum('quizAvailablePoints'),
      ),
      'assignmentPercentage': ratio(
        sum('assignmentEarnedPoints'),
        sum('assignmentAvailablePoints'),
      ),
      'percentage': ratio(sum('earnedPoints'), sum('availablePoints')),
      'hasGrades': sum('availablePoints') > 0,
    });

    return result;
  }
}

Stream<List<T>> _combineLatest<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) {
    return Stream.value(<T>[]);
  }

  late StreamController<List<T>> controller;

  final subscriptions = <StreamSubscription<T>>[];

  final values = List<T?>.filled(streams.length, null);

  final ready = List<bool>.filled(streams.length, false);

  var completedStreams = 0;

  controller = StreamController<List<T>>(
    onListen: () {
      for (var index = 0; index < streams.length; index++) {
        final currentIndex = index;

        subscriptions.add(
          streams[index].listen(
            (value) {
              values[currentIndex] = value;

              ready[currentIndex] = true;

              if (ready.every((item) => item) && !controller.isClosed) {
                controller.add(values.map((item) => item as T).toList());
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            },
            onDone: () {
              completedStreams++;

              if (completedStreams == streams.length && !controller.isClosed) {
                controller.close();
              }
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );

  return controller.stream;
}

Stream<T> _switchLatest<T>(Stream<Stream<T>> streams) {
  late StreamController<T> controller;

  StreamSubscription<Stream<T>>? outerSubscription;

  StreamSubscription<T>? innerSubscription;

  var generation = 0;
  var outerFinished = false;

  controller = StreamController<T>(
    onListen: () {
      outerSubscription = streams.listen(
        (stream) {
          final currentGeneration = ++generation;

          unawaited(innerSubscription?.cancel());

          innerSubscription = stream.listen(
            (value) {
              if (currentGeneration == generation && !controller.isClosed) {
                controller.add(value);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (currentGeneration == generation && !controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            },
            onDone: () {
              if (currentGeneration != generation) {
                return;
              }

              innerSubscription = null;

              if (outerFinished && !controller.isClosed) {
                controller.close();
              }
            },
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          outerFinished = true;

          if (innerSubscription == null && !controller.isClosed) {
            controller.close();
          }
        },
      );
    },
    onCancel: () async {
      generation++;

      await outerSubscription?.cancel();
      await innerSubscription?.cancel();
    },
  );

  return controller.stream;
}

class ProgressServiceException implements Exception {
  ProgressServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
