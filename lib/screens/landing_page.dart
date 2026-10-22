import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color lightText = Colors.white;
  static const Color greyText = Color(0xFFA0ABBF);
  static const Color background = Color(0xFF0B1120);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/images/ssu.jpg',
                // The campus photo is optional; keep the dark background until supplied.
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.expand(),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),

          // 2. Gradient fade overlay to transition the image into a solid dark background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, background],
                  stops: [0.0, 0.55, 0.85],
                ),
              ),
            ),
          ),

          // 3. Foreground Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),

                                // CAS Logo Centerpiece (Background design removed)
                                Container(
                                  width: 130, // Slightly increased to compensate for removed outer circle
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryBlue.withValues(
                                          alpha: 0.2,
                                        ), // Adjusted for dark mode compatibility
                                        blurRadius: 25,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    image: const DecorationImage(
                                      image: AssetImage(
                                        'assets/images/CASlogo.jpg',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 40),

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

                                const Text(
                                  'SSU Enhanced\nE-Learning',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 34,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: lightText,
                                    letterSpacing: -0.8,
                                  ),
                                ),

                                const SizedBox(height: 16),

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

                      // BOTTOM ACTIONS
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                  Icon(Icons.arrow_forward_rounded, size: 19),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/auth');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: lightText,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1.2,
                                ),
                                backgroundColor: Colors.transparent,
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
        ],
      ),
    );
  }

  static Widget _buildFeature(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: primaryBlue),
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
