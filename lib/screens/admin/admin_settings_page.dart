import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/profile_picture_service.dart';
import 'admin_ai_gateway_page.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  static const Color adminTheme = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color green = Color(0xFF26A65B);
  static const Color red = Color(0xFFFF4B4B);
  static const Color purple = Colors.deepPurple;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final FirebaseAuth _auth =
      FirebaseAuth.instance;
  final ProfilePictureService _profilePictureService =
      ProfilePictureService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
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
        throw Exception(
          'No administrator is currently logged in.',
        );
      }

      _authConnected = true;

      final profileDocument =
          await _firestore.collection('users').doc(user.uid).get();

      if (!profileDocument.exists ||
          profileDocument.data() == null) {
        throw Exception(
          'Administrator profile could not be found.',
        );
      }

      final profile = profileDocument.data()!;

      final role =
          (profile['role'] ?? '').toString().trim().toLowerCase();

      final status =
          (profile['status'] ?? '').toString().trim().toLowerCase();

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
        _adminProfile = {
          ...profile,
          'uid': user.uid,
        };
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _firestoreConnected = false;
        _errorMessage =
            e.message ?? 'Unable to load platform settings.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _name {
    final String value =
        (_adminProfile?['name'] ??
                _auth.currentUser?.displayName ??
                '')
            .toString()
            .trim();

    return value.isEmpty
        ? 'Administrator'
        : value;
  }

  String get _email {
    final String value =
        (_adminProfile?['email'] ?? '')
            .toString()
            .trim();

    return value.isEmpty
        ? 'No contact email'
        : value;
  }

  String get _campusId {
    final String value =
        (_adminProfile?['universityId'] ?? '')
            .toString()
            .trim();

    return value.isEmpty
        ? 'No ID'
        : value;
  }

  String get _department {
    final String value =
        (_adminProfile?['department'] ?? '')
            .toString()
            .trim();

    return value.isEmpty
        ? 'Department not specified'
        : value;
  }

  String get _photoUrl {
    return (_adminProfile?['photoUrl'] ?? '')
        .toString()
        .trim();
  }

  Future<void> _showEditAdminProfileDialog() async {
    if (_adminProfile == null || _isSaving) {
      return;
    }

    String newName = _name;
    String newEmail =
        (_adminProfile?['email'] ?? '')
            .toString();

    String newDepartment =
        (_adminProfile?['department'] ?? '')
            .toString();

    final Map<String, String>? result =
        await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: const Text(
            'Administrator Profile',
            style: TextStyle(
              color: textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: newName,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration:
                      const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                    ),
                  ),
                  onChanged: (String value) {
                    newName = value;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: newEmail,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText: 'Contact Email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
                  ),
                  onChanged: (String value) {
                    newEmail = value;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: newDepartment,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration:
                      const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(
                      Icons.apartment_rounded,
                    ),
                  ),
                  onChanged: (String value) {
                    newDepartment = value;
                  },
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration:
                      const InputDecoration(
                    labelText: 'Campus ID',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                    ),
                    helperText:
                        'Campus ID and administrator role are protected.',
                  ),
                  child: Text(
                    _campusId,
                    style: const TextStyle(
                      color: textDark,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(
                  dialogContext,
                ).unfocus();

                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                FocusScope.of(
                  dialogContext,
                ).unfocus();

                Navigator.of(
                  dialogContext,
                ).pop({
                  'name': newName,
                  'email': newEmail,
                  'department':
                      newDepartment,
                });
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: adminTheme,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Save Changes',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final String cleanName =
        (result['name'] ?? '').trim();

    final String cleanEmail =
        (result['email'] ?? '').trim();

    final String cleanDepartment =
        (result['department'] ?? '').trim();

    if (cleanName.isEmpty) {
      _showError(
        'Full name cannot be empty.',
      );
      return;
    }

    if (cleanEmail.isNotEmpty &&
        (!cleanEmail.contains('@') ||
            !cleanEmail.contains('.'))) {
      _showError(
        'Enter a valid contact email address.',
      );
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      _showError(
        'You are no longer logged in.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'name': cleanName,
        'email': cleanEmail,
        'department': cleanDepartment,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      try {
        await user.updateDisplayName(
          cleanName,
        );
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

      _showMessage(
        'Administrator profile updated.',
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showError(
        e.message ??
            'Unable to update your profile.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Unable to update your profile.',
      );
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
      final ProfilePictureResult? result =
          await _profilePictureService
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

      _showMessage(
        'Administrator profile picture updated.',
      );
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

      _showError(
        'Unable to update your profile picture.',
      );
    }
  }

  Future<void> _removeProfilePicture() async {
    if (_photoUrl.isEmpty ||
        _isUploadingPhoto) {
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
            'Remove Profile Picture',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Your administrator initials will be shown instead.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: red,
                foregroundColor:
                    Colors.white,
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
      await _profilePictureService
          .removeProfilePicture();

      if (!mounted) {
        return;
      }

      final Map<String, dynamic>
          updatedProfile = {
        ...?_adminProfile,
      };

      updatedProfile.remove('photoUrl');
      updatedProfile.remove('photoPath');

      setState(() {
        _adminProfile = updatedProfile;
        _isUploadingPhoto = false;
      });

      _showMessage(
        'Administrator profile picture removed.',
      );
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

      _showError(
        'Unable to remove your profile picture.',
      );
    }
  }

  Future<void> _logoutAdmin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Log Out Administrator',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'End this secure administrator session?',
          ),
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
      await _auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to log out.',
          ),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
              'Platform Settings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: textDark,
              ),
            ),
            Text(
              'Integration Health & Administrator Account',
              style: TextStyle(
                fontSize: 12,
                color: textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSettings,
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
              color: textDark,
            ),
          ),
          const SizedBox(width: 8),
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
      return const Center(
        child: CircularProgressIndicator(
          color: adminTheme,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: red,
                size: 50,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textGrey,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: adminTheme,
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

    return RefreshIndicator(
      onRefresh: _loadSettings,
      color: adminTheme,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          _buildAdminAccount(),
          const SizedBox(height: 18),
          _buildActionTile(
            title: 'Edit Administrator Profile',
            subtitle:
                'Update your name, email, and department.',
            icon:
                Icons.manage_accounts_outlined,
            color: adminTheme,
            onTap:
                _showEditAdminProfileDialog,
          ),
          _buildActionTile(
            title: _photoUrl.isEmpty
                ? 'Upload Profile Picture'
                : 'Change Profile Picture',
            subtitle:
                'JPG, JPEG, PNG, or WEBP up to 5 MB.',
            icon:
                Icons.photo_camera_outlined,
            color: adminTheme,
            onTap: _changeProfilePicture,
          ),
          if (_photoUrl.isNotEmpty)
            _buildActionTile(
              title:
                  'Remove Profile Picture',
              subtitle:
                  'Show your administrator initials instead.',
              icon:
                  Icons.delete_outline_rounded,
              color: red,
              onTap:
                  _removeProfilePicture,
            ),
          const SizedBox(height: 18),
          const Text(
            'Core Services',
            style: TextStyle(
              color: textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 18),
          _buildActionTile(
            title: 'Firebase AI Logic',
            subtitle:
                'Open real AI processing status and material activity.',
            icon: Icons.auto_awesome_rounded,
            color: purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminAIGatewayScreen(),
                ),
              );
            },
          ),
          _buildSecurityNotice(),
          const SizedBox(height: 28),
          const Text(
            'Administrator Session',
            style: TextStyle(
              color: textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionTile(
            title: 'Log Out Administrator',
            subtitle:
                'End the current Firebase Authentication session.',
            icon: Icons.logout_rounded,
            color: red,
            onTap: _logoutAdmin,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccount() {
    final String status =
        (_adminProfile?['status'] ?? 'active')
            .toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildAdminAvatar(),
              Material(
                color: adminTheme,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _isUploadingPhoto
                      ? null
                      : _changeProfilePicture,
                  customBorder:
                      const CircleBorder(),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: _isUploadingPhoto
                        ? const Padding(
                            padding:
                                EdgeInsets.all(7),
                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .camera_alt_rounded,
                            color:
                                Colors.white,
                            size: 14,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$_campusId • $_email',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _department,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _capitalize(status),
              style: const TextStyle(
                color: green,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
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
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
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
      backgroundColor:
          adminTheme.withValues(alpha: 0.10),
      child: Text(
        _initials(_name),
        style: const TextStyle(
          color: adminTheme,
          fontWeight: FontWeight.w800,
        ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            connected
                ? Icons.check_circle_rounded
                : Icons.error_rounded,
            color: color,
            size: 20,
          ),
        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 5,
          ),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: textGrey,
            fontSize: 10.5,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: textGrey,
        ),
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: purple,
            size: 19,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'API keys and Firebase service credentials are intentionally not editable in the Flutter app. Secret configuration belongs in Firebase / Google Cloud, not in client-side UI.',
              style: TextStyle(
                color: textDark,
                fontSize: 10.8,
                height: 1.45,
              ),
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

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: adminTheme,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior:
            SnackBarBehavior.floating,
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
