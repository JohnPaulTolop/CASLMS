typedef ProgressRow = Map<String, dynamic>;

class ProgressCalculator {
  static String text(dynamic value) =>
      (value ?? '').toString().trim();

  static String lower(dynamic value) =>
      text(value).toLowerCase();

  static double ratio(num value, num total) {
    if (total <= 0) {
      return 0;
    }

    return (value / total)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static int _time(ProgressRow row) {
    for (final key in [
      'gradedAt',
      'submittedAt',
      'updatedAt',
    ]) {
      final value = row[key];

      if (value is int) {
        return value;
      }

      if (value is DateTime) {
        return value.millisecondsSinceEpoch;
      }
    }

    return 0;
  }

  static num? _total(
    ProgressRow result,
    ProgressRow task,
  ) {
    final value =
        result['totalPoints'] ??
        task['totalPoints'] ??
        task['points'];

    if (value is num &&
        value.isFinite &&
        value > 0) {
      return value;
    }

    return null;
  }

  static bool _scored(
    ProgressRow result,
    ProgressRow task,
    String source,
  ) {
    final status = lower(
      result['status'],
    );

    final eligible =
        status == 'graded' ||
        (source == 'quiz' &&
            status == 'submitted');

    final score = result['score'];
    final total = _total(
      result,
      task,
    );

    return eligible &&
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
    required List<ProgressRow>
        assessmentSubmissions,
    required List<ProgressRow>
        assignmentSubmissions,
    required List<ProgressRow> quizAttempts,
  }) {
    final courseId = text(
      course['id'],
    );

    final publishedModules = modules.where(
      (module) {
        return text(module['courseId']) ==
                courseId &&
            lower(module['status']) ==
                'published';
      },
    ).toList();

    final moduleIds = publishedModules
        .map((module) => text(module['id']))
        .toSet();

    final modernAssessmentIds = assessments
        .map((assessment) =>
            text(assessment['id']))
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
        if (text(task['courseId']) !=
            courseId) {
          continue;
        }

        // Do not count a legacy task again if it is
        // connected to a modern assessment.
        if (source != 'assessment' &&
            modernAssessmentIds.contains(
              text(task['assessmentId']),
            )) {
          continue;
        }

        final taskStatus = lower(
          task['status'],
        );

        final isAvailable =
            taskStatus == 'published' ||
            (source == 'assessment' &&
                taskStatus == 'closed');

        if (!isAvailable) {
          continue;
        }

        final taskId = text(
          task['id'],
        );

        final isQuiz =
            source == 'quiz' ||
            lower(task['assessmentType']) ==
                'quiz';

        final matches = results.where(
          (result) {
            return text(result['courseId']) ==
                    courseId &&
                text(result[parentKey]) ==
                    taskId;
          },
        ).toList();

        matches.sort(
          (a, b) {
            final order =
                _time(b).compareTo(_time(a));

            if (order != 0) {
              return order;
            }

            return text(a['id']).compareTo(
              text(b['id']),
            );
          },
        );

        ProgressRow? grade;

        for (final result in matches) {
          if (_scored(
            result,
            task,
            source,
          )) {
            grade = result;
            break;
          }
        }

        if (grade != null) {
          final score =
              grade['score'] as num;

          final total = _total(
            grade,
            task,
          )!;

          if (isQuiz) {
            quizEarned += score;
            quizAvailable += total;
            gradedQuizzes++;

            final passingScore =
                task['passingScore'];

            if (passingScore is! num ||
                score >= passingScore) {
              passedQuizzes++;
            }
          } else {
            assignmentEarned += score;
            assignmentAvailable += total;
            gradedAssignments++;
          }
        }

        final moduleId = text(
          task['moduleId'],
        );

        // Tasks belonging to unpublished modules
        // are not counted toward module progress.
        if (moduleId.isNotEmpty &&
            !moduleIds.contains(moduleId)) {
          continue;
        }

        final submittedAssignment =
            source == 'assignment' &&
            matches.any(
              (result) {
                final status = lower(
                  result['status'],
                );

                return [
                      'submitted',
                      'graded',
                    ].contains(status) &&
                    result['submittedAt'] !=
                        null &&
                    (
                      text(result['answerText'])
                              .isNotEmpty ||
                          text(result['fileUrl'])
                              .isNotEmpty
                    );
              },
            );

        // An external website cannot be independently
        // verified on Spark. Its recorded submission is
        // the available completion signal.
        final submittedExternalAssessment =
            source == 'assessment' &&
            lower(task['deliveryType']) !=
                'ai_generated' &&
            matches.any(
              (result) {
                final status = lower(
                  result['status'],
                );

                return [
                      'submitted',
                      'graded',
                    ].contains(status) &&
                    result['submittedAt'] !=
                        null;
              },
            );

        final inProgress = matches.any(
          (result) =>
              lower(result['status']) ==
              'in_progress',
        );

        tasks.add({
          'id': '$source:$taskId',
          'title': text(task['title']),
          'moduleId': moduleId,
          'isQuiz': isQuiz,
          'completed':
              grade != null ||
              submittedAssignment ||
              submittedExternalAssessment,
          'inProgress': inProgress,
          'graded': grade != null,
        });
      }
    }

    addTasks(
      assessments,
      assessmentSubmissions,
      'assessment',
      'assessmentId',
    );

    addTasks(
      assignments,
      assignmentSubmissions,
      'assignment',
      'assignmentId',
    );

    addTasks(
      quizzes,
      quizAttempts,
      'quiz',
      'quizId',
    );

    final moduleReports =
        publishedModules.map(
      (module) {
        final linkedTasks = tasks.where(
          (task) {
            return text(task['moduleId']) ==
                text(module['id']);
          },
        ).toList();

        final completedTasks =
            linkedTasks.where(
          (task) =>
              task['completed'] == true,
        ).length;

        return <String, dynamic>{
          ...module,
          'moduleId': module['id'],
          'totalTasks': linkedTasks.length,
          'completedTasks': completedTasks,
          'taskProgress': ratio(
            completedTasks,
            linkedTasks.length,
          ),

          // An empty module is not automatically
          // considered completed.
          'completed':
              linkedTasks.isNotEmpty &&
              completedTasks ==
                  linkedTasks.length,
        };
      },
    ).toList();

    moduleReports.sort(
      (a, b) {
        final orderA =
            (a['order'] as num?) ?? 0;

        final orderB =
            (b['order'] as num?) ?? 0;

        return orderA.compareTo(orderB);
      },
    );

    final completedModules =
        moduleReports.where(
      (module) =>
          module['completed'] == true,
    ).length;

    final completedTasks = tasks.where(
      (task) =>
          task['completed'] == true,
    ).length;

    final quizTasks = tasks.where(
      (task) =>
          task['isQuiz'] == true,
    ).toList();

    final assignmentTasks = tasks.where(
      (task) =>
          task['isQuiz'] != true,
    ).toList();

    final completedQuizzes =
        quizTasks.where(
      (task) =>
          task['completed'] == true,
    ).length;

    final inProgressQuizzes =
        quizTasks.where(
      (task) =>
          task['completed'] != true &&
          task['inProgress'] == true,
    ).length;

    final completedAssignments =
        assignmentTasks.where(
      (task) =>
          task['completed'] == true,
    ).length;

    final earnedPoints =
        quizEarned + assignmentEarned;

    final availablePoints =
        quizAvailable +
        assignmentAvailable;

    return {
      ...course,
      'courseId': courseId,
      'modules': moduleReports,
      'tasks': tasks,

      'totalModules': moduleReports.length,
      'completedModules':
          completedModules,
      'remainingModules':
          moduleReports.length -
          completedModules,
      'moduleProgress': ratio(
        completedModules,
        moduleReports.length,
      ),
      'progress': ratio(
        completedModules,
        moduleReports.length,
      ),

      'totalItems': tasks.length,
      'completedItems': completedTasks,
      'remainingItems':
          tasks.length - completedTasks,
      'learningProgress': ratio(
        completedTasks,
        tasks.length,
      ),

      'totalQuizzes': quizTasks.length,
      'completedQuizzes':
          completedQuizzes,
      'inProgressQuizzes':
          inProgressQuizzes,
      'passedQuizzes': passedQuizzes,
      'remainingQuizzes':
          quizTasks.length -
          completedQuizzes,
      'quizProgress': ratio(
        completedQuizzes,
        quizTasks.length,
      ),

      'totalAssignments':
          assignmentTasks.length,
      'submittedAssignments':
          completedAssignments,
      'remainingAssignments':
          assignmentTasks.length -
          completedAssignments,
      'assignmentProgress': ratio(
        completedAssignments,
        assignmentTasks.length,
      ),

      'gradedAssignments':
          gradedAssignments,
      'gradedQuizzes': gradedQuizzes,
      'gradedItems':
          gradedAssignments +
          gradedQuizzes,

      'quizEarnedPoints': quizEarned,
      'quizAvailablePoints':
          quizAvailable,
      'quizPercentage': ratio(
        quizEarned,
        quizAvailable,
      ),

      'assignmentEarnedPoints':
          assignmentEarned,
      'assignmentAvailablePoints':
          assignmentAvailable,
      'assignmentPercentage': ratio(
        assignmentEarned,
        assignmentAvailable,
      ),

      'earnedPoints': earnedPoints,
      'availablePoints': availablePoints,
      'percentage': ratio(
        earnedPoints,
        availablePoints,
      ),
      'hasGrades':
          availablePoints > 0,

      'academicPerformance': ratio(
        earnedPoints,
        availablePoints,
      ),
      'academicEarnedPoints':
          earnedPoints,
      'academicAvailablePoints':
          availablePoints,
    };
  }

  static ProgressRow overall(
    List<ProgressRow> courses,
  ) {
    num sum(String key) {
      return courses.fold<num>(
        0,
        (total, course) =>
            total +
            ((course[key] as num?) ?? 0),
      );
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
      'remainingQuizzes',
      'inProgressQuizzes',
      'passedQuizzes',
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
      'moduleProgress': ratio(
        sum('completedModules'),
        sum('totalModules'),
      ),
      'progress': ratio(
        sum('completedModules'),
        sum('totalModules'),
      ),
      'learningProgress': ratio(
        sum('completedItems'),
        sum('totalItems'),
      ),
      'quizProgress': ratio(
        sum('completedQuizzes'),
        sum('totalQuizzes'),
      ),
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
      'percentage': ratio(
        sum('earnedPoints'),
        sum('availablePoints'),
      ),
      'hasGrades':
          sum('availablePoints') > 0,
    });

    return result;
  }
}