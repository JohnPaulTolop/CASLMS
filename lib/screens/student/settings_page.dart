import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  // ============================================================
  // CASLMS DESIGN SYSTEM
  // ============================================================

  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  static const Color orange =
      Color(0xFFFF9418);

  static const Color green =
      Color(0xFF26A65B);

  static const Color red =
      Color(0xFFFF4B4B);

  // ============================================================
  // SETTINGS STATES
  // ============================================================

  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _offlineMode = true;

  bool _isLoggingOut = false;

  // ============================================================
  // FIREBASE LOGOUT
  // ============================================================

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthService().signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const AuthScreen(),
        ),
        (route) => false,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: red,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to log out. Please try again.',
          ),
          backgroundColor: red,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () =>
              Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: textDark,
            size: 26,
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 500,
            ),
            child:
                SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // ACCOUNT SECTION
                  // ==================================================

                  _buildSectionHeader(
                    'Account',
                  ),

                  _buildSettingsTile(
                    title:
                        'Personal Information',
                    subtitle:
                        'Update your email and profile details',
                    icon: Icons
                        .person_outline_rounded,
                    iconColor: primaryBlue,
                    onTap: () {},
                  ),

                  _buildSettingsTile(
                    title:
                        'Password & Security',
                    subtitle:
                        'Change your CASLMS login password',
                    icon: Icons
                        .lock_outline_rounded,
                    iconColor: orange,
                    onTap: () {},
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // ==================================================
                  // PREFERENCES SECTION
                  // ==================================================

                  _buildSectionHeader(
                    'Preferences',
                  ),

                  _buildSwitchTile(
                    title:
                        'Push Notifications',
                    subtitle:
                        'Get alerts for assignments and grades',
                    icon: Icons
                        .notifications_active_outlined,
                    iconColor: primaryBlue,
                    value:
                        _pushNotifications,
                    onChanged: (val) {
                      setState(() {
                        _pushNotifications =
                            val;
                      });
                    },
                  ),

                  _buildSwitchTile(
                    title:
                        'Email Notifications',
                    subtitle:
                        'Receive daily summaries via email',
                    icon:
                        Icons.email_outlined,
                    iconColor: primaryBlue,
                    value:
                        _emailNotifications,
                    onChanged: (val) {
                      setState(() {
                        _emailNotifications =
                            val;
                      });
                    },
                  ),

                  _buildSwitchTile(
                    title:
                        'Offline Storage',
                    subtitle:
                        'Automatically download module PDFs',
                    icon: Icons
                        .cloud_download_outlined,
                    iconColor: green,
                    value: _offlineMode,
                    onChanged: (val) {
                      setState(() {
                        _offlineMode = val;
                      });
                    },
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // ==================================================
                  // SYSTEM SECTION
                  // ==================================================

                  _buildSectionHeader(
                    'System & Support',
                  ),

                  _buildSettingsTile(
                    title: 'Clear Cache',
                    subtitle:
                        'Free up space on your device (142 MB)',
                    icon: Icons
                        .cleaning_services_rounded,
                    iconColor: textGrey,
                    onTap: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content:
                              const Text(
                            'Cache cleared successfully!',
                          ),
                          backgroundColor:
                              green,
                          behavior:
                              SnackBarBehavior
                                  .floating,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  _buildSettingsTile(
                    title: 'Help Center',
                    subtitle:
                        'Contact university IT support',
                    icon: Icons
                        .help_outline_rounded,
                    iconColor: textGrey,
                    onTap: () {},
                  ),

                  const SizedBox(
                    height: 32,
                  ),

                  // ==================================================
                  // REAL FIREBASE LOGOUT
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child:
                        ElevatedButton(
                      onPressed:
                          _isLoggingOut
                              ? null
                              : _handleLogout,
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            red.withValues(
                          alpha: 0.1,
                        ),
                        disabledBackgroundColor:
                            red.withValues(
                          alpha: 0.05,
                        ),
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                        ),
                      ),
                      child:
                          _isLoggingOut
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2.3,
                                    color: red,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Icon(
                                      Icons
                                          .logout_rounded,
                                      color:
                                          red,
                                      size: 20,
                                    ),
                                    SizedBox(
                                      width: 8,
                                    ),
                                    Text(
                                      'Log Out',
                                      style:
                                          TextStyle(
                                        color:
                                            red,
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),

                  const SizedBox(
                    height: 40,
                  ),

                  // ==================================================
                  // VERSION
                  // ==================================================

                  const Center(
                    child: Text(
                      'CASLMS Version 1.0.0',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
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
  // SECTION HEADER
  // ==============================================================

  Widget _buildSectionHeader(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12.0,
        left: 4.0,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight:
              FontWeight.w800,
          color: textDark,
        ),
      ),
    );
  }

  // ==============================================================
  // SETTINGS TILE
  // ==============================================================

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior:
          HitTestBehavior.opaque,
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color:
                const Color(
              0xFFE2E6ED,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(
                10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    iconColor.withValues(
                  alpha: 0.1,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),

            const SizedBox(
              width: 16,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .w700,
                      fontSize: 15,
                      color:
                          textDark,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      color:
                          textGrey,
                      fontSize: 12,
                      fontWeight:
                          FontWeight
                              .w500,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons
                  .chevron_right_rounded,
              color:
                  Color(0xFF9AA3B3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // SWITCH TILE
  // ==============================================================

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool>
        onChanged,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(
            0xFFE2E6ED,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.all(
              10,
            ),
            decoration:
                BoxDecoration(
              color:
                  iconColor.withValues(
                alpha: 0.1,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),

          const SizedBox(
            width: 16,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    fontSize: 15,
                    color: textDark,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    color: textGrey,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor:
                primaryBlue,
            activeTrackColor:
                primaryBlue.withValues(
              alpha: 0.3,
            ),
            inactiveThumbColor:
                Colors.white,
            inactiveTrackColor:
                const Color(
              0xFFE2E6ED,
            ),
          ),
        ],
      ),
    );
  }
}