import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

const navy = Color(0xFF17243F);
const blue = Color(0xFF4263EB);
const muted = Color(0xFF7A8498);
const _canvas = Color(0xFFF8FAFD);
const _line = Color(0xFFE9EDF5);
const _blueTint = Color(0xFFEDF2FF);

void main() => runApp(const CASLMSPreviewApp());

class CASLMSPreviewApp extends StatelessWidget {
  const CASLMSPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CASLMS · Student workspace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: _canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: blue).copyWith(
          primary: blue,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: navy,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: navy, fontSize: 14, height: 1.5),
          bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        dividerColor: _line,
        dividerTheme: const DividerThemeData(color: _line, thickness: 1),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const StudentDashboardPreviewPage(),
    );
  }
}

const _courses = [
  CoursePreview(
    code: 'IT 310',
    title: 'Data Structures and Algorithms',
    category: 'COMPUTER SCIENCE',
    progress: .75,
    icon: Icons.data_object_rounded,
    color: Color(0xFF4263EB),
    tint: Color(0xFFEDF2FF),
  ),
  CoursePreview(
    code: 'IT 320',
    title: 'Web Technologies',
    category: 'WEB DEVELOPMENT',
    progress: .60,
    icon: Icons.language_rounded,
    color: Color(0xFF9472D4),
    tint: Color(0xFFF3EEFB),
  ),
  CoursePreview(
    code: 'IT 330',
    title: 'Mobile Development',
    category: 'APP DEVELOPMENT',
    progress: .40,
    icon: Icons.phone_iphone_rounded,
    color: Color(0xFF3B9685),
    tint: Color(0xFFEAF6F2),
  ),
];

const _assessments = [
  AssessmentPreview(
    title: 'Data Structures Quiz',
    course: 'IT 310',
    day: '25',
    month: 'OCT',
    due: 'Oct 25, 2026 · 9:00 AM',
    time: '9:00 AM',
    type: 'Quiz',
    color: blue,
    tint: _blueTint,
  ),
  AssessmentPreview(
    title: 'Web Development Activity',
    course: 'IT 320',
    day: '27',
    month: 'OCT',
    due: 'Oct 27, 2026 · 1:00 PM',
    time: '1:00 PM',
    type: 'Activity',
    color: Color(0xFF3B9685),
    tint: Color(0xFFEAF6F2),
  ),
];

const _destinations = [
  (Icons.space_dashboard_outlined, 'Overview'),
  (Icons.menu_book_outlined, 'Courses'),
  (Icons.notifications_none_rounded, 'Inbox'),
  (Icons.person_outline_rounded, 'Profile'),
];

class StudentDashboardPreviewPage extends StatefulWidget {
  const StudentDashboardPreviewPage({super.key});

  @override
  State<StudentDashboardPreviewPage> createState() =>
      _StudentDashboardPreviewPageState();
}

class _StudentDashboardPreviewPageState
    extends State<StudentDashboardPreviewPage> {
  int _selectedTab = 0;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _showDetails(String title, Widget content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Colors.white,
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          28,
          8,
          28,
          MediaQuery.paddingOf(context).bottom + 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 20),
            content,
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCourse(CoursePreview course) {
    _showDetails(
      course.title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(
            label: '${course.code} · Active course',
            color: course.color,
            background: course.tint,
          ),
          const SizedBox(height: 24),
          _CourseProgress(course: course),
          const SizedBox(height: 16),
          const Text(
            'Your course overview is ready. Lessons and course materials will appear here when they are available.',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }

  void _openAssessment(AssessmentPreview assessment) {
    _showDetails(
      assessment.title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(
            label: '${assessment.course} · ${assessment.type}',
            color: assessment.color,
            background: assessment.tint,
          ),
          const SizedBox(height: 20),
          Text(
            'Due ${assessment.due}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Review your course materials before the assessment. Instructions will be available in your course.',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final desktop = constraints.maxWidth >= 1100 && textScale <= 1.4;
        return Scaffold(
          extendBody: !desktop,
          bottomNavigationBar: desktop ? null : _buildBottomNavigation(),
          body: Row(
            children: [
              if (desktop) _buildSidebar(),
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final inset = constraints.maxWidth >= 800
                          ? 36.0
                          : constraints.maxWidth >= 600
                          ? 28.0
                          : 20.0;
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1450),
                          child: SingleChildScrollView(
                            key: const ValueKey('dashboard-scroll'),
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              inset,
                              24,
                              inset,
                              MediaQuery.paddingOf(context).bottom + 28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTopBar(desktop),
                                const SizedBox(height: 36),
                                if (_selectedTab == 0)
                                  _buildDashboard()
                                else if (_selectedTab == 1)
                                  _buildCoursesPage()
                                else if (_selectedTab == 2)
                                  _buildInboxPage()
                                else
                                  _buildProfilePage(),
                                const SizedBox(height: 32),
                                const Text(
                                  'A little progress, every day.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    letterSpacing: .3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      key: const ValueKey('desktop-sidebar'),
      width: 224,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _line)),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 56),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 10),
                          child: _Brand(),
                        ),
                        const SizedBox(height: 52),
                        const Padding(
                          padding: EdgeInsets.only(left: 14, bottom: 14),
                          child: _Eyebrow('WORKSPACE'),
                        ),
                        for (
                          var index = 0;
                          index < _destinations.length;
                          index++
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: _SidebarItem(
                              index: index,
                              selected: _selectedTab == index,
                              onTap: () => _selectTab(index),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _canvas,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_outlined,
                                  color: blue,
                                  size: 24,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Keep your curiosity.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Your next great idea starts with a little learning.',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () => _showDetails(
                                    'Your learning space',
                                    const Text(
                                      'Find your courses, review assessments, and keep track of your progress from one place. Select a course to see its overview.',
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Explore your workspace',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_outward_rounded,
                                          color: blue,
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: () => _selectTab(3),
                            borderRadius: BorderRadius.circular(12),
                            child: const Row(
                              children: [
                                _Avatar(size: 36),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rolando M.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Student account',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.unfold_more_rounded,
                                  color: muted,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(bool desktop) {
    return Row(
      children: [
        Expanded(
          child: desktop
              ? Row(
                  children: [
                    const Icon(Icons.home_outlined, size: 17, color: muted),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '/',
                        style: TextStyle(color: Color(0xFFCCD3DF)),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _destinations[_selectedTab].$2,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  ],
                )
              : const _Brand(compact: true),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .8),
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => _selectTab(2),
                    icon: const Badge(
                      smallSize: 7,
                      child: Icon(Icons.notifications_none_rounded, size: 21),
                    ),
                  ),
                  Container(height: 18, width: 1, color: _line),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: () => _showDetails(
                      'Student account',
                      const Text(
                        'This is a dashboard preview. There is no active sign-in session to end.',
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 19),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (desktop) ...[
          const SizedBox(width: 16),
          Tooltip(
            message: 'Your profile',
            child: InkWell(
              onTap: () => _selectTab(3),
              customBorder: const CircleBorder(),
              child: const _Avatar(size: 40),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageHeading(
          title: 'Hello, Rolando!',
          subtitle: 'A fresh start. A little focus. A step forward.',
          eyebrow: 'YOUR LEARNING SPACE',
        ),
        const SizedBox(height: 28),
        const _OverviewStats(),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final twoColumns = constraints.maxWidth >= 860 * textScale;
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LearningBanner(onContinue: () => _openCourse(_courses.first)),
                const SizedBox(height: 28),
                _SectionHeading(
                  title: 'My courses',
                  subtitle: 'Keep the momentum going.',
                  action: 'View all',
                  onAction: () => _selectTab(1),
                ),
                const SizedBox(height: 16),
                _buildCourseList(),
              ],
            );
            final side = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAssessments(),
                const SizedBox(height: 20),
                _buildAnnouncements(),
              ],
            );
            if (!twoColumns) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [main, const SizedBox(height: 28), side],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: main),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: side),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCourseList() => Column(
    children: [
      for (var index = 0; index < _courses.length; index++) ...[
        _CourseCard(
          course: _courses[index],
          onTap: () => _openCourse(_courses[index]),
        ),
        if (index < _courses.length - 1) const SizedBox(height: 12),
      ],
    ],
  );

  Widget _buildAssessments() {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'On your calendar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.calendar_today_outlined, color: muted, size: 19),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Your upcoming assessments',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 24),
          for (var index = 0; index < _assessments.length; index++) ...[
            _AssessmentTile(
              item: _assessments[index],
              onTap: () => _openAssessment(_assessments[index]),
            ),
            if (index < _assessments.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),
          ],
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showDetails(
              'Assessments',
              Column(
                children: [
                  for (final item in _assessments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _AssessmentTile(
                        item: item,
                        onTap: () {
                          Navigator.pop(context);
                          _openAssessment(item);
                        },
                      ),
                    ),
                ],
              ),
            ),
            label: const Text('View assessments'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            iconAlignment: IconAlignment.end,
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncements() {
    return _Surface(
      color: const Color(0xFFF0F4FC),
      borderColor: const Color(0xFFF0F4FC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'The noticeboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                  ),
                ),
              ),
              SizedBox(width: 8),
              _Pill(label: '2 new', color: blue, background: Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Stay in the loop.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Course updates and announcements, all in one place.',
            style: TextStyle(fontSize: 13, color: muted, height: 1.6),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _selectTab(2),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            label: const Text('Open your inbox'),
            icon: const Icon(Icons.arrow_outward_rounded, size: 15),
            iconAlignment: IconAlignment.end,
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _PageHeading(
        title: 'My courses',
        subtitle: 'Three subjects. Endless possibilities.',
        eyebrow: 'KEEP EXPLORING',
      ),
      const SizedBox(height: 28),
      _buildCourseList(),
      const SizedBox(height: 20),
      _backHome(),
    ],
  );

  Widget _buildInboxPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _PageHeading(
        title: 'Your inbox',
        subtitle: 'A little less noise. Everything you need to know.',
        eyebrow: 'STAY CONNECTED',
      ),
      const SizedBox(height: 28),
      _Surface(
        child: Column(
          children: [
            for (final entry in const [
              (
                Icons.menu_book_outlined,
                'Your courses are ready',
                'Find your three active courses in the Courses tab.',
              ),
              (
                Icons.campaign_outlined,
                'Your learning workspace',
                'Course updates and announcements will appear here.',
              ),
              (
                Icons.calendar_today_outlined,
                'Keep an eye on your calendar',
                'Review your two assessments and their due dates.',
              ),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconTile(
                      icon: entry.$1,
                      color: blue,
                      background: _blueTint,
                      size: 44,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.$2,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            entry.$3,
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _backHome(),
    ],
  );

  Widget _buildProfilePage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _PageHeading(
        title: 'Your profile',
        subtitle: 'Your own corner of the learning space.',
        eyebrow: 'NICE TO SEE YOU',
      ),
      const SizedBox(height: 28),
      const _Surface(
        child: Column(
          children: [
            _Avatar(size: 80),
            SizedBox(height: 20),
            Text(
              'Rolando Mabansag',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
              ),
            ),
            SizedBox(height: 8),
            Text('Student · CASLMS', style: TextStyle(color: muted)),
            SizedBox(height: 24),
            _Pill(
              label: '3 active courses',
              color: blue,
              background: _blueTint,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _backHome(),
    ],
  );

  Widget _backHome() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => _selectTab(0),
      icon: const Icon(Icons.arrow_back_rounded, size: 17),
      label: const Text('Back to Home'),
    ),
  );

  Widget _buildBottomNavigation() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                key: const ValueKey('mobile-navigation'),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < _destinations.length; index++)
                      Expanded(
                        child: Semantics(
                          selected: _selectedTab == index,
                          button: true,
                          label: _destinations[index].$2,
                          child: Tooltip(
                            message: _destinations[index].$2,
                            child: Material(
                              color: _selectedTab == index
                                  ? _blueTint
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                key: ValueKey('nav-$index'),
                                onTap: () => _selectTab(index),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  child: Icon(
                                    _destinations[index].$1,
                                    size: 23,
                                    color: _selectedTab == index ? blue : muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 32 : 36,
        height: compact ? 32 : 36,
        decoration: BoxDecoration(
          color: blue,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 21),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          'caslms',
          maxLines: 1,
          style: TextStyle(
            fontSize: compact ? 20 : 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
    ],
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xFFECE9E3),
      shape: BoxShape.circle,
    ),
    child: Text(
      'RM',
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        color: const Color(0xFF6D675E),
        fontSize: size * .31,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? _blueTint : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('nav-$index'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Icon(
                _destinations[index].$1,
                size: 20,
                color: selected ? blue : muted,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  _destinations[index].$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? blue : muted,
                  ),
                ),
              ),
              if (index == 2)
                Container(
                  width: 21,
                  height: 21,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : _canvas,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      fontSize: 10,
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
    required this.subtitle,
    required this.eyebrow,
  });
  final String title;
  final String subtitle;
  final String eyebrow;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Eyebrow(eyebrow),
      const SizedBox(height: 10),
      Text(
        title,
        style: TextStyle(
          fontSize: MediaQuery.sizeOf(context).width < 600 ? 30 : 35,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 10),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 14)),
    ],
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: muted,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.7,
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.color = Colors.white,
    this.borderColor = _line,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const stats = [
        (Icons.menu_book_outlined, '03', 'Active courses', blue, _blueTint),
        (
          Icons.event_note_outlined,
          '02',
          'Assessments',
          Color(0xFFB68A46),
          Color(0xFFFAF3E6),
        ),
        (
          Icons.task_alt_rounded,
          '01',
          'Pending task',
          Color(0xFF3B9685),
          Color(0xFFEAF6F2),
        ),
        (
          Icons.campaign_outlined,
          '02',
          'Announcements',
          Color(0xFF9472D4),
          Color(0xFFF3EEFB),
        ),
      ];
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= 760 * scale
          ? 4
          : constraints.maxWidth >= 260 * scale
          ? 2
          : 1;
      final gap = constraints.maxWidth < 600 ? 10.0 : 14.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final stat in stats)
            SizedBox(
              width: width,
              child: _Surface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _IconTile(
                          icon: stat.$1,
                          color: stat.$4,
                          background: stat.$5,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            stat.$2,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: width < 170 ? 36 : 18,
                      ),
                      child: Text(
                        stat.$3,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _LearningBanner extends StatelessWidget {
  const _LearningBanner({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final showArt = constraints.maxWidth >= 500 * textScale;
      return Container(
        padding: EdgeInsets.all(constraints.maxWidth < 400 ? 24 : 28),
        decoration: BoxDecoration(
          color: _blueTint,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PICK UP WHERE YOU LEFT OFF',
                    style: TextStyle(
                      color: blue,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Small steps.\nBig possibilities.',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your next idea is one lesson away.',
                    style: TextStyle(color: Color(0xFF6B7A9C), fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const ValueKey('continue-course'),
                    onPressed: onContinue,
                    label: const Text('Continue learning'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
            ),
            if (showArt) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 160,
                height: 190,
                child: RepaintBoundary(
                  child: CustomPaint(painter: _LearningArtwork()),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
        ],
      );
      final button = TextButton.icon(
        onPressed: onAction,
        label: Text(action),
        icon: const Icon(Icons.arrow_forward_rounded, size: 15),
        iconAlignment: IconAlignment.end,
      );
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      if (constraints.maxWidth < 280 * scale) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 8), button],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 12),
          button,
        ],
      );
    },
  );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});
  final CoursePreview course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final compact = constraints.maxWidth < 440 * scale;
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${course.code}  /  ${course.category}',
            style: TextStyle(
              color: course.color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            course.title,
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 16),
          _CourseProgress(course: course),
        ],
      );
      return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _line),
        ),
        child: InkWell(
          key: ValueKey('course-${course.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _IconTile(
                            icon: course.icon,
                            color: course.color,
                            background: course.tint,
                            size: 46,
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_outward_rounded,
                            size: 19,
                            color: muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      details,
                    ],
                  )
                : Row(
                    children: [
                      _IconTile(
                        icon: course.icon,
                        color: course.color,
                        background: course.tint,
                        size: 72,
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: details),
                      const SizedBox(width: 20),
                      const Icon(
                        Icons.arrow_outward_rounded,
                        size: 20,
                        color: muted,
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

class _CourseProgress extends StatelessWidget {
  const _CourseProgress({required this.course});
  final CoursePreview course;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: LinearProgressIndicator(
          value: course.progress,
          minHeight: 4,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: course.tint,
          color: course.color,
          semanticsLabel: '${course.title} progress',
        ),
      ),
      const SizedBox(width: 14),
      Text(
        '${(course.progress * 100).round()}%',
        style: const TextStyle(
          fontSize: 11,
          color: muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _AssessmentTile extends StatelessWidget {
  const _AssessmentTile({required this.item, required this.onTap});
  final AssessmentPreview item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: item.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                item.month,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: item.color,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .8,
                ),
              ),
              Text(
                item.day,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: item.color,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${item.course} · ${item.time}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(height: 9),
              _Pill(label: item.type, color: item.color, background: item.tint),
            ],
          ),
        ),
      ],
    ),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.size,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(size * .25),
    ),
    child: Icon(icon, color: color, size: size * .48),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.background,
  });
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
    ),
  );
}

// A small vector illustration: no images, background filters, or animation.
class _LearningArtwork extends CustomPainter {
  const _LearningArtwork();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 190);
    canvas.drawCircle(
      const Offset(84, 94),
      67,
      Paint()..color = const Color(0xFFE0E8FF),
    );
    canvas.drawCircle(
      const Offset(84, 94),
      79,
      Paint()
        ..color = const Color(0xFFD7E0F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.translate(80, 95);
    canvas.rotate(-.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-48, -50, 102, 115),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFFC1D0FA),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-55, -58, 102, 115),
        const Radius.circular(14),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-43, -43, 78, 49),
        const Radius.circular(8),
      ),
      Paint()..color = blue,
    );
    final pen = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(-19, -29)
        ..lineTo(-28, -20)
        ..lineTo(-19, -11),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(9, -29)
        ..lineTo(18, -20)
        ..lineTo(9, -11),
      pen,
    );
    canvas.drawLine(const Offset(0, -32), const Offset(-8, -8), pen);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-41, 19 + i * 10, i == 2 ? 38 : 68, 3),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFE5EAF6),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      const Offset(125, 139),
      21,
      Paint()..color = const Color(0xFF17243F),
    );
    canvas.drawPath(
      Path()
        ..moveTo(117, 139)
        ..lineTo(123, 145)
        ..lineTo(134, 133),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      const Offset(23, 40),
      5,
      Paint()..color = const Color(0xFFABC0FA),
    );
    final sparkle = Paint()
      ..color = blue
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(134, 29), const Offset(134, 41), sparkle);
    canvas.drawLine(const Offset(128, 35), const Offset(140, 35), sparkle);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LearningArtwork oldDelegate) => false;
}

class CoursePreview {
  const CoursePreview({
    required this.code,
    required this.title,
    required this.category,
    required this.progress,
    required this.icon,
    required this.color,
    required this.tint,
  });
  final String code;
  final String title;
  final String category;
  final double progress;
  final IconData icon;
  final Color color;
  final Color tint;
}

class AssessmentPreview {
  const AssessmentPreview({
    required this.title,
    required this.course,
    required this.day,
    required this.month,
    required this.due,
    required this.time,
    required this.type,
    required this.color,
    required this.tint,
  });
  final String title;
  final String course;
  final String day;
  final String month;
  final String due;
  final String time;
  final String type;
  final Color color;
  final Color tint;
}
