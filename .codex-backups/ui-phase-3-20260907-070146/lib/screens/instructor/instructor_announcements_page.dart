import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/announcement_service.dart';

class InstructorAnnouncementsScreen extends StatefulWidget {
  const InstructorAnnouncementsScreen({
    super.key,
  });

  @override
  State<InstructorAnnouncementsScreen> createState() =>
      _InstructorAnnouncementsScreenState();
}

class _InstructorAnnouncementsScreenState
    extends State<InstructorAnnouncementsScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color orange = Color(0xFFFF9418);

  // ============================================================
  // SERVICE
  // ============================================================

  final AnnouncementService _announcementService =
      AnnouncementService();

  // ============================================================
  // STATE
  // ============================================================

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _courses = [];

  bool _isLoading = true;

  String? _errorMessage;

  String _searchQuery = '';

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> courses =
          await _announcementService.getInstructorCourses();

      final List<Map<String, dynamic>> announcements =
          await _announcementService.getInstructorAnnouncements();

      if (!mounted) {
        return;
      }

      setState(() {
        _courses = courses;
        _announcements = announcements;

        _isLoading = false;
        _errorMessage = null;
      });
    } on AnnouncementServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load announcements.';
      });
    }
  }

  // ============================================================
  // FILTER ANNOUNCEMENTS
  // ============================================================

  List<Map<String, dynamic>> get _filteredAnnouncements {
    final String query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _announcements;
    }

    return _announcements.where(
      (announcement) {
        final String title =
            (announcement['title'] ?? '').toString().toLowerCase();

        final String message =
            (announcement['message'] ?? '').toString().toLowerCase();

        final String courseCode =
            (announcement['courseCode'] ?? '').toString().toLowerCase();

        final String courseTitle =
            (announcement['courseTitle'] ?? '').toString().toLowerCase();

        return title.contains(query) ||
            message.contains(query) ||
            courseCode.contains(query) ||
            courseTitle.contains(query);
      },
    ).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Announcements',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ==========================================================
      // NEW ANNOUNCEMENT BUTTON
      // ==========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateAnnouncementModal();
        },
        backgroundColor: primaryTeal,
        icon: const Icon(
          Icons.campaign_rounded,
          color: Colors.white,
        ),
        label: const Text(
          'New Announcement',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1200,
            ),
            child: Column(
              children: [
                // ==================================================
                // SEARCH
                // ==================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    18,
                    24,
                    10,
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search announcements...',
                      hintStyle: const TextStyle(
                        color: Color(0xFFA0A8B7),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: primaryTeal,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFE3E7EE),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFE3E7EE),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: primaryTeal,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    // ------------------------------------------------------------
    // LOADING
    // ------------------------------------------------------------

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryTeal,
        ),
      );
    }

    // ------------------------------------------------------------
    // ERROR
    // ------------------------------------------------------------

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.redAccent,
                size: 46,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadData,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ------------------------------------------------------------
    // EMPTY
    // ------------------------------------------------------------

    if (_announcements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_outlined,
              color: primaryTeal,
              size: 52,
            ),
            SizedBox(height: 12),
            Text(
              'No announcements yet',
              style: TextStyle(
                color: textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Use New Announcement to post to your students.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // ------------------------------------------------------------
    // SEARCH EMPTY
    // ------------------------------------------------------------

    if (_filteredAnnouncements.isEmpty) {
      return const Center(
        child: Text(
          'No matching announcements.',
          style: TextStyle(
            color: textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // ------------------------------------------------------------
    // REAL ANNOUNCEMENTS
    // ------------------------------------------------------------

    return RefreshIndicator(
      color: primaryTeal,
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          24,
          12,
          24,
          100,
        ),
        itemCount: _filteredAnnouncements.length,
        itemBuilder: (
          context,
          index,
        ) {
          return _buildAnnouncementCard(
            _filteredAnnouncements[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // ANNOUNCEMENT CARD
  // ============================================================

  Widget _buildAnnouncementCard(
    Map<String, dynamic> announcement,
  ) {
    final String id =
        (announcement['id'] ?? '').toString();

    final String title =
        (announcement['title'] ?? 'Announcement').toString();

    final String message =
        (announcement['message'] ?? '').toString();

    final String courseCode =
        (announcement['courseCode'] ?? '').toString();

    final String courseTitle =
        (announcement['courseTitle'] ?? '').toString();

    final String targetType =
        (announcement['targetType'] ?? '').toString();

    final bool isUrgent =
        announcement['isUrgent'] == true ||
        (announcement['priority'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            'urgent';

    final DateTime? createdAt = _toDate(
      announcement['createdAt'],
    );

    final String targetText =
        targetType == 'all_classes' ||
            (courseCode.isEmpty && courseTitle.isEmpty)
        ? 'All Classes'
        : courseCode.isNotEmpty
        ? '$courseCode • $courseTitle'
        : courseTitle;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: isUrgent
              ? orange.withValues(
                  alpha: 0.40,
                )
              : const Color(
                  0xFFE6EAF0,
                ),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.02,
            ),
            blurRadius: 10,
            offset: const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================================
          // TITLE
          // ======================================================

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUrgent) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: orange.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(
                            8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: orange,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'URGENT',
                              style: TextStyle(
                                color: orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // OPTIONS
              // ==================================================

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDelete(
                      id,
                      title,
                    );
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            targetText,
            style: const TextStyle(
              color: primaryTeal,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: Divider(
              height: 1,
            ),
          ),

          // ======================================================
          // MESSAGE
          // ======================================================

          Text(
            message,
            style: const TextStyle(
              color: textDark,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),

          const SizedBox(height: 16),

          // ======================================================
          // FOOTER
          // ======================================================

          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: textGrey,
              ),
              const SizedBox(width: 5),
              Text(
                createdAt == null
                    ? 'Recently posted'
                    : _formatDate(
                        createdAt,
                      ),
                style: const TextStyle(
                  color: textGrey,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.public_rounded,
                color: textGrey,
                size: 14,
              ),
              const SizedBox(width: 4),
              const Text(
                'Published',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CREATE ANNOUNCEMENT MODAL
  // ============================================================

  Future<void> _showCreateAnnouncementModal() async {
    // ------------------------------------------------------------
    // IMPORTANT:
    // We are intentionally NOT using TextEditingController here.
    //
    // This avoids the Flutter bottom-sheet lifecycle assertion
    // that happened when controllers were disposed while the
    // modal was still being removed from the widget tree.
    // ------------------------------------------------------------

    String selectedCourseId = '';

    String title = '';

    String message = '';

    bool isUrgent = false;

    bool isPosting = false;

    final bool? posted =
        await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (
        BuildContext bottomSheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext modalContext,
            StateSetter setModalState,
          ) {
            return PopScope(
              canPop: !isPosting,

              child: Container(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(modalContext).size.height *
                      0.90,
                ),

                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 22,
                  bottom:
                      MediaQuery.of(modalContext)
                          .viewInsets
                          .bottom +
                      24,
                ),

                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                      28,
                    ),
                  ),
                ),

                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      // ==========================================
                      // HEADER
                      // ==========================================

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'New Announcement',
                              style: TextStyle(
                                color: textDark,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),

                          IconButton(
                            tooltip: 'Close',
                            onPressed: isPosting
                                ? null
                                : () {
                                    Navigator.of(
                                      bottomSheetContext,
                                    ).pop(
                                      false,
                                    );
                                  },
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ==========================================
                      // SEND TO
                      // ==========================================

                      const Text(
                        'Send To',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 7),

                      DropdownButtonFormField<String>(
                        initialValue: selectedCourseId,
                        isExpanded: true,

                        decoration: _inputDecoration(),

                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text(
                              'All Classes',
                            ),
                          ),

                          ..._courses.map(
                            (
                              Map<String, dynamic> course,
                            ) {
                              final String id =
                                  (course['id'] ?? '').toString();

                              final String code =
                                  (course['code'] ?? '').toString();

                              final String courseTitle =
                                  (course['title'] ?? 'Course')
                                      .toString();

                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(
                                  code.isEmpty
                                      ? courseTitle
                                      : '$code • $courseTitle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ],

                        onChanged: isPosting
                            ? null
                            : (value) {
                                setModalState(
                                  () {
                                    selectedCourseId =
                                        value ?? '';
                                  },
                                );
                              },
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // TITLE
                      // ==========================================

                      TextFormField(
                        enabled: !isPosting,
                        textInputAction: TextInputAction.next,

                        onChanged: (value) {
                          title = value;
                        },

                        decoration: _inputDecoration(
                          label: 'Announcement Title',
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // MESSAGE
                      // ==========================================

                      TextFormField(
                        enabled: !isPosting,
                        minLines: 4,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,

                        onChanged: (value) {
                          message = value;
                        },

                        decoration: _inputDecoration(
                          label: 'Message',
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ==========================================
                      // URGENT
                      // ==========================================

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? orange.withValues(
                                  alpha: 0.06,
                                )
                              : const Color(
                                  0xFFF8FAFD,
                                ),
                          borderRadius: BorderRadius.circular(
                            14,
                          ),
                          border: Border.all(
                            color: isUrgent
                                ? orange.withValues(
                                    alpha: 0.35,
                                  )
                                : const Color(
                                    0xFFE1E5EC,
                                  ),
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,

                          value: isUrgent,

                          activeThumbColor: orange,

                          title: const Text(
                            'Urgent announcement',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),

                          subtitle: const Text(
                            'Highlight this announcement for students.',
                            style: TextStyle(
                              color: textGrey,
                              fontSize: 11,
                            ),
                          ),

                          onChanged: isPosting
                              ? null
                              : (value) {
                                  setModalState(
                                    () {
                                      isUrgent = value;
                                    },
                                  );
                                },
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ==========================================
                      // POST
                      // ==========================================

                      SizedBox(
                        width: double.infinity,
                        height: 52,

                        child: ElevatedButton.icon(
                          onPressed: isPosting
                              ? null
                              : () async {
                                  // ==============================
                                  // VALIDATION
                                  // ==============================

                                  if (title.trim().isEmpty) {
                                    ScaffoldMessenger.of(
                                      bottomSheetContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter an announcement title.',
                                        ),
                                        behavior:
                                            SnackBarBehavior.floating,
                                      ),
                                    );

                                    return;
                                  }

                                  if (message.trim().isEmpty) {
                                    ScaffoldMessenger.of(
                                      bottomSheetContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter an announcement message.',
                                        ),
                                        behavior:
                                            SnackBarBehavior.floating,
                                      ),
                                    );

                                    return;
                                  }

                                  // ==============================
                                  // START LOADING
                                  // ==============================

                                  setModalState(
                                    () {
                                      isPosting = true;
                                    },
                                  );

                                  String courseCode = '';

                                  String courseTitle = '';

                                  // ==============================
                                  // FIND SELECTED COURSE
                                  // ==============================

                                  if (selectedCourseId.isNotEmpty) {
                                    final Map<String, dynamic>
                                        selectedCourse =
                                        _courses.firstWhere(
                                      (
                                        Map<String, dynamic> item,
                                      ) {
                                        return (item['id'] ?? '')
                                                .toString() ==
                                            selectedCourseId;
                                      },
                                      orElse: () =>
                                          <String, dynamic>{},
                                    );

                                    courseCode =
                                        (selectedCourse['code'] ?? '')
                                            .toString();

                                    courseTitle =
                                        (selectedCourse['title'] ?? '')
                                            .toString();
                                  }

                                  try {
                                    // ============================
                                    // SAVE TO FIRESTORE
                                    // ============================

                                    await _announcementService
                                        .createAnnouncement(
                                      title: title,
                                      message: message,
                                      courseId: selectedCourseId,
                                      courseCode: courseCode,
                                      courseTitle: courseTitle,
                                      isUrgent: isUrgent,
                                    );

                                    // The sheet may have been
                                    // removed while Firebase was
                                    // waiting, so check first.
                                    if (!bottomSheetContext.mounted) {
                                      return;
                                    }

                                    // ============================
                                    // CLOSE WITH SUCCESS RESULT
                                    // ============================

                                    Navigator.of(
                                      bottomSheetContext,
                                    ).pop(
                                      true,
                                    );
                                  } on AnnouncementServiceException catch (e) {
                                    if (!bottomSheetContext.mounted) {
                                      return;
                                    }

                                    setModalState(
                                      () {
                                        isPosting = false;
                                      },
                                    );

                                    ScaffoldMessenger.of(
                                      bottomSheetContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          e.message,
                                        ),
                                        backgroundColor:
                                            Colors.redAccent,
                                        behavior:
                                            SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (_) {
                                    if (!bottomSheetContext.mounted) {
                                      return;
                                    }

                                    setModalState(
                                      () {
                                        isPosting = false;
                                      },
                                    );

                                    ScaffoldMessenger.of(
                                      bottomSheetContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Unable to post announcement.',
                                        ),
                                        backgroundColor:
                                            Colors.redAccent,
                                        behavior:
                                            SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },

                          icon: isPosting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                ),

                          label: Text(
                            isPosting
                                ? 'Posting...'
                                : 'Post Announcement',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTeal,
                            disabledBackgroundColor:
                                primaryTeal.withValues(
                              alpha: 0.55,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                14,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // ============================================================
    // THE SHEET IS NOW FULLY CLOSED
    // ============================================================

    if (!mounted) {
      return;
    }

    if (posted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Announcement posted successfully.',
          ),
          backgroundColor: primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadData();
    }
  }

  // ============================================================
  // DELETE ANNOUNCEMENT
  // ============================================================

  Future<void> _confirmDelete(
    String announcementId,
    String title,
  ) async {
    if (announcementId.trim().isEmpty) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Delete Announcement?',
          ),
          content: Text(
            'Remove "$title"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _announcementService.deleteAnnouncement(
        announcementId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Announcement deleted.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadData();
    } on AnnouncementServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    String? label,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(
        0xFFF8FAFD,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          13,
        ),
        borderSide: const BorderSide(
          color: Color(
            0xFFE1E5EC,
          ),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          13,
        ),
        borderSide: const BorderSide(
          color: Color(
            0xFFE1E5EC,
          ),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          13,
        ),
        borderSide: const BorderSide(
          color: primaryTeal,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _toDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(
    DateTime date,
  ) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final int hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final String minute = date.minute
        .toString()
        .padLeft(
          2,
          '0',
        );

    final String period =
        date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year} • '
        '$hour:$minute $period';
  }
}