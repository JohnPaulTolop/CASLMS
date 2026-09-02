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
  static const Color adminTheme = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color green = Color(0xFF26A65B);
  static const Color red = Color(0xFFFF4B4B);
  static const Color orange = Color(0xFFFF9418);

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

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _requireAdmin() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('No administrator is currently logged in.');
    }

    final document =
        await _firestore.collection('users').doc(user.uid).get();

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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await _requireAdmin();

      final snapshot =
          await _firestore.collection('users').get();

      final users = snapshot.docs
          .map(
            (document) => <String, dynamic>{
              ...document.data(),
              'uid': document.id,
            },
          )
          .toList();

      users.sort(
        (a, b) => _displayName(a)
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
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();

    return _users.where((user) {
      final role = _role(user);

      final roleMatches = _selectedRoleFilter == 'All' ||
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
    final nextStatus =
        currentStatus == 'active' ? 'suspended' : 'active';

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

      _showMessage(
        '${_displayName(user)} is now ${_capitalize(nextStatus)}.',
      );
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
    String newDepartment =
        (user['department'] ?? '').toString();

    String newCourse =
        (user['course'] ?? '').toString();

    final Map<String, String>? result =
        await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Edit User',
            style: TextStyle(
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
                  ),
                  onChanged: (String value) {
                    newName = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: newEmail,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText: 'Contact Email',
                  ),
                  onChanged: (String value) {
                    newEmail = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: newDepartment,
                  decoration:
                      const InputDecoration(
                    labelText: 'Department',
                  ),
                  onChanged: (String value) {
                    newDepartment = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: newCourse,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Course / Program',
                  ),
                  onChanged: (String value) {
                    newCourse = value;
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration:
                      const InputDecoration(
                    labelText: 'Campus ID',
                    helperText:
                        'Campus ID, role, and Firebase auth email are protected.',
                  ),
                  child: Text(
                    _campusId(user),
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
                  'course': newCourse,
                });
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: adminTheme,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final String name =
        (result['name'] ?? '').trim();

    final String email =
        (result['email'] ?? '')
            .trim()
            .toLowerCase();

    final String department =
        (result['department'] ?? '')
            .trim();

    final String course =
        (result['course'] ?? '').trim();

    if (name.length < 2) {
      _showError(
        'Enter the complete user name.',
      );
      return;
    }

    if (email.isNotEmpty &&
        !_isValidEmail(email)) {
      _showError(
        'Enter a valid contact email.',
      );
      return;
    }

    final String uid =
        (user['uid'] ?? '').toString();

    if (uid.isEmpty) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _requireAdmin();

      await _firestore
          .collection('users')
          .doc(uid)
          .update({
        'name': name,
        'email': email,
        'department': department,
        'course': course,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      // Update the existing list locally instead of immediately
      // tearing down and rebuilding it after the dialog route closes.
      setState(() {
        final int index = _users.indexWhere(
          (Map<String, dynamic> item) =>
              (item['uid'] ?? '').toString() ==
              uid,
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

      _showMessage(
        'User profile updated.',
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
      });

      _showError(
        e.message ??
            'Unable to update user.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
      });

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
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

    final result =
        await showModalBottomSheet<Map<String, String>>(
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Provision User Account',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Creates a real Firebase Authentication account and Firestore profile.',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Full Name'),
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
                      decoration:
                          const InputDecoration(labelText: 'Contact Email'),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: departmentController,
                      decoration:
                          const InputDecoration(labelText: 'Department'),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: courseController,
                      decoration:
                          const InputDecoration(labelText: 'Course / Program'),
                    ),
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration:
                          const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Student'),
                        ),
                        DropdownMenuItem(
                          value: 'instructor',
                          child: Text('Instructor'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin'),
                        ),
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
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                            <String, String>{
                              'name': nameController.text,
                              'campusId': campusIdController.text,
                              'email': emailController.text,
                              'department': departmentController.text,
                              'course': courseController.text,
                              'password': passwordController.text,
                              'role': selectedRole,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: adminTheme,
                          foregroundColor: Colors.white,
                        ),
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

    final cleanCampusId =
        campusId.trim().replaceAll(RegExp(r'\s+'), '');

    final cleanContactEmail =
        contactEmail.trim().toLowerCase();

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
      _showError(
        'Temporary password must contain at least 6 characters.',
      );
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
          .where(
            'universityId',
            isEqualTo: cleanCampusId,
          )
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception(
          'A CASLMS account already uses this Campus ID.',
        );
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

      final credential =
          await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception(
          'Firebase Authentication did not return the new user.',
        );
      }

      await createdUser.updateDisplayName(cleanName);

      await _firestore
          .collection('users')
          .doc(createdUser.uid)
          .set({
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

      _showMessage(
        '${_capitalize(cleanRole)} account created for $cleanName.',
      );
    } on FirebaseAuthException catch (e) {
      try {
        await createdUser?.delete();
      } catch (_) {}

      if (!mounted) return;

      _showError(
        e.message ??
            'Unable to create Firebase Authentication account.',
      );
    } on FirebaseException catch (e) {
      try {
        await createdUser?.delete();
      } catch (_) {}

      if (!mounted) return;

      _showError(
        e.message ?? 'Unable to create CASLMS user profile.',
      );
    } catch (e) {
      try {
        await createdUser?.delete();
      } catch (_) {}

      if (!mounted) return;

      _showError(
        e.toString().replaceFirst('Exception: ', ''),
      );
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

    await Clipboard.setData(
      ClipboardData(text: csv.toString()),
    );

    if (!mounted) return;

    _showMessage('User CSV copied to clipboard.');
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
              'User Management',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: textDark,
              ),
            ),
            Text(
              'Firebase Authentication & Firestore Profiles',
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
            onPressed: _isBusy ? null : _exportCsv,
            tooltip: 'Copy CSV',
            icon: const Icon(Icons.download_rounded, color: textDark),
          ),
          IconButton(
            onPressed: _isBusy ? null : _loadUsers,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: textDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _isBusy ? null : _showCreateUserModal,
              backgroundColor: adminTheme,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create User'),
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
        child: CircularProgressIndicator(color: adminTheme),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: red, size: 50),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textGrey, height: 1.45),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadUsers,
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
      onRefresh: _loadUsers,
      color: adminTheme,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        children: [
          _buildMetrics(),
          const SizedBox(height: 20),
          _buildSearchAndFilter(),
          const SizedBox(height: 18),
          if (_filteredUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(
                child: Text(
                  'No users match this filter.',
                  style: TextStyle(
                    color: textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ..._filteredUsers.map(_buildUserCard),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            'Total',
            '${_users.length}',
            Icons.groups_rounded,
            adminTheme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            'Active',
            '$_activeUsers',
            Icons.verified_user_rounded,
            green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            'Students',
            '$_studentCount',
            Icons.school_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            'Faculty',
            '$_instructorCount',
            Icons.badge_rounded,
            Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: textGrey,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search name, Campus ID, or email',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: borderColor),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 11),
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
                  onSelected: (_) {
                    setState(() {
                      _selectedRoleFilter = role;
                    });
                  },
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
        ? Colors.deepPurple
        : role == 'instructor'
            ? Colors.teal
            : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.10),
          child: Text(
            _initials(_displayName(user)),
            style: TextStyle(
              color: roleColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _displayName(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: (active ? green : orange).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _capitalize(status),
                style: TextStyle(
                  color: active ? green : orange,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${_capitalize(role)} • ${_campusId(user)}\n'
            '${_contactEmail(user)}\n'
            'Last login: ${_formatTimestamp(user['lastLoginAt'])}',
            style: const TextStyle(
              color: textGrey,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          enabled: !_isBusy,
          onSelected: (action) {
            if (action == 'edit') {
              _editUser(user);
            } else if (action == 'status') {
              _toggleStatus(user);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit User'),
            ),
            PopupMenuItem(
              value: 'status',
              child: Text(
                active ? 'Suspend Account' : 'Reactivate Account',
              ),
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
    return (user['status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();
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
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value);
  }

  String _formatTimestamp(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return 'Never';

    final difference =
        DateTime.now().difference(date.toLocal());

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
