import 'package:flutter/material.dart';
import 'admin_ai_gateway_page.dart'; // Adjust import to match your file name
import 'admin_system_reports_page.dart'; // Adjust import to match your file name

class AdminDashboardScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const AdminDashboardScreen({Key? key, this.onNavigateToTab}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color adminTheme = Colors.indigo.shade600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 24.0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'System Administration',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87, letterSpacing: -0.5),
              ),
              Text(
                'CASLMS Core Management',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_suggest_rounded, color: Colors.black87),
              onPressed: () => onNavigateToTab?.call(3), // Jumps to Settings Tab
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- System Health & Connection Banner ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Text('Moodle API Connected', style: TextStyle(color: Colors.green[800], fontSize: 12, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('Ping: 24ms', style: TextStyle(color: Colors.green[700], fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- High-Level Metrics ---
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('Total Students', '3,412', Icons.groups_rounded, Colors.blueAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Instructors', '128', Icons.badge_rounded, Colors.teal)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Active Subjects', '340', Icons.library_books_rounded, adminTheme)),
                    ],
                  ),
                  const SizedBox(height: 36),

                  const Text('Management Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                  const SizedBox(height: 16),

                  // --- Admin Action Grid ---
                  _buildAdminActionCard(
                    title: 'User Management',
                    subtitle: 'Create, suspend, or modify student and instructor accounts.',
                    icon: Icons.manage_accounts_rounded,
                    color: adminTheme,
                    onTap: () => onNavigateToTab?.call(1), // Jumps to Users Tab
                  ),
                  _buildAdminActionCard(
                    title: 'Course Administration',
                    subtitle: 'Manage categories, assign instructors, and oversee enrollment.',
                    icon: Icons.account_tree_rounded,
                    color: Colors.orange.shade600,
                    onTap: () => onNavigateToTab?.call(2), // Jumps to Courses Tab
                  ),
                  _buildAdminActionCard(
                    title: 'AI Service Gateway',
                    subtitle: 'Monitor API usage, token limits, and LLM connection health.',
                    icon: Icons.memory_rounded,
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminAIGatewayScreen()),
                      );
                    },
                  ),
                  _buildAdminActionCard(
                    title: 'System Reports',
                    subtitle: 'Generate overall grade distributions and platform activity logs.',
                    icon: Icons.analytics_rounded,
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminSystemReportsScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAdminActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 16),
          ],
        ),
      ),
    );
  }
}