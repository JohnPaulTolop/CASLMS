import '../../core/app_colors.dart';

import 'package:flutter/material.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  // ============================================================
  // CASLMS DESIGN SYSTEM
  // ============================================================
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color background = AppColors.background;
  static const Color textDark = AppColors.darkText;
  static const Color textGrey = AppColors.secondaryText;

  static const Color orange = AppColors.amber;
  static const Color green = AppColors.green;

  int _selectedTab = 0; // 0: To Do, 1: Submitted, 2: Completed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'My Tasks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined, color: textDark),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // Expanded to 1200px for wide desktop monitors
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // ----------------------------------------------------
                // SEGMENTED TABS
                // ----------------------------------------------------
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                  ), // Keeps tabs neat and compact on wide screens
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEFF3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildSegmentTab('To Do (3)', 0)),
                      Expanded(child: _buildSegmentTab('Submitted', 1)),
                      Expanded(child: _buildSegmentTab('Completed', 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ----------------------------------------------------
                // TASK LIST CONTENT
                // ----------------------------------------------------
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    children: _buildTaskListContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // UI COMPONENTS
  // ==============================================================

  Widget _buildSegmentTab(String title, int index) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? textDark : textGrey,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTaskListContent() {
    if (_selectedTab == 0) {
      // TO DO TAB
      return [
        _buildTaskCard(
          title: 'Activity 3: Firebase Auth Login',
          subtitle: 'Mobile Development • Due Tomorrow',
          badgeText: 'Due Soon',
          badgeColor: orange,
          icon: Icons.code_rounded,
        ),
        _buildTaskCard(
          title: 'Chapter 1 Defense Proposal',
          subtitle: 'IT Capstone Project 1 • Due Friday',
          badgeText: 'Due This Week',
          badgeColor: primaryBlue,
          icon: Icons.description_outlined,
        ),
        _buildTaskCard(
          title: 'Quiz 2: Auth Concepts',
          subtitle: 'Mobile Development • Due Next Monday',
          badgeText: 'Online Quiz',
          badgeColor: textGrey,
          icon: Icons.quiz_rounded,
        ),
      ];
    } else if (_selectedTab == 1) {
      // SUBMITTED TAB
      return [
        _buildTaskCard(
          title: 'Activity 1: UI Wireframes',
          subtitle: 'Mobile Development • Submitted May 18',
          badgeText: 'Under Review',
          badgeColor: orange,
          icon: Icons.assignment_turned_in_rounded,
        ),
      ];
    } else {
      // COMPLETED TAB
      return [
        _buildTaskCard(
          title: 'Midterm Project: Inventory App',
          subtitle: 'System Integration • Graded 95/100',
          badgeText: 'Completed',
          badgeColor: green,
          icon: Icons.check_circle_rounded,
        ),
        _buildTaskCard(
          title: 'Quiz 1: Android Basics',
          subtitle: 'Mobile Development • Graded 100/100',
          badgeText: 'Completed',
          badgeColor: green,
          icon: Icons.check_circle_rounded,
        ),
      ];
    }
  }

  Widget _buildTaskCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
  }) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: textGrey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        badgeText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final iconTile = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: primaryBlue, size: 24),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [iconTile, const Spacer(), badge]),
                const SizedBox(height: 14),
                details,
              ],
            );
          }
          return Row(
            children: [
              iconTile,
              const SizedBox(width: 16),
              Expanded(child: details),
              const SizedBox(width: 12),
              badge,
            ],
          );
        },
      ),
    );
  }
}
