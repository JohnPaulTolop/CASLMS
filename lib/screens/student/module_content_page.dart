import 'package:flutter/material.dart';

class ModuleContentScreen extends StatefulWidget {
  final String title;
  final String moduleName;

  const ModuleContentScreen({
    super.key,
    this.title = 'Introduction to Programming',
    this.moduleName = 'Module 1',
  });

  @override
  State<ModuleContentScreen> createState() => _ModuleContentScreenState();
}

class _ModuleContentScreenState extends State<ModuleContentScreen> {
  // ============================================================
  // CASLMS DESIGN SYSTEM
  // ============================================================
  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  
  static const Color orange = Color(0xFFFF9418);
  static const Color green = Color(0xFF26A65B);
  static const Color purple = Color(0xFF7B4DFF);

  int _selectedTabIndex = 0;

  // AI State Simulation
  bool _isGeneratingSummary = false;
  String? _generatedSummary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 850;

        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  // ============================================================
  // 1. DESKTOP WIDE LAYOUT (Two Columns - Expanded up to 1200px)
  // ============================================================
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN: Main Content & Video
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.arrow_back_rounded, color: textDark, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Back to Modules',
                                style: TextStyle(fontWeight: FontWeight.w700, color: textDark, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.moduleName.toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryBlue, letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.title,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: textDark, letterSpacing: -1, height: 1.1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '12 mins video • 1st Semester, AY 2026-2027',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textGrey),
                        ),
                        const SizedBox(height: 32),
                        
                        _buildVideoPlayer(),
                        
                        const SizedBox(height: 40),
                        _buildAboutSection(),
                      ],
                    ),
                  ),
                ),
                
                // Divider
                Container(width: 1, color: const Color(0xFFE2E6ED)),
                
                // RIGHT COLUMN: AI Assistant & Resources (Always visible)
                Expanded(
                  flex: 4,
                  child: Container(
                    color: Colors.white,
                    height: double.infinity,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Study Tools', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textDark)),
                          const SizedBox(height: 24),
                          _buildAIAssistantSection(),
                          
                          const SizedBox(height: 40),
                          const Divider(height: 1, color: Color(0xFFE2E6ED)),
                          const SizedBox(height: 40),
                          
                          _buildResourcesSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 2. MOBILE NARROW LAYOUT (Original Stacked Tabs)
  // ============================================================
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.white, 
      body: Stack(
        children: [
          // Blue background layer locked to the top half
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            color: primaryBlue,
          ),

          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Mobile Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 26),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                          ),
                          child: const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.moduleName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, height: 1.2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '12 mins video • 1st Semester, AY 2026-2027',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),

                  // Mobile Body & Tabs
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.7, 
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: Row(
                            children: [
                              _buildTab('Overview', 0),
                              const SizedBox(width: 12),
                              _buildTab('AI Assistant ✨', 1),
                            ],
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 65),
                          child: _selectedTabIndex == 0 
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildVideoPlayer(),
                                  const SizedBox(height: 24),
                                  _buildAboutSection(),
                                  const SizedBox(height: 32),
                                  _buildResourcesSection(),
                                ],
                              ) 
                            : _buildAIAssistantSection(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // REUSABLE UI COMPONENTS (Shared between Desktop & Mobile)
  // ==============================================================

  Widget _buildTab(String title, int index) {
    final bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? primaryBlue : textGrey,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1617042375876-a13e36732a04?auto=format&fit=crop&q=80&w=800'),
            fit: BoxFit.cover,
            opacity: 0.6,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About this module',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
        ),
        const SizedBox(height: 12),
        const Text(
          'In this lesson, we will explore the fundamental building blocks of programming. You will learn the difference between various architectures and how to compose them into a complex system structure.',
          style: TextStyle(fontSize: 14, color: textGrey, height: 1.6, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildResourcesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attached Resources',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
        ),
        const SizedBox(height: 16),
        _buildActionTile(
          title: 'Presentation Slides',
          subtitle: 'PDF Document • 2.4 MB',
          icon: Icons.picture_as_pdf_rounded,
          iconColor: Colors.redAccent,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildAIAssistantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Warning Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF), 
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: purple, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI-Assisted Learning',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: purple),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Summaries and reviewers are generated by AI based on this module\'s specific materials. Always verify with your instructor\'s original content.',
                      style: TextStyle(fontSize: 12, color: purple.withValues(alpha: 0.8), height: 1.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        if (_generatedSummary == null && !_isGeneratingSummary) ...[
          _buildActionTile(
            title: 'Generate Lesson Summary',
            subtitle: 'Extract key concepts and terms instantly.',
            icon: Icons.subject_rounded,
            iconColor: primaryBlue,
            onTap: _simulateAIGeneration,
          ),
          _buildActionTile(
            title: 'Create Study Reviewer',
            subtitle: 'Generate flashcards based on this video.',
            icon: Icons.style_rounded,
            iconColor: orange,
            onTap: () {},
          ),
          _buildActionTile(
            title: 'Generate Practice Questions',
            subtitle: 'Test your knowledge before the real quiz.',
            icon: Icons.quiz_rounded,
            iconColor: green,
            onTap: () {},
          ),
        ],

        // Loading State
        if (_isGeneratingSummary)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 50.0),
            child: Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: purple),
                  const SizedBox(height: 20),
                  Text(
                    'Generating summary from transcript...',
                    style: TextStyle(color: textGrey, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

        // Generated Result State
        if (_generatedSummary != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E6ED)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('✨ AI Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
                    Icon(Icons.copy_rounded, size: 20, color: textGrey.withValues(alpha: 0.6)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E6ED)),
                ),
                Text(
                  _generatedSummary!,
                  style: const TextStyle(fontSize: 14, color: textDark, height: 1.6, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E6ED)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA3B3), size: 24),
          ],
        ),
      ),
    );
  }

  // --- Fake API Call for Demo ---
  Future<void> _simulateAIGeneration() async {
    setState(() => _isGeneratingSummary = true);
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    setState(() {
      _isGeneratingSummary = false;
      _generatedSummary = '''Flutter is a UI toolkit built by Google. 

Key Concepts:
• Widgets: The basic building blocks of a Flutter interface. Everything is a widget.
• StatelessWidget: A widget whose information does not change over time.
• StatefulWidget: A widget that can change its appearance in response to user interaction or data changes.

Remember: The 'build' method is called every time the UI needs to be updated.''';
    });
  }
}