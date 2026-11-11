import '../shared/page_loading_state.dart';
import '../../core/app_colors.dart';
import '../../services/admin_catalog.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../firebase_options.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  Color get adminTheme => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);
  Color get surface => AppColors.resolve(context, Colors.white);
  Color get green => AppColors.resolve(context, AppColors.green);
  Color get red => AppColors.resolve(context, AppColors.error);
  Color get orange => AppColors.resolve(context, AppColors.amber);
  Color get purple => AppColors.resolve(context, AppColors.purple);
  Color get blueTint => AppColors.resolve(context, AppColors.blueTint);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedRoleFilter = 'All';

  final List<String> _roleOptions = const [
    'All',
    'Student',
    'Instructor',
    'Admin',
  ];

  List<Map<String, dynamic>> _users = [];

  AdminCatalog? _catalog;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalog = context
        .dependOnInheritedWidgetOfExactType<AdminScope>()
        ?.notifier;
    if (_catalog != null) {
      _syncDirectory();
    } else if (!_started) {
      _started = true;
      _loadUsers();
    }
  }

  void _syncDirectory() {
    final catalog = _catalog!;
    _users =
        catalog.users.values
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
          ..sort(
            (a, b) =>
                _displayName(a)
                    .toLowerCase()
                    .compareTo(_displayName(b).toLowerCase()),
          );
    _isLoading = catalog.loading;
    _errorMessage = catalog.error;
  }

  Future<void> _requireAdmin() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('No administrator is currently logged in.');
    }

    final document = await _firestore.collection('users').doc(user.uid).get();

    if (!document.exists || document.data() == null) {
      throw Exception('Administrator profile could not be found.');
    }

    final profile = document.data()!;
    final role = (profile['role'] ?? '').toString().trim().toLowerCase();
    final status = (profile['status'] ?? '').toString().trim().toLowerCase();

    if (role != 'admin' || status != 'active') {
      throw Exception('Active administrator access is required.');
    }
  }

  Future<void> _loadUsers() async {
    if (_catalog != null) {
      if (_catalog!.error != null) await _catalog!.start();
      if (mounted) setState(_syncDirectory);
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await _requireAdmin();

      final snapshot = await _firestore.collection('users').get();

      final users = snapshot.docs
          .map(
            (document) => <String, dynamic>{
              ...document.data(),
              'uid': document.id,
            },
          )
          .toList();

      users.sort(
        (a, b) =>
            _displayName(a)
                .toLowerCase()
                .compareTo(_displayName(b).toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Unable to load users.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();

    return _users.where((user) {
      final role = _role(user);

      final roleMatches =
          _selectedRoleFilter == 'All' ||
          role == _selectedRoleFilter.toLowerCase();

      if (!roleMatches) return false;
      if (query.isEmpty) return true;

      return _displayName(user).toLowerCase().contains(query) ||
          _campusId(user).toLowerCase().contains(query) ||
          _contactEmail(user).toLowerCase().contains(query);
    }).toList();
  }

  int get _activeUsers =>
      _users.where((user) => _status(user) == 'active').length;

  int get _studentCount =>
      _users.where((user) => _role(user) == 'student').length;

  int get _instructorCount =>
      _users.where((user) => _role(user) == 'instructor').length;

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    if (_isBusy) return;

    final uid = (user['uid'] ?? '').toString();

    if (uid.isEmpty) return;

    if (uid == _auth.currentUser?.uid) {
      _showError('You cannot suspend your own administrator account.');
      return;
    }

    final currentStatus = _status(user);
    final nextStatus = currentStatus == 'active' ? 'suspended' : 'active';

    setState(() {
      _isBusy = true;
    });

    try {
      await _requireAdmin();

      await _firestore.collection('users').doc(uid).update({
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadUsers();

      if (!mounted) return;

      _showMessage('${_displayName(user)} is now ${_capitalize(nextStatus)}.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? 'Unable to update account status.');
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    if (_isBusy) {
      return;
    }

    String newName = _displayName(user);
    String newEmail = _contactEmailRaw(user);
    String newDepartment = (user['department'] ?? '').toString();

    String newCourse = (user['course'] ?? '').toString();

    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit User',
            style: TextStyle(fontWeight: FontWeight.w700, color: textDark),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: newName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  onChanged: (String value) {
                    newName = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: newEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Contact Email'),
                  onChanged: (String value) {
                    newEmail = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: newDepartment,
                  decoration: const InputDecoration(labelText: 'Department'),
                  onChanged: (String value) {
                    newDepartment = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: newCourse,
                  decoration: const InputDecoration(
                    labelText: 'Course / Program',
                  ),
                  onChanged: (String value) {
                    newCourse = value;
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Campus ID',
                    helperText: 'Campus ID, role, and Firebase auth email are protected.',
                  ),
                  child: Text(
                    _campusId(user),
                    style: TextStyle(color: textDark),
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
                  'course': newCourse,
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final String name = (result['name'] ?? '').trim();

    final String email = (result['email'] ?? '').trim().toLowerCase();

    final String department = (result['department'] ?? '').trim();

    final String course = (result['course'] ?? '').trim();

    if (name.length < 2) {
      _showError('Enter the complete user name.');
      return;
    }

    if (email.isNotEmpty && !_isValidEmail(email)) {
      _showError('Enter a valid contact email.');
      return;
    }

    final String uid = (user['uid'] ?? '').toString();

    if (uid.isEmpty) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _requireAdmin();

      await _firestore.collection('users').doc(uid).update({
        'name': name,
        'email': email,
        'department': department,
        'course': course,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      // Update the existing list locally instead of immediately
      // tearing down and rebuilding it after the dialog route closes.
      setState(() {
        final int index = _users.indexWhere(
          (Map<String, dynamic> item) => (item['uid'] ?? '').toString() == uid,
        );

        if (index != -1) {
          _users[index] = {
            ..._users[index],
            'name': name,
            'email': email,
            'department': department,
            'course': course,
          };
        }

        _isBusy = false;
      });

      _showMessage('User profile updated.');
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
      });

      _showError(e.message ?? 'Unable to update user.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
      });

      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showCreateUserModal() async {
    if (_isBusy) return;

    final nameController = TextEditingController();
    final campusIdController = TextEditingController();
    final emailController = TextEditingController();
    final departmentController = TextEditingController();
    final courseController = TextEditingController();
    final passwordController = TextEditingController();

    String selectedRole = 'instructor';

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                22,
                16,
                22,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Provision User Account',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Creates a real Firebase Authentication account and Firestore profile.',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: campusIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Campus ID',
                        helperText: '5–12 numeric digits.',
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Contact Email',
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: courseController,
                      decoration: const InputDecoration(
                        labelText: 'Course / Program',
                      ),
                    ),
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Student'),
                        ),
                        DropdownMenuItem(
                          value: 'instructor',
                          child: Text('Instructor'),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setSheetState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Temporary Password',
                        helperText: 'At least 6 characters.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, <String, String>{
                            'name': nameController.text,
                            'campusId': campusIdController.text,
                            'email': emailController.text,
                            'department': departmentController.text,
                            'course': courseController.text,
                            'password': passwordController.text,
                            'role': selectedRole,
                          });
                        },
                        child: const Text(
                          'Create Account',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    campusIdController.dispose();
    emailController.dispose();
    departmentController.dispose();
    courseController.dispose();
    passwordController.dispose();

    if (result == null) return;

    await _createUser(
      fullName: result['name'] ?? '',
      campusId: result['campusId'] ?? '',
      contactEmail: result['email'] ?? '',
      department: result['department'] ?? '',
      course: result['course'] ?? '',
      password: result['password'] ?? '',
      role: result['role'] ?? '',
    );
  }

  Future<void> _createUser({
    required String fullName,
    required String campusId,
    required String contactEmail,
    required String department,
    required String course,
    required String password,
    required String role,
  }) async {
    final cleanName = fullName.trim();

    final cleanCampusId = campusId.trim().replaceAll(RegExp(r'\s+'), '');

    final cleanContactEmail = contactEmail.trim().toLowerCase();

    final cleanRole = role.trim().toLowerCase();

    if (cleanName.length < 2) {
      _showError('Enter the complete user name.');
      return;
    }

    if (!RegExp(r'^\d{5,12}$').hasMatch(cleanCampusId)) {
      _showError('Campus ID must contain 5–12 numeric digits.');
      return;
    }

    if (!_isValidEmail(cleanContactEmail)) {
      _showError('Enter a valid contact email.');
      return;
    }

    if (!{'student', 'instructor', 'admin'}.contains(cleanRole)) {
      _showError('Invalid user role.');
      return;
    }

    if (password.length < 6) {
      _showError('Temporary password must contain at least 6 characters.');
      return;
    }

    setState(() {
      _isBusy = true;
    });

    FirebaseAuth? secondaryAuth;
    User? createdUser;

    try {
      await _requireAdmin();

      final existing = await _firestore
          .collection('users')
          .where('universityId', isEqualTo: cleanCampusId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('A CASLMS account already uses this Campus ID.');
      }

      const appName = 'caslmsAdminProvisioning';
      FirebaseApp secondaryApp;

      try {
        secondaryApp = Firebase.app(appName);
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: appName,
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      await secondaryAuth.signOut();

      final authEmail = '$cleanCampusId@caslms.app';

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception('Firebase Authentication did not return the new user.');
      }

      await createdUser.updateDisplayName(cleanName);

      await _firestore.collection('users').doc(createdUser.uid).set({
        'uid': createdUser.uid,
        'name': cleanName,
        'universityId': cleanCampusId,
        'email': cleanContactEmail,
        'authEmail': authEmail,
        'department': department.trim(),
        'course': course.trim(),
        'role': cleanRole,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': null,
      });

      await secondaryAuth.signOut();

      await _loadUsers();

      if (!mounted) return;

      _showMessage('${_capitalize(cleanRole)} account created for $cleanName.');
    } on FirebaseAuthException catch (e) {
      try {
        await createdUser?.delete();
      } catch (_) {}

      if (!mounted) return;

      _showError(
        e.message ?? 'Unable to create Firebase Authentication account.',
      );
    } on FirebaseException catch (e) {
      try {
        await createdUser?.delete();
      } catch (_) {}

      if (!mounted) return;

      _showError(e.message ?? 'Unable to create CASLMS user profile.');
    } catch (e) {
      try {
        await createdUser?.delete();
      } catch (_) {}

      if (!mounted) return;

      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      try {
        await secondaryAuth?.signOut();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_filteredUsers.isEmpty) {
      _showError('There are no users to export.');
      return;
    }

    final csv = StringBuffer(
      'Campus ID,Name,Email,Role,Status,Department,Course,Last Login\n',
    );

    for (final user in _filteredUsers) {
      csv.writeln(
        '${_csv(_campusId(user))},'
        '${_csv(_displayName(user))},'
        '${_csv(_contactEmailRaw(user))},'
        '${_csv(_capitalize(_role(user)))},'
        '${_csv(_capitalize(_status(user)))},'
        '${_csv((user['department'] ?? '').toString())},'
        '${_csv((user['course'] ?? '').toString())},'
        '${_csv(_formatTimestamp(user['lastLoginAt']))}',
      );
    }

    await Clipboard.setData(ClipboardData(text: csv.toString()));

    if (!mounted) return;

    _showMessage('User CSV copied to clipboard.');
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
                      title: 'Users',
                      subtitle: 'Manage student, instructor, and administrator accounts.',
                      eyebrow: 'ADMINISTRATION',
                      actions: [
                        FilledButton.icon(
                          onPressed: _isBusy ? null : _showCreateUserModal,
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: const Text('Create user'),
                        ),
                        IconButton(
                          onPressed: _isBusy ? null : _exportCsv,
                          tooltip: 'Copy CSV',
                          icon: Icon(Icons.download_rounded, color: textDark),
                        ),
                        IconButton(
                          onPressed: _isBusy ? null : _loadUsers,
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
          onRetry: _loadUsers,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: adminTheme,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 100),
        children: [
          _buildMetrics(),
          const SizedBox(height: 20),
          _buildSearchAndFilter(),
          const SizedBox(height: 18),
          if (_filteredUsers.isEmpty)
            const WorkspaceEmptyState(
              title: 'No users match this filter.',
              message: 'Try adjusting your search query or role filter.',
              icon: Icons.person_search_outlined,
            )
          else
            ..._filteredUsers.map(_buildUserCard),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stats = [
          (
            Icons.groups_rounded,
            '${_users.length}',
            'Total users',
            adminTheme,
            blueTint,
          ),
          (
            Icons.verified_user_rounded,
            '$_activeUsers',
            'Active accounts',
            green,
            AppColors.resolve(context, AppColors.greenTint),
          ),
          (
            Icons.school_rounded,
            '$_studentCount',
            'Students',
            Colors.blue,
            blueTint,
          ),
          (
            Icons.badge_rounded,
            '$_instructorCount',
            'Faculty',
            purple,
            AppColors.resolve(context, AppColors.purpleTint),
          ),
        ];
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 760 * scale
            ? 4
            : constraints.maxWidth >= 380 * scale
            ? 2
            : 1;
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

  Widget _buildSearchAndFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search name, Campus ID, or email',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _roleOptions.map((role) {
              final selected = _selectedRoleFilter == role;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(role == 'All' ? 'All Users' : role),
                  selectedColor: adminTheme.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: selected ? adminTheme : textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? adminTheme : borderColor,
                    ),
                  ),
                  onSelected: (_) => setState(() => _selectedRoleFilter = role),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = _role(user);
    final status = _status(user);
    final active = status == 'active';

    final Color roleColor = role == 'admin'
        ? purple
        : role == 'instructor'
        ? Colors.teal
        : adminTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkspaceSurface(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: roleColor.withValues(alpha: 0.12),
              child: Text(
                _initials(_displayName(user)),
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _displayName(user),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (active ? green : orange).withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _capitalize(status),
                          style: TextStyle(
                            color: active ? green : orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _capitalize(role),
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Campus ID: ${_campusId(user)}  •  ${_contactEmail(user)}',
                    style: TextStyle(color: textGrey, fontSize: 12),
                  ),
                  if ((user['department'] ?? '').toString().isNotEmpty ||
                      (user['course'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if ((user['department'] ?? '').toString().isNotEmpty)
                          user['department'].toString(),
                        if ((user['course'] ?? '').toString().isNotEmpty)
                          user['course'].toString(),
                      ].join(' · '),
                      style: TextStyle(color: textGrey, fontSize: 11.5),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Last login: ${_formatTimestamp(user['lastLoginAt'])}',
                    style: TextStyle(
                      color: textGrey.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !_isBusy,
              icon: Icon(Icons.more_vert_rounded, color: textGrey),
              onSelected: (action) {
                if (action == 'edit') {
                  _editUser(user);
                } else if (action == 'status') {
                  _toggleStatus(user);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit profile')),
                PopupMenuItem(
                  value: 'status',
                  child: Text(
                    active ? 'Suspend account' : 'Reactivate account',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(Map<String, dynamic> user) {
    final value = (user['name'] ?? '').toString().trim();
    return value.isEmpty ? 'Unnamed User' : value;
  }

  String _campusId(Map<String, dynamic> user) {
    final value = (user['universityId'] ?? '').toString().trim();
    return value.isEmpty ? 'No ID' : value;
  }

  String _contactEmailRaw(Map<String, dynamic> user) {
    return (user['email'] ?? '').toString().trim();
  }

  String _contactEmail(Map<String, dynamic> user) {
    final value = _contactEmailRaw(user);
    return value.isEmpty ? 'No contact email' : value;
  }

  String _role(Map<String, dynamic> user) {
    return (user['role'] ?? '').toString().trim().toLowerCase();
  }

  String _status(Map<String, dynamic> user) {
    return (user['status'] ?? 'active').toString().trim().toLowerCase();
  }

  String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _formatTimestamp(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return 'Never';

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }

    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _csv(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  void _showMessage(String message) {
    if (!mounted) return;

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
    if (!mounted) return;

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
