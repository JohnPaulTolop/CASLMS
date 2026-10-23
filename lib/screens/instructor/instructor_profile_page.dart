import '../../services/activity_log_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import '../../services/password_reset_service.dart';
import '../../services/profile_picture_service.dart';

class InstructorProfileScreen extends StatefulWidget {
  const InstructorProfileScreen({super.key});

  @override
  State<InstructorProfileScreen> createState() =>
      _InstructorProfileScreenState();
}

class _InstructorProfileScreenState extends State<InstructorProfileScreen> {
  // ============================================================
  // CASLMS DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color blue = Color(0xFF1769FF);
  static const Color green = Color(0xFF26A65B);
  static const Color red = Color(0xFFFF4B4B);

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfilePictureService _profilePictureService = ProfilePictureService();
  final PasswordResetService _passwordResetService = PasswordResetService();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isRequestingPasswordReset = false;
  String? _errorMessage;

  Map<String, dynamic>? _profile;
  int _activeClasses = 0;
  int _totalStudents = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD REAL PROFILE + REAL INSTRUCTOR STATS
  // ============================================================

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('You are not currently logged in.');
      }

      final DocumentSnapshot<Map<String, dynamic>> profileDocument =
          await _firestore.collection('users').doc(user.uid).get();

      if (!profileDocument.exists || profileDocument.data() == null) {
        throw Exception('Instructor profile could not be found.');
      }

      final Map<String, dynamic> profileData = profileDocument.data()!;

      final String role = (profileData['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (role != 'instructor') {
        throw Exception('This account is not an instructor account.');
      }

      final QuerySnapshot<Map<String, dynamic>> courseSnapshot =
          await _firestore
              .collection('courses')
              .where('instructorId', isEqualTo: user.uid)
              .get();

      final List<String> activeCourseIds = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in courseSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String status = (data['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

        if (status == 'active') {
          activeCourseIds.add(document.id);
        }
      }

      final Set<String> activeStudentIds = {};

      for (final String courseId in activeCourseIds) {
        final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
            await _firestore
                .collection('enrollments')
                .where('courseId', isEqualTo: courseId)
                .get();

        for (final QueryDocumentSnapshot<Map<String, dynamic>> document
            in enrollmentSnapshot.docs) {
          final Map<String, dynamic> enrollment = document.data();

          final String status = (enrollment['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          final String studentId = (enrollment['studentId'] ?? '')
              .toString()
              .trim();

          if (status == 'active' && studentId.isNotEmpty) {
            activeStudentIds.add(studentId);
          }
        }
      }

      final int totalStudents = activeStudentIds.length;

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = {...profileData, 'uid': user.uid};

        _activeClasses = activeCourseIds.length;
        _totalStudents = totalStudents;
        _isLoading = false;
        _errorMessage = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Unable to load your instructor profile.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // REAL PROFILE VALUES
  // ============================================================

  String get _name {
    final String value =
        (_profile?['name'] ?? _auth.currentUser?.displayName ?? '')
            .toString()
            .trim();

    return value.isEmpty ? 'Instructor' : value;
  }

  String get _department {
    final String value = (_profile?['department'] ?? '').toString().trim();

    return value.isEmpty ? 'Department not specified' : value;
  }

  String get _facultyId {
    final String value = (_profile?['universityId'] ?? '').toString().trim();

    return value.isEmpty ? 'Not set' : value;
  }

  String get _email {
    final String value = (_profile?['email'] ?? '').toString().trim();

    return value.isEmpty ? 'Not set' : value;
  }

  String get _status {
    final String value = (_profile?['status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();

    return value.isEmpty ? 'active' : value;
  }

  String get _photoUrl {
    return (_profile?['photoUrl'] ?? '').toString().trim();
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
        _profile = {
          ...?_profile,
          'photoUrl': result.photoUrl,
          'photoPath': result.photoPath,
        };
        _isUploadingPhoto = false;
      });

      _showMessage('Profile picture updated.');
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
          title: const Text(
            'Remove Profile Picture',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text('Your initials will be shown instead.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
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

      final Map<String, dynamic> updatedProfile = {...?_profile};

      updatedProfile.remove('photoUrl');
      updatedProfile.remove('photoPath');

      setState(() {
        _profile = updatedProfile;
        _isUploadingPhoto = false;
      });

      _showMessage('Profile picture removed.');
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

  String get _initials {
    final List<String> parts = _name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'I';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // ============================================================
  // EDIT PERSONAL INFORMATION
  //
  // IMPORTANT:
  // universityId, role, status and authEmail are intentionally
  // not editable here because they are protected identity fields.
  // ============================================================

  Future<void> _showEditProfileDialog() async {
    if (_profile == null || _isSaving) {
      return;
    }

    String newName = _name;
    String newEmail = (_profile?['email'] ?? '').toString();

    String newDepartment = (_profile?['department'] ?? '').toString();

    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Personal Information',
            style: TextStyle(color: textDark, fontWeight: FontWeight.w800),
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
                    labelText: 'Faculty ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                    helperText: 'Faculty ID is managed by the administrator.',
                  ),
                  child: Text(
                    _facultyId,
                    style: const TextStyle(
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
            ElevatedButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();

                Navigator.of(dialogContext).pop({
                  'name': newName,
                  'email': newEmail,
                  'department': newDepartment,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
              ),
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
        // Firestore remains the source of truth.
      }

      if (!mounted) {
        return;
      }

      // Avoid immediately rebuilding the whole profile while the
      // dialog route is still being removed from Flutter's tree.
      setState(() {
        _profile = {
          ...?_profile,
          'name': cleanName,
          'email': cleanEmail,
          'department': cleanDepartment,
        };
        _isSaving = false;
      });

      _showMessage('Profile updated successfully.');
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

  // ============================================================
  // ACCOUNT DETAILS
  // ============================================================

  Future<void> _showAccountDetails() async {
    if (_profile == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Account Details',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _buildDetailRow(Icons.badge_outlined, 'Faculty ID', _facultyId),
                _buildDetailRow(Icons.email_outlined, 'Contact Email', _email),
                _buildDetailRow(
                  Icons.apartment_rounded,
                  'Department',
                  _department,
                ),
                _buildDetailRow(
                  Icons.admin_panel_settings_outlined,
                  'Role',
                  'Instructor',
                ),
                _buildDetailRow(
                  Icons.verified_user_outlined,
                  'Account Status',
                  _capitalize(_status),
                  valueColor: _status == 'active' ? green : red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<void> _requestPasswordReset() async {
    if (_profile == null || _isRequestingPasswordReset || _isSaving) {
      return;
    }

    final String campusId = _facultyId;
    final String registeredEmail = _email;

    if (campusId == 'Not set' || registeredEmail == 'Not set') {
      _showError(
        'Your faculty ID or registered email is missing. '
        'Please update your profile or contact the administrator.',
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: primaryTeal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reset Password',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CASLMS will send a secure password reset link to your registered email:',
                style: TextStyle(color: textGrey, height: 1.45),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: primaryTeal,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        registeredEmail,
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The link will work on both web and mobile. Check your spam folder if the email does not appear.',
                style: TextStyle(color: textGrey, fontSize: 12, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isRequestingPasswordReset = true;
    });

    try {
      final String message = await _passwordResetService.requestPasswordReset(
        campusId: campusId,
        email: registeredEmail,
      );

      if (!mounted) {
        return;
      }

      _showMessage(message);
    } on PasswordResetException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('Unable to request a password reset. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPasswordReset = false;
        });
      }
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _showLogoutDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(color: textDark, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Are you sure you want to log out of your CASLMS account?',
            style: TextStyle(color: textGrey, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
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

    if (confirmed != true) {
      return;
    }

    try {
      await ActivityLogService(auth: _auth).signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showError(e.message ?? 'Unable to log out.');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return instructorScaffold(
      context: context,
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Instructor Profile',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadProfile,
            tooltip: 'Refresh Profile',
            icon: const Icon(Icons.refresh_rounded, color: textDark),
          ),
          IconButton(
            onPressed: _isLoading ? null : _showAccountDetails,
            tooltip: 'Account Details',
            icon: const Icon(Icons.settings_outlined, color: textDark),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryTeal));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_profile == null) {
      return _buildErrorState(message: 'Instructor profile is unavailable.');
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: primaryTeal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 30),
            _buildStats(),
            const SizedBox(height: 28),
            _buildAccountMenu(),
            const SizedBox(height: 22),
            _buildLogoutCard(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryTeal, width: 2),
              ),
              child: _buildProfileAvatar(),
            ),
            Material(
              color: primaryTeal,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _isUploadingPhoto ? null : _changeProfilePicture,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: _isUploadingPhoto
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isUploadingPhoto ? null : _changeProfilePicture,
          icon: const Icon(Icons.photo_camera_outlined, size: 17),
          label: Text(
            _photoUrl.isEmpty
                ? 'Upload Profile Picture'
                : 'Change Profile Picture',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: textDark,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _department,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: textGrey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryTeal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Samar State University',
            style: TextStyle(
              color: primaryTeal,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    if (_photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _photoUrl,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return _buildInitialAvatar();
              },
        ),
      );
    }

    return _buildInitialAvatar();
  }

  Widget _buildInitialAvatar() {
    return CircleAvatar(
      radius: 48,
      backgroundColor: primaryTeal.withValues(alpha: 0.10),
      child: Text(
        _initials,
        style: const TextStyle(
          color: primaryTeal,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // REAL STATS
  // ============================================================

  Widget _buildStats() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 520;

        final Widget classesCard = _buildInfoCard(
          title: 'Active Classes',
          value: '$_activeClasses',
          icon: Icons.class_outlined,
          color: primaryTeal,
        );

        final Widget studentsCard = _buildInfoCard(
          title: 'Active Students',
          value: '$_totalStudents',
          icon: Icons.groups_outlined,
          color: blue,
        );

        final Widget idCard = _buildInfoCard(
          title: 'Faculty ID',
          value: _facultyId,
          icon: Icons.badge_outlined,
          color: green,
        );

        if (compact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: classesCard),
                  const SizedBox(width: 12),
                  Expanded(child: studentsCard),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: idCard),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: classesCard),
            const SizedBox(width: 14),
            Expanded(child: studentsCard),
            const SizedBox(width: 14),
            Expanded(child: idCard),
          ],
        );
      },
    );
  }

  // ============================================================
  // ACCOUNT MENU
  // ============================================================

  Widget _buildAccountMenu() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildMenuTile(
            icon: Icons.account_circle_outlined,
            title: 'Personal Information',
            subtitle: 'Update your name, email, and department',
            onTap: _showEditProfileDialog,
          ),
          _buildDivider(),
          _buildMenuTile(
            icon: Icons.photo_camera_outlined,
            title: _photoUrl.isEmpty
                ? 'Upload Profile Picture'
                : 'Change Profile Picture',
            subtitle: 'JPG, JPEG, PNG, or WEBP up to 5 MB',
            onTap: _changeProfilePicture,
          ),
          if (_photoUrl.isNotEmpty) ...[
            _buildDivider(),
            _buildMenuTile(
              icon: Icons.delete_outline_rounded,
              title: 'Remove Profile Picture',
              subtitle: 'Show your initials instead',
              onTap: _removeProfilePicture,
            ),
          ],
          _buildDivider(),
          _buildMenuTile(
            icon: Icons.badge_outlined,
            title: 'Account Details',
            subtitle: 'Faculty ID, role, and account status',
            onTap: _showAccountDetails,
          ),
          _buildDivider(),
          _buildMenuTile(
            icon: Icons.lock_reset_rounded,
            title: _isRequestingPasswordReset
                ? 'Sending Reset Link...'
                : 'Reset Password',
            subtitle: 'Send a secure reset link to your registered email',
            onTap: _requestPasswordReset,
          ),
          _buildDivider(),
          _buildMenuTile(
            icon: Icons.refresh_rounded,
            title: 'Refresh Profile',
            subtitle: 'Reload your latest Firebase account data',
            onTap: _loadProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      decoration: _cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: red.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.logout_rounded, color: red, size: 20),
        ),
        title: const Text(
          'Log Out',
          style: TextStyle(
            color: red,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: const Text(
          'Sign out of this instructor account',
          style: TextStyle(color: textGrey, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF9BA4B4),
        ),
        onTap: _showLogoutDialog,
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 11),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textGrey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primaryTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primaryTeal, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: textDark,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: textGrey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF9BA4B4),
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: primaryTeal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF0F2F5),
      indent: 68,
      endIndent: 20,
    );
  }

  Widget _buildErrorState({String? message}) {
    final String text =
        message ?? _errorMessage ?? 'Unable to load your profile.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: red, size: 50),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textGrey,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
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
        backgroundColor: primaryTeal,
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
