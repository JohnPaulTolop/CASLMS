import 'package:flutter/material.dart';

class InstructorAnalyticsScreen extends StatelessWidget {
  const InstructorAnalyticsScreen({super.key});

  // ============================================================
  // CASLMS DESIGN SYSTEM (Instructor Teal Palette)
  // ============================================================
  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  
  static const Color blue = Color(0xFF1769FF);
  static const Color orange = Color(0xFFFF9418);
  static const Color red = Color(0xFFFF4B4B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      
      // ==================================================
      // STANDARDIZED HEADER
      // ==================================================
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Cohort Analytics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined, color: textDark),
              tooltip: 'Export Report',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Exporting CSV report...'),
                    backgroundColor: primaryTeal,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // Expanded to 1200 for wide desktop browsers to match other screens
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // CLASS SELECTOR DROPDOWN
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE6EAF0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: 'Mobile Development - BSIT 3A',
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryTeal),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: textDark, fontSize: 14),
                        items: <String>[
                          'Mobile Development - BSIT 3A',
                          'IT Capstone Project 1 - BSIT 4B',
                          'System Integration - BSIT 3C'
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ==================================================
                  // OVERVIEW STATS
                  // ==================================================
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Class Average', '82%', Icons.grading_rounded, blue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Active Today', '38/45', Icons.people_alt_rounded, primaryTeal)),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ==================================================
                  // AT-RISK AI ALERT
                  // ==================================================
                  const Text(
                    'Requires Attention',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 14),
                  _buildAtRiskCard(),
                  const SizedBox(height: 28),

                  // ==================================================
                  // MODULE ENGAGEMENT CHART
                  // ==================================================
                  const Text(
                    'Module Engagement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 14),
                  _buildEngagementChart(primaryTeal),
                  const SizedBox(height: 28),

                  // ==================================================
                  // TOPIC COMPREHENSION
                  // ==================================================
                  const Text(
                    'Weakest Topics (Based on Quizzes)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 14),
                  _buildTopicWeaknessItem('Firebase Security Rules', 45, red),
                  _buildTopicWeaknessItem('Complex SQL Joins', 58, orange),
                  _buildTopicWeaknessItem('State Management', 65, const Color(0xFFD6A000)),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // UI COMPONENTS
  // ==============================================================

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value, 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildAtRiskCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: red.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_rounded, color: red, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI flagged 2 students who may be falling behind in the current module.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
          ),
          _buildAtRiskStudent('John M.', 'Inactive for 5 days. Missed Quiz 2.'),
          const SizedBox(height: 12),
          _buildAtRiskStudent('Sarah L.', 'Failed 3 compilation checks on Activity 3.'),
        ],
      ),
    );
  }

  Widget _buildAtRiskStudent(String name, String reason) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: const Color(0xFFE6EAF0),
          child: Text(
            name[0], 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name, 
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: textDark),
              ),
              const SizedBox(height: 2),
              Text(
                reason, 
                style: const TextStyle(fontSize: 11.5, color: red, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: blue.withValues(alpha: 0.1),
            foregroundColor: blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Message', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        )
      ],
    );
  }

  Widget _buildEngagementChart(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEngagementBar('Mod 1: Intro', 0.98, themeColor),
          const SizedBox(height: 16),
          _buildEngagementBar('Mod 2: Layouts', 0.85, themeColor),
          const SizedBox(height: 16),
          _buildEngagementBar('Mod 3: Nav', 0.72, themeColor),
          const SizedBox(height: 16),
          _buildEngagementBar('Mod 4: State', 0.45, orange),
        ],
      ),
    );
  }

  Widget _buildEngagementBar(String label, double completion, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label, 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textDark),
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completion,
              backgroundColor: const Color(0xFFECEFF4),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '${(completion * 100).toInt()}%', 
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color), 
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildTopicWeaknessItem(String title, int averageScore, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: color, size: 18),
              const SizedBox(width: 12),
              Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textDark),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), 
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Avg: $averageScore%', 
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}