import 'package:flutter/material.dart';
import '../auth_page.dart'; // To handle logout routing
import '../../services/auth_service.dart';
class InstructorProfileScreen extends StatelessWidget {
  const InstructorProfileScreen({super.key});

  // ============================================================
  // CASLMS DESIGN SYSTEM (Instructor Teal Palette)
  // ============================================================
  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color blue = Color(0xFF1769FF);
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
            'Instructor Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: textDark),
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
            // Expanded to 1200 for wide desktop browsers to match other screens
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                children: [
                  // ==================================================
                  // PROFILE HEADER
                  // ==================================================
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryTeal, width: 2),
                              ),
                              child: const CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person_rounded, color: primaryTeal, size: 48),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryTeal,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Prof. Mabansag', 
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textDark, letterSpacing: -0.5)
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Department of Information Technology', 
                          style: TextStyle(fontSize: 14, color: textGrey, fontWeight: FontWeight.w500)
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Samar State University', 
                            style: TextStyle(color: primaryTeal, fontSize: 12, fontWeight: FontWeight.w700)
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // ==================================================
                  // QUICK INFO CARDS
                  // ==================================================
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard('Office Hours', 'MWF 4PM-5PM', Icons.access_time_rounded, primaryTeal),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard('Faculty ID', 'SSU-IT-2018', Icons.badge_outlined, blue),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // ==================================================
                  // MENU OPTIONS
                  // ==================================================
                  Container(
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
                        _buildMenuTile(Icons.account_circle_outlined, 'Personal Information'),
                        _buildDivider(),
                        _buildMenuTile(Icons.notifications_none_rounded, 'Notification Preferences'),
                        _buildDivider(),
                        _buildMenuTile(Icons.security_rounded, 'Account Security'),
                        _buildDivider(),
                        _buildMenuTile(Icons.lightbulb_outline_rounded, 'Smart University Roadmap Ops', subtitle: 'Manage IoT integration settings'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // ==================================================
                  // SUPPORT & LOGOUT
                  // ==================================================
                  Container(
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
                        _buildMenuTile(Icons.help_outline_rounded, 'Help & Support'),
                        _buildDivider(),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: red.withValues(alpha: 0.1), 
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.logout_rounded, color: red, size: 20),
                          ),
                          title: const Text(
                            'Log Out', 
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: red)
                          ),
                          onTap: () {
                            _showLogoutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value, 
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark), 
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            style: const TextStyle(fontSize: 11, color: textGrey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, {String? subtitle}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primaryTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primaryTeal, size: 20),
      ),
      title: Text(
        title, 
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textDark),
      ),
      subtitle: subtitle != null 
          ? Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500)) 
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9BA4B4), size: 20),
      onTap: () {},
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1, 
      thickness: 1, 
      color: Color(0xFFF0F2F5), 
      indent: 68, 
      endIndent: 20,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out of your account?',
            style: TextStyle(
              color: textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: textGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await AuthService().signOut();

                  if (!dialogContext.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    dialogContext,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(),
                    ),
                    (route) => false,
                  );
                } on AuthServiceException catch (e) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}