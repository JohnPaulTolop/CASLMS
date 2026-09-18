import 'package:flutter/material.dart';

import '../../services/course_invitation_service.dart';

class StudentCourseInvitationsScreen extends StatefulWidget {
  const StudentCourseInvitationsScreen({super.key});

  @override
  State<StudentCourseInvitationsScreen> createState() =>
      _StudentCourseInvitationsScreenState();
}

class _StudentCourseInvitationsScreenState
    extends State<StudentCourseInvitationsScreen> {
  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color background = Color(0xFFF8FAFD);
  static const Color textDark = Color(0xFF111827);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5EAF0);
  static const Color green = Color(0xFF25A55F);
  static const Color red = Color(0xFFFF4B4B);

  final CourseInvitationService _service = CourseInvitationService();
  final Set<String> _busyInvitationIds = {};

  bool _isLoading = true;
  bool _changed = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final invitations = await _service.getMyPendingInvitations();
      if (!mounted) return;
      setState(() {
        _invitations = invitations;
        _isLoading = false;
      });
    } on CourseInvitationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load your course invitations.';
        _isLoading = false;
      });
    }
  }

  Future<void> _respond(
    Map<String, dynamic> invitation, {
    required bool accept,
  }) async {
    final invitationId = (invitation['invitationId'] ?? invitation['id'] ?? '')
        .toString();
    if (invitationId.isEmpty || _busyInvitationIds.contains(invitationId)) {
      return;
    }

    if (!accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Decline invitation?'),
          content: Text(
            'You will not be enrolled in '
            '${(invitation['courseTitle'] ?? 'this course').toString()}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Invitation'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: red),
              child: const Text('Decline'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busyInvitationIds.add(invitationId));

    try {
      if (accept) {
        await _service.acceptInvitation(invitationId);
      } else {
        await _service.declineInvitation(invitationId);
      }

      if (!mounted) return;
      _changed = true;
      setState(() {
        _busyInvitationIds.remove(invitationId);
        _invitations.removeWhere(
          (item) =>
              (item['invitationId'] ?? item['id'] ?? '').toString() ==
              invitationId,
        );
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Invitation accepted. The course is now in My Classes.'
                  : 'Invitation declined.',
            ),
            backgroundColor: accept ? green : textGrey,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } on CourseInvitationException catch (error) {
      if (!mounted) return;
      setState(() => _busyInvitationIds.remove(invitationId));
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyInvitationIds.remove(invitationId));
      _showError('Unable to answer this invitation.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text(
          'Course Invitations',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadInvitations,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryBlue,
        onRefresh: _loadInvitations,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth >= 800 ? 48 : 20,
                vertical: 20,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: _buildContent(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 420,
        child: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 420,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: red, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadInvitations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.white, size: 34),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified enrollment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Only invitations sent to your registered Campus ID appear here.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${_invitations.length} pending '
          '${_invitations.length == 1 ? 'invitation' : 'invitations'}',
          style: const TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (_invitations.isEmpty)
          _buildEmptyState()
        else
          ..._invitations.map(_buildInvitationCard),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.mark_email_read_outlined, color: primaryBlue, size: 48),
          SizedBox(height: 13),
          Text(
            'No pending invitations',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your instructor must invite your registered Campus ID before you can enroll.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textGrey, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invitation) {
    final invitationId = (invitation['invitationId'] ?? invitation['id'] ?? '')
        .toString();
    final courseCode = (invitation['courseCode'] ?? '').toString().trim();
    final courseTitle = (invitation['courseTitle'] ?? 'Course')
        .toString()
        .trim();
    final instructorName = (invitation['instructorName'] ?? 'Instructor')
        .toString()
        .trim();
    final busy = _busyInvitationIds.contains(invitationId);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_outlined, color: primaryBlue),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (courseCode.isNotEmpty)
                      Text(
                        courseCode,
                        style: const TextStyle(
                          color: primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      courseTitle,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Invited by $instructorName',
                      style: const TextStyle(color: textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _respond(invitation, accept: false),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => _respond(invitation, accept: true),
                  icon: busy
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(busy ? 'Processing...' : 'Accept & Enroll'),
                  style: FilledButton.styleFrom(backgroundColor: primaryBlue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
