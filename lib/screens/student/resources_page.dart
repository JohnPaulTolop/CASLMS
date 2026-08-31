import 'package:flutter/material.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  // ==============================================================
  // CASLMS DESIGN SYSTEM
  // ==============================================================

  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color darkText = Color(0xFF10182F);
  static const Color greyText = Color(0xFF68738A);
  static const Color background = Color(0xFFF7F9FC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resources',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                                letterSpacing: -0.7,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Find guides, documents, and learning materials.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: greyText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE5E9F0),
                          ),
                        ),
                        child: const Icon(
                          Icons.folder_outlined,
                          color: primaryBlue,
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // SEARCH
                  // ==================================================

                  _buildSearchBar(),

                  const SizedBox(height: 27),

                  // ==================================================
                  // QUICK CATEGORIES
                  // ==================================================

                  _buildSectionTitle(
                    'Browse Resources',
                    'Quick access to useful materials',
                  ),

                  const SizedBox(height: 13),

                  SizedBox(
                    height: 82,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildCategory(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'Documents',
                          color: const Color(0xFFE45757),
                        ),
                        _buildCategory(
                          icon: Icons.code_rounded,
                          label: 'Development',
                          color: primaryBlue,
                        ),
                        _buildCategory(
                          icon: Icons.school_outlined,
                          label: 'Academic',
                          color: const Color(0xFF7956D8),
                        ),
                        _buildCategory(
                          icon: Icons.link_rounded,
                          label: 'Web Links',
                          color: const Color(0xFF26A65B),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // UNIVERSITY GUIDELINES
                  // ==================================================

                  _buildSectionTitle(
                    'University Guidelines',
                    'Official academic references and documents',
                  ),

                  const SizedBox(height: 13),

                  _buildResourceItem(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'SSU IT Capstone Format Guide',
                    subtitle: 'PDF Document • 2.4 MB',
                    color: const Color(0xFFE45757),
                  ),

                  _buildResourceItem(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'Student Handbook 2026',
                    subtitle: 'PDF Document • 5.1 MB',
                    color: const Color(0xFFE45757),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // DEVELOPMENT
                  // ==================================================

                  _buildSectionTitle(
                    'Development Cheat Sheets',
                    'Helpful references for IT development',
                  ),

                  const SizedBox(height: 13),

                  _buildResourceItem(
                    icon: Icons.code_rounded,
                    title: 'Flutter & Dart Syntax Guide',
                    subtitle: 'Web Link',
                    color: primaryBlue,
                  ),

                  _buildResourceItem(
                    icon: Icons.security_rounded,
                    title: 'Firebase Security Rules Template',
                    subtitle: 'Code Snippet',
                    color: const Color(0xFFFF9418),
                  ),

                  _buildResourceItem(
                    icon: Icons.compare_arrows_rounded,
                    title: 'React Native vs Jetpack Compose',
                    subtitle: 'Article',
                    color: const Color(0xFF26A65B),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // RECENTLY ADDED
                  // ==================================================

                  _buildSectionTitle(
                    'Recently Added',
                    'New resources available for you',
                  ),

                  const SizedBox(height: 13),

                  _buildRecentResource(
                    'Mobile UI/UX Design Principles',
                    'Article • 8 min read',
                    Icons.design_services_outlined,
                    const Color(0xFF7956D8),
                  ),

                  _buildRecentResource(
                    'Database Normalization Guide',
                    'PDF Document • 1.8 MB',
                    Icons.storage_outlined,
                    const Color(0xFF2495E8),
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // INFO CARD
                  // ==================================================

                  _buildInfoCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // SEARCH BAR
  // ==============================================================

  Widget _buildSearchBar() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE3E7EE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search resources...',
          hintStyle: const TextStyle(
            color: Color(0xFFA0A8B7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: primaryBlue,
            size: 21,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: primaryBlue,
                size: 18,
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // SECTION TITLE
  // ==============================================================

  Widget _buildSectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: darkText,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            color: greyText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // RESOURCE CATEGORY
  // ==============================================================

  Widget _buildCategory({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 92,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6EAF0),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // RESOURCE ITEM
  // ==============================================================

  Widget _buildResourceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE6EAF0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: greyText,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: primaryBlue,
                    size: 17,
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
  // RECENT RESOURCE
  // ==============================================================

  Widget _buildRecentResource(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE6EAF0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: greyText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF9BA4B4),
            size: 20,
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // INFO CARD
  // ==============================================================

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: primaryBlue,
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Resources are organized to help you quickly find academic guides, development references, and useful learning materials.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.45,
                color: greyText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}