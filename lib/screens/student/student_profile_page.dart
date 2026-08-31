import 'package:flutter/material.dart';
import '../auth_page.dart';
import 'settings_page.dart';
import '../../services/auth_service.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  // ==============================================================
  // CASLMS DESIGN SYSTEM
  // ==============================================================
  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color darkText = Color(0xFF10182F);
  static const Color greyText = Color(0xFF68738A);
  static const Color background = Color(0xFFF7F9FC);
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
            'My Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: darkText,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: darkText),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
            // Expanded to 1200px for wide desktop monitors
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
                                border: Border.all(color: primaryBlue, width: 2),
                              ),
                              child: const CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person_rounded, color: primaryBlue, size: 48),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Rolando Mabansag', 
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: darkText, letterSpacing: -0.5)
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'BS Information Technology', 
                          style: TextStyle(fontSize: 14, color: greyText, fontWeight: FontWeight.w500)
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Samar State University', 
                            style: TextStyle(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.w700)
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // ==================================================
                  // QUICK STATS
                  // ==================================================
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard('Completed', '12 Modules', Icons.emoji_events_rounded, orange),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard('Student ID', '2023-1042', Icons.badge_rounded, primaryBlue),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // ==================================================
                  // ACADEMIC & DEVELOPER SETTINGS
                  // ==================================================
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6EAF0)),
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
                        _buildMenuTile(Icons.code_rounded, 'Linked Accounts', subtitle: 'GitHub Connected'),
                        _buildDivider(),
                        _buildMenuTile(Icons.folder_shared_outlined, 'Digital Portfolio', subtitle: 'Manage capstone projects'),
                        _buildDivider(),
                        _buildMenuTile(Icons.notifications_none_rounded, 'Notification Preferences'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // ==================================================
                  // APP SETTINGS & LOGOUT
                  // ==================================================
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6EAF0)),
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
                        _buildMenuTile(Icons.dark_mode_outlined, 'App Theme', subtitle: 'System Default'),
                        _buildDivider(),
                        _buildMenuTile(Icons.help_outline_rounded, 'Help & Support'),
                        _buildDivider(),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: red.withValues(alpha: 0.1), 
                              borderRadius: BorderRadius.circular(12)
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
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025), 
            blurRadius: 12, 
            offset: const Offset(0, 5)
          )
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            style: const TextStyle(fontSize: 12, color: greyText, fontWeight: FontWeight.w600)
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
          color: primaryBlue.withValues(alpha: 0.08), 
          borderRadius: BorderRadius.circular(12)
        ),
        child: Icon(icon, color: primaryBlue, size: 20),
      ),
      title: Text(
        title, 
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: darkText)
      ),
      subtitle: subtitle != null 
          ? Text(subtitle, style: const TextStyle(color: greyText, fontSize: 12, fontWeight: FontWeight.w500)) 
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
      endIndent: 20
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
              color: darkText,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out of your account?',
            style: TextStyle(
              color: greyText,
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
                  color: greyText,
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