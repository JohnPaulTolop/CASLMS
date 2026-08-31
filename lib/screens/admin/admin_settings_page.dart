import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth_page.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState
    extends State<AdminSettingsScreen> {
  final Color adminTheme = Colors.indigo.shade600;

  // ============================================================
  // SIMULATED STATES
  // ============================================================

  bool _isPingingMoodle = false;
  String _moodlePing = '24ms';
  bool _isPurgingCache = false;

  // ============================================================
  // MOODLE SERVER PING
  // ============================================================

  void _pingMoodleServer() async {
    setState(() => _isPingingMoodle = true);

    // Simulate network delay
    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (mounted) {
      setState(() {
        _isPingingMoodle = false;

        // Randomize ping slightly for realism
        _moodlePing =
            '${20 + (DateTime.now().millisecond % 15)}ms';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moodle REST Server ping successful: $_moodlePing',
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // PURGE CACHE
  // ============================================================

  void _purgeCache() async {
    Navigator.pop(context);

    setState(
      () => _isPurgingCache = true,
    );

    await Future.delayed(
      const Duration(seconds: 3),
    );

    if (mounted) {
      setState(
        () => _isPurgingCache = false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Text(
                'System cache purged successfully.',
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // FIREBASE ADMIN LOGOUT
  // ============================================================

  Future<void> _logoutAdmin() async {
    try {
      await AuthService().signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
        (route) => false,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to log out. Please try again.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F9FA),

      appBar: PreferredSize(
        preferredSize:
            const Size.fromHeight(60.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 24.0,
          title: const Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                'Platform Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'API & Integration Health',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1200,
            ),
            child: SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server Connections',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // MOODLE REST SERVER
                  // ==================================================

                  _buildInteractiveTile(
                    title:
                        'Moodle REST Server',
                    subtitle:
                        'https://moodle.ssu.edu.ph',
                    icon: Icons.dns_rounded,
                    iconColor: Colors.green,
                    trailing:
                        _isPingingMoodle
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Colors.green,
                                ),
                              )
                            : Text(
                                'Ping: $_moodlePing',
                                style:
                                    TextStyle(
                                  color: Colors
                                      .green.shade700,
                                  fontWeight:
                                      FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                    onTap:
                        _pingMoodleServer,
                  ),

                  // ==================================================
                  // AI SERVICE GATEWAY
                  // ==================================================

                  _buildInteractiveTile(
                    title:
                        'CASLMS AI Service Gateway',
                    subtitle:
                        'Manage LLM Token & API Keys',
                    icon: Icons.memory_rounded,
                    iconColor:
                        Colors.deepPurple,
                    trailing: const Icon(
                      Icons.edit_rounded,
                      color:
                          Colors.deepPurple,
                      size: 18,
                    ),
                    onTap: () =>
                        _showAiSettingsModal(
                      context,
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'System Cache & Security',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // PURGE CACHE
                  // ==================================================

                  _buildInteractiveTile(
                    title:
                        'Purge Local Cache',
                    subtitle:
                        'Clears downloaded offline modules.',
                    icon: Icons
                        .cleaning_services_rounded,
                    iconColor: Colors.orange,
                    trailing:
                        _isPurgingCache
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Colors.orange,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .arrow_forward_ios_rounded,
                                color:
                                    Colors.grey,
                                size: 16,
                              ),
                    onTap: () =>
                        _showPurgeConfirmationDialog(
                      context,
                    ),
                  ),

                  // ==================================================
                  // RESET TOKENS
                  // ==================================================

                  _buildInteractiveTile(
                    title:
                        'Reset Web Service Tokens',
                    subtitle:
                        'Forces all users to re-authenticate.',
                    icon:
                        Icons.lock_reset_rounded,
                    iconColor:
                        Colors.redAccent,
                    trailing: const Icon(
                      Icons.warning_rounded,
                      color:
                          Colors.redAccent,
                      size: 18,
                    ),
                    onTap: () =>
                        _showResetConfirmationDialog(
                      context,
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Admin Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // REAL FIREBASE LOGOUT
                  // ==================================================

                  _buildInteractiveTile(
                    title:
                        'Log Out Administrator',
                    subtitle:
                        'End secure session',
                    icon:
                        Icons.logout_rounded,
                    iconColor:
                        Colors.black54,
                    trailing:
                        const SizedBox.shrink(),
                    onTap: _logoutAdmin,
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

  // ==============================================================
  // UI COMPONENTS
  // ==============================================================

  Widget _buildInteractiveTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(
                0,
                4,
              ),
            ),
          ],
          border: Border.all(
            color:
                Colors.grey.shade100,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(
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
                size: 22,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 15,
                      color:
                          Colors.black87,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors
                          .grey[500],
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            trailing,
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // AI SETTINGS MODAL
  // ==============================================================

  void _showAiSettingsModal(
    BuildContext context,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context)
                .viewInsets
                .bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration:
              const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.only(
              topLeft:
                  Radius.circular(32),
              topRight:
                  Radius.circular(32),
            ),
          ),
          child:
              SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.memory_rounded,
                      color:
                          Colors.deepPurple,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'AI Gateway Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                TextField(
                  obscureText: true,
                  decoration:
                      InputDecoration(
                    labelText:
                        'Gemini / OpenAI API Key',
                    hintText:
                        'sk-***************************',
                    filled: true,
                    fillColor:
                        Colors.grey[50],
                    prefixIcon:
                        const Icon(
                      Icons.key_rounded,
                      color: Colors.grey,
                    ),
                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      borderSide:
                          BorderSide(
                        color: Colors
                            .grey.shade200,
                      ),
                    ),
                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      borderSide:
                          const BorderSide(
                        color: Colors
                            .deepPurple,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                Container(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors
                        .deepPurple.shade50,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .info_outline_rounded,
                        color: Colors
                            .deepPurple,
                        size: 20,
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child: Text(
                          'Ensure your billing limits are properly configured in your AI provider\'s console to avoid service interruptions for Instructors.',
                          style:
                              TextStyle(
                            color: Colors
                                .deepPurple
                                .shade800,
                            fontSize: 12,
                            fontWeight:
                                FontWeight
                                    .w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 56,
                  child:
                      ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'AI Gateway credentials updated.',
                          ),
                          backgroundColor:
                              Colors
                                  .deepPurple,
                        ),
                      );
                    },
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          Colors.deepPurple,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Credentials',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 32,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==============================================================
  // PURGE CONFIRMATION
  // ==============================================================

  void _showPurgeConfirmationDialog(
    BuildContext context,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Text(
          'Purge System Cache?',
          style: TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        content: const Text(
          'This will clear all temporary files and downloaded modules from the server. This operation may take a few moments and cannot be undone.',
          style: TextStyle(
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _purgeCache,
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.orange.shade700,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
            ),
            child: const Text(
              'Purge Cache',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // RESET TOKEN CONFIRMATION
  // ==============================================================

  void _showResetConfirmationDialog(
    BuildContext context,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
            ),
            SizedBox(width: 8),
            Text(
              'Critical Action',
              style: TextStyle(
                fontWeight:
                    FontWeight.w800,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: const Text(
          'Resetting Web Service Tokens will instantly invalidate all active sessions. Every student and instructor will be forcefully logged out and required to sign in again. Proceed?',
          style: TextStyle(
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
              );

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content: Text(
                    'All web service tokens have been reset.',
                  ),
                  backgroundColor:
                      Colors.red,
                  behavior:
                      SnackBarBehavior
                          .floating,
                ),
              );
            },
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.red,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
            ),
            child: const Text(
              'Force Reset',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}