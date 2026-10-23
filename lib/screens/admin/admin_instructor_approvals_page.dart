import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/instructor_approval_service.dart';

class AdminInstructorApprovalsScreen extends StatefulWidget {
  const AdminInstructorApprovalsScreen({super.key, this.applicationId = ''});
  final String applicationId;

  @override
  State<AdminInstructorApprovalsScreen> createState() =>
      _AdminInstructorApprovalsScreenState();
}

class _AdminInstructorApprovalsScreenState
    extends State<AdminInstructorApprovalsScreen> {
  static const Color adminTheme = Color(0xFF4F46E5);

  static const Color background = Color(0xFFF8F9FA);

  static const Color textDark = Color(0xFF10182F);

  static const Color textGrey = Color(0xFF68738A);

  static const Color borderColor = Color(0xFFE6EAF0);

  static const Color green = Color(0xFF26A65B);

  static const Color red = Color(0xFFFF4B4B);

  static const Color orange = Color(0xFFFF9418);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final InstructorApprovalService _approvalService =
      InstructorApprovalService();

  final Set<String> _busyApplicants = <String>{};

  String _selectedStatus = 'pending';

  Stream<QuerySnapshot<Map<String, dynamic>>> _applicationsStream() {
    return _firestore
        .collection('instructorApplications')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  bool _isBusy(String applicantId) {
    return _busyApplicants.contains(applicantId);
  }

  void _setBusy(String applicantId, bool busy) {
    if (!mounted) {
      return;
    }

    setState(() {
      if (busy) {
        _busyApplicants.add(applicantId);
      } else {
        _busyApplicants.remove(applicantId);
      }
    });
  }

  Future<void> _viewFacultyId(Map<String, dynamic> application) async {
    final String applicantId = _applicantId(application);

    if (applicantId.isEmpty || _isBusy(applicantId)) {
      return;
    }

    _setBusy(applicantId, true);

    try {
      await _approvalService.openFacultyId(applicantId);
    } on InstructorApprovalException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Unable to open the faculty ID.');
    } finally {
      _setBusy(applicantId, false);
    }
  }

  Future<void> _approveInstructor(Map<String, dynamic> application) async {
    final String applicantId = _applicantId(application);

    if (applicantId.isEmpty || _isBusy(applicantId)) {
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text(
                'Approve Instructor',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Text(
                'Approve ${_name(application)} as a CASLMS instructor?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    _setBusy(applicantId, true);

    try {
      final InstructorReviewResult result = await _approvalService
          .approveInstructor(applicantId);

      if (!mounted) {
        return;
      }

      if (result.emailSent) {
        _showMessage(
          '${_name(application)} was approved and notified by email.',
        );
      } else {
        _showWarning(
          '${_name(application)} was approved, but the email could not be sent.',
        );
      }
    } on InstructorApprovalException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Unable to approve the instructor.');
    } finally {
      _setBusy(applicantId, false);
    }
  }

  Future<void> _denyInstructor(Map<String, dynamic> application) async {
    final String applicantId = _applicantId(application);

    if (applicantId.isEmpty || _isBusy(applicantId)) {
      return;
    }

    final String? reason = await showDialog<String>(
      context: context,
      builder: (_) {
        return _DenialReasonDialog(instructorName: _name(application));
      },
    );

    if (reason == null || reason.trim().isEmpty || !mounted) {
      return;
    }

    _setBusy(applicantId, true);

    try {
      final InstructorReviewResult result = await _approvalService
          .denyInstructor(applicantId: applicantId, reason: reason);

      if (!mounted) {
        return;
      }

      if (result.emailSent) {
        _showMessage('${_name(application)} was denied and notified by email.');
      } else {
        _showWarning(
          'The application was denied, but the email could not be sent.',
        );
      }
    } on InstructorApprovalException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Unable to deny the instructor application.');
    } finally {
      _setBusy(applicantId, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        elevation: 0,
        titleSpacing: 24,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructor Approvals',
              style: TextStyle(
                color: textDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Verify faculty registration requests',
              style: TextStyle(
                color: textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _applicationsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: adminTheme),
              );
            }

            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            final applications = (snapshot.data?.docs ?? const []).map((
              document,
            ) {
              return <String, dynamic>{...document.data(), 'id': document.id};
            }).toList();

            final pendingCount = applications.where((application) {
              return _status(application) == 'pending';
            }).length;

            final filtered = applications.where((application) {
              return widget.applicationId.isNotEmpty
                  ? application['id'] == widget.applicationId
                  : _status(application) == _selectedStatus;
            }).toList();

            return RefreshIndicator(
              onRefresh: () async {
                await _firestore
                    .collection('instructorApplications')
                    .limit(1)
                    .get();
              },
              color: adminTheme,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: [
                  _buildSummary(pendingCount, applications.length),
                  const SizedBox(height: 18),
                  _buildFilters(),
                  const SizedBox(height: 18),
                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ...filtered.map(_buildApplicationCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummary(int pendingCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6D63F1)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.how_to_reg_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pendingCount pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalCount total instructor applications',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const statuses = ['pending', 'approved', 'denied'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final bool selected = _selectedStatus == status;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text(_capitalize(status)),
              selectedColor: adminTheme.withValues(alpha: 0.14),
              labelStyle: TextStyle(
                color: selected ? adminTheme : textGrey,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedStatus = status;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final String applicantId = _applicantId(application);

    final String status = _status(application);

    final bool pending = status == 'pending';

    final bool busy = _isBusy(applicantId);

    final String denialReason = (application['denialReason'] ?? '')
        .toString()
        .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: pending ? orange.withValues(alpha: 0.35) : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: adminTheme.withValues(alpha: 0.10),
                child: Text(
                  _initials(_name(application)),
                  style: const TextStyle(
                    color: adminTheme,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name(application),
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _email(application),
                      style: const TextStyle(color: textGrey, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow('Faculty ID', _facultyId(application)),
          _detailRow('Department', _valueOrDefault(application['department'])),
          _detailRow(
            'Position / Program',
            _valueOrDefault(application['course']),
          ),
          _detailRow('Submitted', _formatTimestamp(application['submittedAt'])),
          if (denialReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Reason: $denialReason',
                style: const TextStyle(color: red, fontSize: 11.5, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  color: adminTheme,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (pending)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _viewFacultyId(application);
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Faculty ID'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _denyInstructor(application);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: red,
                          side: const BorderSide(color: red),
                        ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Deny'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _approveInstructor(application);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: () {
                _viewFacultyId(application);
              },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View Submitted Faculty ID'),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: textDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final Color color = status == 'approved'
        ? green
        : status == 'denied'
        ? red
        : orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        _capitalize(status),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.assignment_turned_in_outlined, color: textGrey, size: 48),
          SizedBox(height: 12),
          Text(
            'No applications found',
            style: TextStyle(color: textGrey, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: red, size: 50),
            const SizedBox(height: 12),
            const Text(
              'Unable to load instructor applications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textDark, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textGrey, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  String _applicantId(Map<String, dynamic> application) {
    return (application['applicantId'] ?? application['id'] ?? '')
        .toString()
        .trim();
  }

  String _name(Map<String, dynamic> application) {
    final String name = (application['name'] ?? '').toString().trim();

    return name.isEmpty ? 'Unnamed Instructor' : name;
  }

  String _email(Map<String, dynamic> application) {
    return _valueOrDefault(application['email']);
  }

  String _facultyId(Map<String, dynamic> application) {
    return _valueOrDefault(application['universityId']);
  }

  String _status(Map<String, dynamic> application) {
    return (application['status'] ?? 'pending').toString().trim().toLowerCase();
  }

  String _valueOrDefault(dynamic value) {
    final String text = (value ?? '').toString().trim();

    return text.isEmpty ? 'Not provided' : text;
  }

  String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatTimestamp(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) {
      return 'Not available';
    }

    final DateTime local = date.toLocal();

    final String month = local.month.toString().padLeft(2, '0');

    final String day = local.day.toString().padLeft(2, '0');

    final String hour = local.hour.toString().padLeft(2, '0');

    final String minute = local.minute.toString().padLeft(2, '0');

    return '$month/$day/${local.year} $hour:$minute';
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showWarning(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DenialReasonDialog extends StatefulWidget {
  const _DenialReasonDialog({required this.instructorName});

  final String instructorName;

  @override
  State<_DenialReasonDialog> createState() => _DenialReasonDialogState();
}

class _DenialReasonDialogState extends State<_DenialReasonDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Deny Application',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explain why ${widget.instructorName} was not approved.'),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter the reason for denial',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final String reason = _reasonController.text.trim();

            if (reason.isEmpty) {
              return;
            }

            Navigator.of(context).pop(reason);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4B4B),
            foregroundColor: Colors.white,
          ),
          child: const Text('Deny Application'),
        ),
      ],
    );
  }
}
