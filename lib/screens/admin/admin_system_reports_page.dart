import '../shared/page_loading_state.dart';
import '../../core/app_colors.dart';
import '../../models/admin_records.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';
import 'admin_download.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSystemReportsScreen extends StatefulWidget {
  const AdminSystemReportsScreen({super.key});

  @override
  State<AdminSystemReportsScreen> createState() =>
      _AdminSystemReportsScreenState();
}

class _AdminSystemReportsScreenState extends State<AdminSystemReportsScreen> {
  Color get adminTheme => AppColors.resolve(context, AppColors.primaryBlue);
  Color get reportRed => AppColors.resolve(context, AppColors.error);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);
  Color get surface => AppColors.resolve(context, Colors.white);
  Color get green => AppColors.resolve(context, AppColors.green);
  Color get blue => AppColors.resolve(context, AppColors.primaryBlue);
  Color get orange => AppColors.resolve(context, AppColors.amber);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedTimeframe = 'All Time';

  final List<String> _timeframeOptions = const [
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'All Time',
  ];

  int _users = 0;
  int _activeCourses = 0;
  int _activeEnrollments = 0;
  int _assessmentSubmissions = 0;
  int _moduleProgressRecords = 0;
  int _aiReady = 0;
  int _aiFailed = 0;

  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final usersSnapshot = await _firestore.collection('users').get();

      final coursesSnapshot = await _firestore.collection('courses').get();

      final enrollmentSnapshot = await _firestore
          .collection('enrollments')
          .get();

      final submissionSnapshot = await _firestore
          .collection('assessmentSubmissions')
          .get();

      final progressSnapshot = await _firestore
          .collection('moduleProgress')
          .get();

      final resourceSnapshot = await _firestore
          .collection('moduleResources')
          .get();

      int activeCourses = 0;

      for (final document in coursesSnapshot.docs) {
        final status = (document.data()['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

        if (status == 'active') {
          activeCourses++;
        }
      }

      int activeEnrollments = 0;

      for (final document in enrollmentSnapshot.docs) {
        final status = (document.data()['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status == 'active') {
          activeEnrollments++;
        }
      }

      int aiReady = 0;
      int aiFailed = 0;

      final List<Map<String, dynamic>> activities = [];

      for (final document in coursesSnapshot.docs) {
        final data = document.data();

        final timestamp = data['createdAt'];

        if (timestamp != null) {
          activities.add({
            'type': 'Course',
            'title': '${(data['code'] ?? 'Course')} • ${(data['title'] ?? '')}',
            'subtitle': 'Current course record - created',
            'timestamp': timestamp,
            'color': Colors.indigo,
            'icon': Icons.library_books_rounded,
          });
        }
      }

      for (final document in resourceSnapshot.docs) {
        final data = document.data();

        final status = (data['aiProcessingStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status == 'ready') {
          aiReady++;
        } else if (status == 'failed') {
          aiFailed++;
        }

        final timestamp = data['aiProcessedAt'] ?? data['updatedAt'];

        if (status.isNotEmpty && timestamp != null) {
          activities.add({
            'type': 'AI',
            'title': (data['fileName'] ?? data['title'] ?? 'Learning Material')
                .toString(),
            'subtitle': 'AI status: ${_capitalize(status)}',
            'timestamp': timestamp,
            'color': status == 'ready'
                ? green
                : status == 'failed'
                ? reportRed
                : orange,
            'icon': Icons.auto_awesome_rounded,
          });
        }
      }

      activities.sort((a, b) {
        final aDate = _dateFrom(a['timestamp']);
        final bDate = _dateFrom(b['timestamp']);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _users = usersSnapshot.size;
        _activeCourses = activeCourses;
        _activeEnrollments = activeEnrollments;
        _assessmentSubmissions = submissionSnapshot.size;
        _moduleProgressRecords = progressSnapshot.size;
        _aiReady = aiReady;
        _aiFailed = aiFailed;
        _activities = activities;
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Unable to load system report.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredActivities {
    final now = DateTime.now();
    DateTime? cutoff;

    if (_selectedTimeframe == 'Today') {
      cutoff = DateTime(now.year, now.month, now.day);
    } else if (_selectedTimeframe == 'Last 7 Days') {
      cutoff = now.subtract(const Duration(days: 7));
    } else if (_selectedTimeframe == 'Last 30 Days') {
      cutoff = now.subtract(const Duration(days: 30));
    }

    if (cutoff == null) {
      return _activities.take(50).toList();
    }

    return _activities
        .where((item) {
          final date = _dateFrom(item['timestamp']);

          return date != null && !date.toLocal().isBefore(cutoff!);
        })
        .take(50)
        .toList();
  }

  Future<void> _exportReport() async {
    try {
      await downloadAdminCsv(
        adminCsv([
          ['CASLMS System Report'],
          ['Record snapshot timeframe', _selectedTimeframe],
          [
            'Metrics describe current records; timeframe applies to snapshots below.',
          ],
          ['Metric', 'Value'],
          ['Users', _users],
          ['Active courses', _activeCourses],
          ['Active enrollments', _activeEnrollments],
          ['Assessment submissions', _assessmentSubmissions],
          ['Module progress records', _moduleProgressRecords],
          ['AI ready', _aiReady],
          ['AI failed', _aiFailed],
          [],
          ['Record type', 'Title', 'Details', 'Timestamp'],
          ..._filteredActivities.map(
            (item) => [
              item['type'],
              item['title'],
              item['subtitle'],
              _formatAbsoluteDate(item['timestamp']),
            ],
          ),
        ]),
        'caslms-system-report.csv',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to download report. Please retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PageLoadingState();
    final double inset = workspaceInset(MediaQuery.sizeOf(context).width);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: WorkspaceScrollingBody(
              header: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 0),
                    child: WorkspaceHeading(
                      showEyebrow: false,
                      title: 'System reports',
                      subtitle: 'Current platform metrics, system activity, and real-time audit logs.',
                      eyebrow: 'ADMINISTRATION',
                      actions: [
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _exportReport,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download CSV'),
                        ),
                        IconButton(
                          onPressed: _isLoading ? null : _loadReport,
                          tooltip: 'Refresh',
                          icon: Icon(Icons.refresh_rounded, color: textDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              body: _buildBody(inset),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double inset) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: blue));
    }

    if (_errorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: WorkspaceErrorState(
          message: _errorMessage!,
          onRetry: _loadReport,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      color: blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 40),
        children: [
          Text(
            'Metrics describe current records. The timeframe filters the record snapshots below; open Activity logs for session history.',
            style: TextStyle(color: textGrey, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          _buildTimeframeSelector(),
          const SizedBox(height: 20),
          _buildMetrics(),
          const SizedBox(height: 32),
          const WorkspaceSectionHeading(
            title: 'Current record snapshots',
            subtitle: 'Recent courses created and learning material updates across the platform.',
          ),
          const SizedBox(height: 14),
          if (_filteredActivities.isEmpty)
            const WorkspaceEmptyState(
              title: 'No record snapshots',
              message: 'No matching record snapshots found for this timeframe.',
              icon: Icons.analytics_outlined,
            )
          else
            ..._filteredActivities.map(_buildActivityCard),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _timeframeOptions.map((timeframe) {
          final isSelected = _selectedTimeframe == timeframe;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(timeframe),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedTimeframe = timeframe);
                }
              },
              selectedColor: blue.withValues(alpha: 0.16),
              backgroundColor: surface,
              labelStyle: TextStyle(
                color: isSelected ? blue : textGrey,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? blue : borderColor),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetrics() {
    final cards = [
      _metric('Users', _users, Icons.groups_rounded, blue),
      _metric(
        'Active Courses',
        _activeCourses,
        Icons.library_books_rounded,
        Colors.indigo,
      ),
      _metric(
        'Enrollments',
        _activeEnrollments,
        Icons.how_to_reg_rounded,
        green,
      ),
      _metric(
        'Submissions',
        _assessmentSubmissions,
        Icons.assignment_turned_in_outlined,
        orange,
      ),
      _metric(
        'Progress Records',
        _moduleProgressRecords,
        Icons.trending_up_rounded,
        Colors.teal,
      ),
      _metric(
        'AI Ready',
        _aiReady,
        Icons.auto_awesome_rounded,
        Colors.deepPurple,
      ),
      _metric('AI Failed', _aiFailed, Icons.error_outline_rounded, reportRed),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;

        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _metric(String label, int value, IconData icon, Color color) {
    return WorkspaceSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          WorkspaceIconTile(
            icon: icon,
            color: color,
            background: color.withValues(alpha: 0.12),
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> item) {
    final color = item['color'] is Color ? item['color'] as Color : textGrey;

    final icon = item['icon'] is IconData
        ? item['icon'] as IconData
        : Icons.info_outline_rounded;
    final relativeTime = _formatRelative(item['timestamp']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WorkspaceSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            WorkspaceIconTile(
              icon: icon,
              color: color,
              background: color.withValues(alpha: 0.10),
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['title'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (item['subtitle'] ?? '').toString(),
                    style: TextStyle(color: textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (relativeTime.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  relativeTime,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatRelative(dynamic value) {
    final date = _dateFrom(value);

    if (date == null) return '';

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inMinutes < 1) return 'Now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    return '${difference.inDays}d';
  }

  String _formatAbsoluteDate(dynamic value) {
    final date = _dateFrom(value);

    if (date == null) return '';

    final local = date.toLocal();

    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _capitalize(String value) {
    final clean = value.trim();

    if (clean.isEmpty) return clean;

    return '${clean[0].toUpperCase()}${clean.substring(1)}';
  }
}
