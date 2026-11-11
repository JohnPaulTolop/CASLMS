import '../../core/app_colors.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';

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
  Color get adminTheme => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);
  Color get surface => AppColors.resolve(context, Colors.white);
  Color get green => AppColors.resolve(context, AppColors.green);
  Color get red => AppColors.resolve(context, AppColors.error);
  Color get orange => AppColors.resolve(context, AppColors.amber);
  Color get blueTint => AppColors.resolve(context, AppColors.blueTint);

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
                style: TextStyle(fontWeight: FontWeight.w700),
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
    final width = MediaQuery.sizeOf(context).width;
    final inset = workspaceInset(width);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: WorkspaceScrollingBody(
              header: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 0),
                    child: WorkspaceHeading(
                      showEyebrow: false,
                      title: 'Instructor approvals',
                      subtitle: 'Verify and review SSU faculty registration applications.',
                      eyebrow: 'ADMINISTRATION',
                      actions: [
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => setState(() {}),
                          icon: Icon(Icons.refresh_rounded, color: textDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              body: _buildBody(inset),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double inset) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _applicationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: adminTheme));
        }

        if (snapshot.hasError) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: WorkspaceErrorState(
              message:
                  'Unable to load instructor applications.\n${snapshot.error}',
              onRetry: () => setState(() {}),
            ),
          );
        }

        final applications = (snapshot.data?.docs ?? const []).map((document) {
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
            padding: EdgeInsets.fromLTRB(inset, 0, inset, 100),
            children: [
              _buildSummary(pendingCount, applications.length),
              const SizedBox(height: 20),
              _buildFilters(),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                WorkspaceEmptyState(
                  title: 'No applications found',
                  message:
                      'No instructor applications match the "${_capitalize(_selectedStatus)}" status.',
                  icon: Icons.how_to_reg_outlined,
                )
              else
                ...filtered.map(_buildApplicationCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(int pendingCount, int totalCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stats = [
          (
            Icons.pending_actions_rounded,
            '$pendingCount',
            'Pending review',
            orange,
            AppColors.resolve(context, AppColors.amberTint),
          ),
          (
            Icons.how_to_reg_rounded,
            '$totalCount',
            'Total applications',
            adminTheme,
            blueTint,
          ),
        ];
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 500 * scale ? 2 : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: WorkspaceSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          WorkspaceIconTile(
                            icon: stat.$1,
                            color: stat.$4,
                            background: stat.$5,
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stat.$2,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        stat.$3,
                        style: TextStyle(fontSize: 12, color: textGrey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
              selectedColor: adminTheme.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: selected ? adminTheme : textGrey,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: selected ? adminTheme : borderColor),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkspaceSurface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: adminTheme.withValues(alpha: 0.10),
                  child: Text(
                    _initials(_name(application)),
                    style: TextStyle(
                      color: adminTheme,
                      fontWeight: FontWeight.w700,
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
                        style: TextStyle(
                          color: textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _email(application),
                        style: TextStyle(color: textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 14),
            _detailRow('Faculty ID', _facultyId(application)),
            _detailRow(
              'Department',
              _valueOrDefault(application['department']),
            ),
            _detailRow(
              'Position / Program',
              _valueOrDefault(application['course']),
            ),
            _detailRow(
              'Submitted',
              _formatTimestamp(application['submittedAt']),
            ),
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
                  style: TextStyle(color: red, fontSize: 12, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (busy)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    color: adminTheme,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else if (pending)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _viewFacultyId(application),
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('View Faculty ID'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _denyInstructor(application),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: red,
                      side: BorderSide(color: red.withValues(alpha: 0.5)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Deny'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _approveInstructor(application),
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Approve'),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: () => _viewFacultyId(application),
                icon: const Icon(Icons.visibility_outlined, size: 17),
                label: const Text('View Submitted Faculty ID'),
              ),
          ],
        ),
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
            width: 125,
            child: Text(
              label,
              style: TextStyle(
                color: textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textDark,
                fontSize: 12,
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
          fontSize: 10,
          fontWeight: FontWeight.w700,
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
    final surface = AppColors.resolve(context, Colors.white);
    final textDark = AppColors.resolve(context, AppColors.darkText);

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Deny Application',
        style: TextStyle(fontWeight: FontWeight.w700, color: textDark),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explain why ${widget.instructorName} was not approved.',
              style: TextStyle(color: textDark),
            ),
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
        FilledButton(
          onPressed: () {
            final String reason = _reasonController.text.trim();

            if (reason.isEmpty) {
              return;
            }

            Navigator.of(context).pop(reason);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Deny Application'),
        ),
      ],
    );
  }
}
