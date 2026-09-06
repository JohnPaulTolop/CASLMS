import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_ai_gateway_page.dart';
import 'admin_system_reports_page.dart';

class AdminDashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const AdminDashboardScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color adminTheme = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color green = Color(0xFF26A65B);
  static const Color red = Color(0xFFFF4B4B);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _errorMessage;

  String _adminName = 'Administrator';
  int _students = 0;
  int _instructors = 0;
  int _activeCourses = 0;
  int _restrictedAccounts = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No administrator is currently logged in.');
      }

      final adminDocument =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!adminDocument.exists || adminDocument.data() == null) {
        throw Exception('Administrator profile could not be found.');
      }

      final admin = adminDocument.data()!;
      final role = (admin['role'] ?? '').toString().trim().toLowerCase();
      final status = (admin['status'] ?? '').toString().trim().toLowerCase();

      if (role != 'admin' || status != 'active') {
        throw Exception(
          'This account does not have active administrator access.',
        );
      }

      final results = await Future.wait([
        _firestore.collection('users').get(),
        _firestore.collection('courses').get(),
      ]);

      final userSnapshot = results[0];
      final courseSnapshot = results[1];

      int students = 0;
      int instructors = 0;
      int restricted = 0;

      for (final document in userSnapshot.docs) {
        final data = document.data();
        final userRole = (data['role'] ?? '').toString().trim().toLowerCase();
        final userStatus =
            (data['status'] ?? 'active').toString().trim().toLowerCase();

        if (userStatus != 'active') {
          restricted++;
        }

        if (userRole == 'student' && userStatus == 'active') {
          students++;
        } else if (userRole == 'instructor' && userStatus == 'active') {
          instructors++;
        }
      }

      int activeCourses = 0;

      for (final document in courseSnapshot.docs) {
        final status =
            (document.data()['status'] ?? 'active').toString().trim().toLowerCase();

        if (status == 'active') {
          activeCourses++;
        }
      }

      if (!mounted) return;

      setState(() {
        _adminName = (admin['name'] ?? 'Administrator').toString().trim();
        if (_adminName.isEmpty) {
          _adminName = 'Administrator';
        }

        _students = students;
        _instructors = instructors;
        _activeCourses = activeCourses;
        _restrictedAccounts = restricted;
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            e.message ?? 'Unable to load administrator dashboard.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        elevation: 0,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Administration',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: textDark,
              ),
            ),
            Text(
              'Signed in as $_adminName',
              style: const TextStyle(
                fontSize: 12,
                color: textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadDashboard,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: textDark),
          ),
          IconButton(
            onPressed: () => widget.onNavigateToTab?.call(3),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_suggest_rounded, color: textDark),
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
      return const Center(
        child: CircularProgressIndicator(color: adminTheme),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: red, size: 50),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textGrey, height: 1.45),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: adminTheme,
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
      onRefresh: _loadDashboard,
      color: adminTheme,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthBanner(),
            const SizedBox(height: 24),
            _buildMetrics(),
            const SizedBox(height: 32),
            const Text(
              'Management Modules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 16),
            _buildAction(
              title: 'User Management',
              subtitle:
                  'Manage real Firebase accounts and Firestore user profiles.',
              icon: Icons.manage_accounts_rounded,
              color: adminTheme,
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
            _buildAction(
              title: 'Course Administration',
              subtitle:
                  'Manage live courses, instructors, and enrollment records.',
              icon: Icons.account_tree_rounded,
              color: Colors.orange,
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
            _buildAction(
              title: 'AI Service Gateway',
              subtitle:
                  'Monitor real learning-material AI processing activity.',
              icon: Icons.memory_rounded,
              color: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAIGatewayScreen(),
                  ),
                );
              },
            ),
            _buildAction(
              title: 'System Reports',
              subtitle:
                  'View real platform metrics and activity reports.',
              icon: Icons.analytics_rounded,
              color: Colors.redAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminSystemReportsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_rounded, color: green, size: 20),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Firebase Authentication and Cloud Firestore are responding.',
              style: TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'LIVE',
            style: TextStyle(
              color: green,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    final cards = [
      _metric('Active Students', _students, Icons.groups_rounded, Colors.blue),
      _metric('Instructors', _instructors, Icons.badge_rounded, Colors.teal),
      _metric(
        'Active Courses',
        _activeCourses,
        Icons.library_books_rounded,
        adminTheme,
      ),
      _metric(
        'Restricted Accounts',
        _restrictedAccounts,
        Icons.block_rounded,
        Colors.redAccent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 520
                ? 2
                : 1;

        const spacing = 14.0;
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
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 9),
          Text(
            '$value',
            style: const TextStyle(
              color: textDark,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textGrey,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: textGrey,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: textGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
