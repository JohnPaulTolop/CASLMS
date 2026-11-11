import '../shared/page_loading_state.dart';
import '../../core/app_colors.dart';
import '../../services/activity_log_service.dart';
import '../../services/course_content_migration_service.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/profile_picture_service.dart';
import 'admin_ai_gateway_page.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  Color get adminTheme => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);
  Color get surface => AppColors.resolve(context, Colors.white);
  Color get green => AppColors.resolve(context, AppColors.green);
  Color get red => AppColors.resolve(context, AppColors.error);
  Color get purple => AppColors.resolve(context, AppColors.purple);
  Color get blueTint => AppColors.resolve(context, AppColors.blueTint);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfilePictureService _profilePictureService = ProfilePictureService();
  late final CourseContentMigrationService _courseContentMigration =
      CourseContentMigrationService(firestore: _firestore, auth: _auth);

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isMigratingCourseContent = false;
  String? _errorMessage;

  Map<String, dynamic>? _adminProfile;

  bool _authConnected = false;
  bool _firestoreConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('No administrator is currently logged in.');
      }

      _authConnected = true;

      final profileDocument = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!profileDocument.exists || profileDocument.data() == null) {
        throw Exception('Administrator profile could not be found.');
      }

      final profile = profileDocument.data()!;

      final role = (profile['role'] ?? '').toString().trim().toLowerCase();

      final status = (profile['status'] ?? '').toString().trim().toLowerCase();

      if (role != 'admin' || status != 'active') {
        throw Exception(
          'This account does not have active administrator access.',
        );
      }

      // Real Firestore health check.
      await _firestore.collection('courses').limit(1).get();

      _firestoreConnected = true;

      if (!mounted) return;

      setState(() {
        _adminProfile = {...profile, 'uid': user.uid};
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _firestoreConnected = false;
        _errorMessage = e.message ?? 'Unable to load platform settings.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _name {
    final String value =
        (_adminProfile?['name'] ?? _auth.currentUser?.displayName ?? '')
            .toString()
            .trim();

    return value.isEmpty ? 'Administrator' : value;
  }

  String get _email {
    final String value = (_adminProfile?['email'] ?? '').toString().trim();

    return value.isEmpty ? 'No contact email' : value;
  }

  String get _campusId {
    final String value = (_adminProfile?['universityId'] ?? '')
        .toString()
        .trim();

    return value.isEmpty ? 'No ID' : value;
  }

  String get _department {
    final String value = (_adminProfile?['department'] ?? '').toString().trim();

    return value.isEmpty ? 'Department not specified' : value;
  }

  String get _photoUrl {
    return (_adminProfile?['photoUrl'] ?? '').toString().trim();
  }

  Future<void> _showEditAdminProfileDialog() async {
    if (_adminProfile == null || _isSaving) {
      return;
    }

    String newName = _name;
    String newEmail = (_adminProfile?['email'] ?? '').toString();

    String newDepartment = (_adminProfile?['department'] ?? '').toString();

    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Administrator Profile',
            style: TextStyle(color: textDark, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: newName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  onChanged: (String value) {
                    newName = value;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: newEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Contact Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  onChanged: (String value) {
                    newEmail = value;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: newDepartment,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                  onChanged: (String value) {
                    newDepartment = value;
                  },
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Campus ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                    helperText:
                        'Campus ID and administrator role are protected.',
                  ),
                  child: Text(
                    _campusId,
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();

                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();

                Navigator.of(dialogContext).pop({
                  'name': newName,
                  'email': newEmail,
                  'department': newDepartment,
                });
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final String cleanName = (result['name'] ?? '').trim();

    final String cleanEmail = (result['email'] ?? '').trim();

    final String cleanDepartment = (result['department'] ?? '').trim();

    if (cleanName.isEmpty) {
      _showError('Full name cannot be empty.');
      return;
    }

    if (cleanEmail.isNotEmpty &&
        (!cleanEmail.contains('@') || !cleanEmail.contains('.'))) {
      _showError('Enter a valid contact email address.');
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showError('You are no longer logged in.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'name': cleanName,
        'email': cleanEmail,
        'department': cleanDepartment,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await user.updateDisplayName(cleanName);
      } catch (_) {
        // Firestore is the source of truth.
      }

      if (!mounted) {
        return;
      }

      // Do not call _loadSettings() immediately after
      // the dialog closes. Update local state instead.
      setState(() {
        _adminProfile = {
          ...?_adminProfile,
          'name': cleanName,
          'email': cleanEmail,
          'department': cleanDepartment,
        };
        _isSaving = false;
      });

      _showMessage('Administrator profile updated.');
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showError(e.message ?? 'Unable to update your profile.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showError('Unable to update your profile.');
    }
  }

  Future<void> _changeProfilePicture() async {
    if (_isUploadingPhoto || _isSaving) {
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final ProfilePictureResult? result = await _profilePictureService
          .pickAndUploadProfilePicture();

      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() {
          _isUploadingPhoto = false;
        });
        return;
      }

      setState(() {
        _adminProfile = {
          ...?_adminProfile,
          'photoUrl': result.photoUrl,
          'photoPath': result.photoPath,
        };
        _isUploadingPhoto = false;
      });

      _showMessage('Administrator profile picture updated.');
    } on ProfilePictureServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUploadingPhoto = false;
      });

      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUploadingPhoto = false;
      });

      _showError('Unable to update your profile picture.');
    }
  }

  Future<void> _removeProfilePicture() async {
    if (_photoUrl.isEmpty || _isUploadingPhoto) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Remove Profile Picture',
            style: TextStyle(fontWeight: FontWeight.w700, color: textDark),
          ),
          content: const Text(
            'Your administrator initials will be shown instead.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      await _profilePictureService.removeProfilePicture();

      if (!mounted) {
        return;
      }

      final Map<String, dynamic> updatedProfile = {...?_adminProfile};

      updatedProfile.remove('photoUrl');
      updatedProfile.remove('photoPath');

      setState(() {
        _adminProfile = updatedProfile;
        _isUploadingPhoto = false;
      });

      _showMessage('Administrator profile picture removed.');
    } on ProfilePictureServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUploadingPhoto = false;
      });

      _showError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isUploadingPhoto = false;
      });

      _showError('Unable to remove your profile picture.');
    }
  }

  Future<void> _logoutAdmin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Log Out Administrator',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text('End this secure administrator session?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ActivityLogService(auth: _auth).signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Unable to log out.'),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _migrateCourseContent() async {
    if (_isMigratingCourseContent) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Migrate course content',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Copy existing modules, materials, assessments, and course events '
          'into the student-safe course structure? Legacy records will remain '
          'unchanged, and this operation can be run again safely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start migration'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isMigratingCourseContent = true);
    try {
      final result = await _courseContentMigration.migrateLegacyContent();
      if (!mounted) return;
      _showMessage(
        'Migration complete: ${result.copied} records copied '
        '(${result.modules} modules, ${result.resources} materials, '
        '${result.assessments} assessments, '
        '${result.calendarEvents} events). '
        '${result.skipped} invalid or schoolwide records skipped.',
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = error.code == 'resource-exhausted'
          ? 'Firestore free-tier quota is currently exhausted. Run the '
                'migration again after the daily quota resets.'
          : error.message ?? 'Course content migration failed.';
      _showError(message);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isMigratingCourseContent = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PageLoadingState();
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
                      title: 'Settings',
                      subtitle: 'Platform configuration, service health, and administrator account.',
                      eyebrow: 'ADMINISTRATION',
                      actions: [
                        IconButton(
                          onPressed: _isLoading ? null : _loadSettings,
                          tooltip: 'Refresh',
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
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: adminTheme));
    }

    if (_errorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: WorkspaceErrorState(
          message: _errorMessage!,
          onRetry: _loadSettings,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSettings,
      color: adminTheme,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 40),
        children: [
          _buildAdminAccount(),
          const SizedBox(height: 24),
          const WorkspaceSectionHeading(
            title: 'Core services',
            subtitle: 'Live infrastructure connectivity checks.',
          ),
          const SizedBox(height: 14),
          _buildStatusTile(
            title: 'Firebase Authentication',
            subtitle: _authConnected
                ? 'Administrator session is authenticated.'
                : 'No authenticated Firebase session.',
            icon: Icons.verified_user_outlined,
            connected: _authConnected,
          ),
          _buildStatusTile(
            title: 'Cloud Firestore',
            subtitle: _firestoreConnected
                ? 'Database read health check succeeded.'
                : 'Firestore health check failed.',
            icon: Icons.cloud_done_outlined,
            connected: _firestoreConnected,
          ),
          const SizedBox(height: 14),
          _buildActionTile(
            title: 'Firebase AI Gateway',
            subtitle: 'Open real AI processing status, multi-provider routing, and vector sync.',
            icon: Icons.auto_awesome_rounded,
            color: purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAIGatewayScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          _buildSecurityNotice(),
          const SizedBox(height: 28),
          const WorkspaceSectionHeading(
            title: 'Course data migration',
            subtitle:
                'Copy legacy course content into student-safe scoped paths.',
          ),
          const SizedBox(height: 14),
          _buildActionTile(
            title: _isMigratingCourseContent
                ? 'Migrating course content…'
                : 'Migrate existing course content',
            subtitle: _isMigratingCourseContent
                ? 'Keep this page open until all records are copied.'
                : 'Safe and repeatable. Existing instructor records are not deleted.',
            icon: _isMigratingCourseContent
                ? Icons.sync_rounded
                : Icons.account_tree_outlined,
            color: adminTheme,
            onTap: _migrateCourseContent,
          ),
          const SizedBox(height: 18),
          const WorkspaceSectionHeading(
            title: 'Administrator session',
            subtitle: 'Manage your active Firebase authentication session.',
          ),
          const SizedBox(height: 14),
          _buildActionTile(
            title: 'Log Out Administrator',
            subtitle: 'End the current Firebase Authentication session.',
            icon: Icons.logout_rounded,
            color: red,
            onTap: _logoutAdmin,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccount() {
    final String status = (_adminProfile?['status'] ?? 'active').toString();

    return WorkspaceSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _buildAdminAvatar(),
                  Material(
                    color: adminTheme,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _isUploadingPhoto ? null : _changeProfilePicture,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: _isUploadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _name,
                            style: TextStyle(
                              color: textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: green.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _capitalize(status),
                            style: TextStyle(
                              color: green,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Campus ID: $_campusId  •  $_email',
                      style: TextStyle(color: textGrey, fontSize: 13),
                    ),
                    if (_department.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _department,
                        style: TextStyle(color: textGrey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _showEditAdminProfileDialog,
                icon: const Icon(Icons.manage_accounts_outlined, size: 17),
                label: const Text('Edit profile'),
              ),
              OutlinedButton.icon(
                onPressed: _isUploadingPhoto ? null : _changeProfilePicture,
                icon: const Icon(Icons.photo_camera_outlined, size: 17),
                label: Text(
                  _photoUrl.isEmpty ? 'Upload picture' : 'Change picture',
                ),
              ),
              if (_photoUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: _removeProfilePicture,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: red,
                  ),
                  label: Text('Remove picture', style: TextStyle(color: red)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAvatar() {
    if (_photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _photoUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return _buildAdminInitialAvatar();
              },
        ),
      );
    }

    return _buildAdminInitialAvatar();
  }

  Widget _buildAdminInitialAvatar() {
    return CircleAvatar(
      radius: 26,
      backgroundColor: adminTheme.withValues(alpha: 0.10),
      child: Text(
        _initials(_name),
        style: TextStyle(color: adminTheme, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildStatusTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool connected,
  }) {
    final color = connected ? green : red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WorkspaceSurface(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              connected ? Icons.check_circle_rounded : Icons.error_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WorkspaceSurface(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(color: textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: textGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return WorkspaceSurface(
      padding: const EdgeInsets.all(16),
      color: AppColors.resolve(context, AppColors.noticeboard),
      borderColor: AppColors.resolve(context, AppColors.noticeboard),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: purple, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'API keys and Firebase service credentials are intentionally managed in the Firebase and Supabase consoles for platform security. Secret configuration is never exposed in the client UI.',
              style: TextStyle(color: textDark, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: adminTheme,
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

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'A';
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _capitalize(String value) {
    final clean = value.trim().toLowerCase();

    if (clean.isEmpty) return clean;

    return '${clean[0].toUpperCase()}${clean.substring(1)}';
  }
}
