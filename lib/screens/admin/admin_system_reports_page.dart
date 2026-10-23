import '../../models/admin_records.dart';
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
  static const Color reportRed = Color(0xFFFF4B4B);
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color green = Color(0xFF26A65B);
  static const Color blue = Color(0xFF1769FF);
  static const Color orange = Color(0xFFFF9418);

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
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: textDark,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Reports',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Current platform metrics',
              style: TextStyle(
                fontSize: 12,
                color: textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _exportReport,
            tooltip: 'Download CSV',
            icon: const Icon(Icons.file_download_outlined, color: reportRed),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadReport,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: reportRed));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: reportRed,
                size: 50,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textGrey, height: 1.45),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: reportRed,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      color: reportRed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          const Text(
            'Metrics describe current records. The timeframe filters the record snapshots below; open Activity logs for session history.',
            style: TextStyle(color: textGrey, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          _buildTimeframeSelector(),
          const SizedBox(height: 18),
          _buildMetrics(),
          const SizedBox(height: 28),
          const Text(
            'Current record snapshots',
            style: TextStyle(
              color: textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (_filteredActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No matching record snapshots for this timeframe.',
                  style: TextStyle(color: textGrey),
                ),
              ),
            )
          else
            ..._filteredActivities.map(_buildActivityCard),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimeframe,
          isExpanded: true,
          items: _timeframeOptions.map((value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedTimeframe = value;
            });
          },
        ),
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
        final columns = constraints.maxWidth >= 850
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['title'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  (item['subtitle'] ?? '').toString(),
                  style: const TextStyle(color: textGrey, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatRelative(item['timestamp']),
            style: const TextStyle(color: textGrey, fontSize: 9.5),
          ),
        ],
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
