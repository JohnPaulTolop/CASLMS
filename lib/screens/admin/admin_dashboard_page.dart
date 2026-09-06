import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_ai_gateway_page.dart';
import 'admin_system_reports_page.dart';

class AdminDashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const AdminDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color adminTheme = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
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

      final adminDocument = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

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
        final userStatus = (data['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

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
        final status = (document.data()['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

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
        _errorMessage = e.message ?? 'Unable to load administrator dashboard.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
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
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                image: const DecorationImage(
                  image: AssetImage('assets/images/CASlogo.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CASLMS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    color: adminTheme,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'ADMIN PORTAL',
                  style: TextStyle(
                    fontSize: 9,
                    color: textGrey,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _loadDashboard,
              tooltip: 'Refresh dashboard',
              icon: const Icon(
                Icons.refresh_rounded,
                color: textDark,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: adminTheme.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => widget.onNavigateToTab?.call(3),
              tooltip: 'Settings',
              icon: const Icon(
                Icons.settings_suggest_rounded,
                color: adminTheme,
                size: 21,
              ),
            ),
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
      return const Center(child: CircularProgressIndicator(color: adminTheme));
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 800 ? 32.0 : 20.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeBanner(),
                  const SizedBox(height: 26),
                  _buildSectionTitle(
                    'Platform overview',
                    'Live totals across your learning environment',
                  ),
                  const SizedBox(height: 14),
                  _buildMetrics(),
                  const SizedBox(height: 30),
                  _buildSectionTitle(
                    'Management center',
                    'Open an area to manage the platform',
                  ),
                  const SizedBox(height: 14),
                  _buildManagementGrid(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: adminTheme.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -36,
            top: -58,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 62,
            bottom: -78,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $_adminName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Monitor users, courses, reports, and system services from one place.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            color: Color(0xFF9FF0BC),
                            size: 16,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Firebase services online',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: textDark,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            color: textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildManagementGrid() {
    final actions = [
      _buildAction(
        title: 'User Management',
        subtitle: 'Review accounts, roles, access, and instructor approvals.',
        icon: Icons.manage_accounts_rounded,
        color: adminTheme,
        onTap: () => widget.onNavigateToTab?.call(1),
      ),
      _buildAction(
        title: 'Course Administration',
        subtitle: 'Manage courses, instructors, and enrollment records.',
        icon: Icons.account_tree_rounded,
        color: Colors.orange,
        onTap: () => widget.onNavigateToTab?.call(2),
      ),
      _buildAction(
        title: 'AI Service Gateway',
        subtitle: 'Monitor learning-material AI processing activity.',
        icon: Icons.memory_rounded,
        color: Colors.deepPurple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAIGatewayScreen()),
          );
        },
      ),
      _buildAction(
        title: 'System Reports',
        subtitle: 'View platform metrics and operational reports.',
        icon: Icons.analytics_rounded,
        color: Colors.redAccent,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminSystemReportsScreen()),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        const spacing = 14.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map((action) => SizedBox(width: itemWidth, child: action))
              .toList(),
        );
      },
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                const Icon(Icons.chevron_right_rounded, color: textGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
