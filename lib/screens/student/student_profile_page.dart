import 'student_profile_editor.dart';
import '../../services/activity_log_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/password_reset_service.dart';
import '../../services/profile_picture_service.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  // ============================================================
  // CASLMS DESIGN SYSTEM
  // ============================================================

  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color darkText = Color(0xFF10182F);
  static const Color greyText = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color orange = Color(0xFFFF9418);
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

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD REAL STUDENT PROFILE + ENROLLMENT COUNT
  // ============================================================

  Future<void> _loadProfile() async {
    if (_isSaving || _isUploadingPhoto || _isRequestingPasswordReset) return;
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
        throw Exception('Student profile could not be found.');
      }

      final Map<String, dynamic> profileData = profileDocument.data()!;

      final String role = (profileData['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (role != 'student') {
        throw Exception('This account is not a student account.');
      }

      final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where('studentId', isEqualTo: user.uid)
              .get();

      int activeClasses = 0;

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in enrollmentSnapshot.docs) {
        final String status = (document.data()['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status == 'active') {
          activeClasses++;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = {...profileData, 'uid': user.uid};

        _activeClasses = activeClasses;
        _isLoading = false;
        _errorMessage = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Unable to load your student profile.';
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
        (_profile?['displayName'] ??
                _profile?['name'] ??
                _auth.currentUser?.displayName ??
                '')
            .toString()
            .trim();

    return value.isEmpty ? 'Student' : value;
  }

  String get _course {
    final String value = (_profile?['course'] ?? '').toString().trim();

    return value.isEmpty ? 'Course not specified' : value;
  }

  String get _department {
    final String value = (_profile?['department'] ?? '').toString().trim();

    return value.isEmpty ? 'Department not specified' : value;
  }

  String get _studentId {
    final String value = (_profile?['universityId'] ?? '').toString().trim();

    return value.isEmpty ? 'Not set' : value;
  }

  String get _email {
    final String value = (_profile?['email'] ?? '').toString().trim();

    return value.isEmpty ? 'Not set' : value;
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
      return 'S';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // ============================================================
  // PASSWORD RESET
  // Uses the registered, verified email rather than an unsaved form value.
  // ============================================================

  Future<void> _requestPasswordReset() async {
    if (_profile == null || _isRequestingPasswordReset || _isSaving) {
      return;
    }

    final String campusId = _studentId;
    final String registeredEmail = _email;

    if (campusId == 'Not set' || registeredEmail == 'Not set') {
      _showError(
        'Your student ID or registered email is missing. '
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
              Icon(Icons.lock_reset_rounded, color: primaryBlue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reset Password',
                  style: TextStyle(
                    color: darkText,
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
                style: TextStyle(color: greyText, height: 1.45),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        registeredEmail,
                        style: const TextStyle(
                          color: darkText,
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
                style: TextStyle(color: greyText, fontSize: 12, height: 1.4),
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
                backgroundColor: primaryBlue,
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
            style: TextStyle(color: darkText, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Are you sure you want to log out of your CASLMS account?',
            style: TextStyle(color: greyText, height: 1.45),
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
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadProfile,
            tooltip: 'Refresh Profile',
            icon: const Icon(Icons.refresh_rounded, color: darkText),
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
      return const Center(child: CircularProgressIndicator(color: primaryBlue));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_profile == null) {
      return _buildErrorState(message: 'Student profile is unavailable.');
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: primaryBlue,
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
                border: Border.all(color: primaryBlue, width: 2),
              ),
              child: _buildProfileAvatar(),
            ),
            Material(
              color: primaryBlue,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _isUploadingPhoto || _isSaving
                    ? null
                    : _changeProfilePicture,
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
          onPressed: _isUploadingPhoto || _isSaving
              ? null
              : _changeProfilePicture,
          icon: const Icon(Icons.photo_camera_outlined, size: 17),
          label: Text(
            _photoUrl.isEmpty
                ? 'Upload Profile Picture'
                : 'Change Profile Picture',
          ),
        ),
        if (_photoUrl.isNotEmpty)
          TextButton(
            onPressed: _isUploadingPhoto || _isSaving
                ? null
                : _removeProfilePicture,
            child: const Text('Remove photo'),
          ),
        const SizedBox(height: 4),
        Text(
          _name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: darkText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _course,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: greyText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _department,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: greyText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Samar State University',
            style: TextStyle(
              color: primaryBlue,
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
      backgroundColor: primaryBlue.withValues(alpha: 0.10),
      child: Text(
        _initials,
        style: const TextStyle(
          color: primaryBlue,
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
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            title: 'Active Classes',
            value: '$_activeClasses',
            icon: Icons.class_outlined,
            color: orange,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildInfoCard(
            title: 'Student ID',
            value: _studentId,
            icon: Icons.badge_outlined,
            color: primaryBlue,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACCOUNT MENU
  // ============================================================

  Widget _buildAccountMenu() => StudentProfileEditor(
    profile: _profile!,
    photoBusy: _isUploadingPhoto,
    resetBusy: _isRequestingPasswordReset,
    onSaved: (profile) {
      if (mounted) setState(() => _profile = profile);
    },
    onBusyChanged: (busy) {
      if (mounted) setState(() => _isSaving = busy);
    },
    onResetPassword: _requestPasswordReset,
  );

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
          'Sign out of this student account',
          style: TextStyle(color: greyText, fontSize: 12),
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
              color: darkText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: greyText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
                color: greyText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryBlue,
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
