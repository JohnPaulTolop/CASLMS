import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color darkText = Color(0xFF10182F);
  static const Color greyText = Color(0xFF68738A);
  static const Color background = Color(0xFFF8FAFD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        // 1. Center the content on wide screens
        child: Center(
          // 2. Constrain the maximum width to behave like a mobile screen
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              child: Column(
                children: [
                  // =====================================================
                  // CENTER CONTENT (Logo now acts as the centerpiece)
                  // =====================================================
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            // Main Illustration Background
                            Container(
                              width: 210, 
                              height: 210,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryBlue.withValues(alpha: 0.08),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Decorative circles
                                  Positioned(
                                    top: 18,
                                    right: 20,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF7DB0FF),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 28,
                                    left: 20,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFB9D3FF),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),

                                  // CAS Logo Centerpiece
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryBlue.withValues(alpha: 0.15),
                                          blurRadius: 25,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                      image: const DecorationImage(
                                        image: AssetImage('assets/images/CASlogo.jpg'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Organization
                            const Text(
                              'COLLEGE OF ARTS AND SCIENCES',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: primaryBlue,
                                letterSpacing: 1.5,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Main title
                            const Text(
                              'SSU Enhanced\nE-Learning',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                                letterSpacing: -0.8,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Description
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                'Your integrated digital learning platform for modules, interactive videos, and academic submissions.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: greyText,
                                  height: 1.55,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Feature pills
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildFeature(
                                  Icons.menu_book_rounded,
                                  'Learn',
                                ),
                                const SizedBox(width: 8),
                                _buildFeature(
                                  Icons.assignment_rounded,
                                  'Submit',
                                ),
                                const SizedBox(width: 8),
                                _buildFeature(
                                  Icons.video_library_rounded,
                                  'Watch',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // =====================================================
                  // BOTTOM ACTIONS
                  // =====================================================
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Get Started
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/auth');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 19,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Existing account
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/auth');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: darkText,
                            side: const BorderSide(
                              color: Color(0xFFDDE3EC),
                              width: 1.2,
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'I already have an account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Communicate. Assess. Organize. Succeed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: greyText,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
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
  // FEATURE PILL
  // ==============================================================

  static Widget _buildFeature(
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5EAF2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: primaryBlue,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: greyText,
            ),
          ),
        ],
      ),
    );
  }
}