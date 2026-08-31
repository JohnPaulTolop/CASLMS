import 'package:flutter/material.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final Color adminTheme = Colors.indigo.shade600;
  
  String _searchQuery = '';
  String _selectedRoleFilter = 'All Users';
  final List<String> _roleOptions = ['All Users', 'Student', 'Instructor', 'Admin'];

  // Mock User Database
  final List<Map<String, dynamic>> _users = [
    {
      'id': '2023-1042',
      'name': 'Rolando Mabansag Jr.',
      'email': 'rolando.mabansag@student.ssu.edu.ph',
      'role': 'Student',
      'status': 'Active',
      'lastLogin': '2 mins ago',
      'color': Colors.blueAccent,
    },
    {
      'id': 'F-2018-045',
      'name': 'Mr. Juan Santos',
      'email': 'juan.santos@ssu.edu.ph',
      'role': 'Instructor',
      'status': 'Active',
      'lastLogin': '1 hr ago',
      'color': Colors.teal,
    },
    {
      'id': '2022-0015',
      'name': 'Maria Elena Cruz',
      'email': 'maria.cruz@student.ssu.edu.ph',
      'role': 'Student',
      'status': 'Suspended',
      'lastLogin': '5 days ago',
      'color': Colors.blueAccent,
    },
    {
      'id': 'F-2015-012',
      'name': 'Dr. Anna Reyes',
      'email': 'anna.reyes@ssu.edu.ph',
      'role': 'Admin',
      'status': 'Active',
      'lastLogin': 'Just now',
      'color': Colors.deepPurple,
    },
  ];

  // Dynamic Filtering Logic
  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((user) {
      final matchesRole = _selectedRoleFilter == 'All Users' || user['role'] == _selectedRoleFilter;
      final matchesSearch = user['name'].toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            user['id'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            user['email'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesRole && matchesSearch;
    }).toList();
  }

  void _toggleUserStatus(int index) {
    setState(() {
      _users[index]['status'] = _users[index]['status'] == 'Active' ? 'Suspended' : 'Active';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_users[index]['name']} is now ${_users[index]['status']}'),
        backgroundColor: adminTheme,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteUser(int index) {
    final name = _users[index]['name'];
    setState(() {
      _users.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name deleted successfully.'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 24.0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'User Management',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87, letterSpacing: -0.5),
              ),
              Text(
                'Manage Students & Instructors',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.black87), 
              tooltip: 'Export CSV', 
              onPressed: () {}
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              children: [
                _buildTopMetrics(),
                const SizedBox(height: 24),
                _buildSearchAndFilter(),
                const SizedBox(height: 16),
                
                // Show active filter indicator if not default
                if (_selectedRoleFilter != 'All Users')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        const Text('Filtering by: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Chip(
                          label: Text(_selectedRoleFilter, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                          backgroundColor: adminTheme,
                          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 16),
                          onDeleted: () => setState(() => _selectedRoleFilter = 'All Users'),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),

                if (_filteredUsers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No users found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                else
                  ..._filteredUsers.map((user) {
                    int originalIndex = _users.indexWhere((u) => u['id'] == user['id']);
                    return _buildRedesignedUserCard(user, originalIndex);
                  }).toList(),
                  
                const SizedBox(height: 80), // Fab padding
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateUserModal(context),
        backgroundColor: adminTheme,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('New User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==============================================================
  // UI COMPONENTS (REDESIGNED)
  // ==============================================================

  Widget _buildTopMetrics() {
    int total = _users.length;
    int students = _users.where((u) => u['role'] == 'Student').length;
    int instructors = _users.where((u) => u['role'] == 'Instructor').length;
    int suspended = _users.where((u) => u['status'] == 'Suspended').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildInnerMetric('Total Users', total.toString(), Icons.groups_rounded, adminTheme)),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildInnerMetric('Students', students.toString(), Icons.school_rounded, Colors.blueAccent)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
          ),
          Row(
            children: [
              Expanded(child: _buildInnerMetric('Faculty', instructors.toString(), Icons.badge_rounded, Colors.teal)),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(child: _buildInnerMetric('Suspended', suspended.toString(), Icons.block_rounded, Colors.red.shade400)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInnerMetric(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value, 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)
              ),
              const SizedBox(height: 2),
              Text(
                title, 
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600), 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by name, ID, or email...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: adminTheme, width: 2)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(Icons.filter_list_rounded, color: _selectedRoleFilter == 'All Users' ? Colors.grey.shade700 : adminTheme),
            tooltip: 'Filter by Role',
            onSelected: (String result) {
              setState(() {
                _selectedRoleFilter = result;
              });
            },
            itemBuilder: (BuildContext context) => _roleOptions.map((String choice) {
              return PopupMenuItem<String>(
                value: choice,
                child: Text(choice, style: TextStyle(
                  fontWeight: _selectedRoleFilter == choice ? FontWeight.bold : FontWeight.normal,
                  color: _selectedRoleFilter == choice ? adminTheme : Colors.black87
                )),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRedesignedUserCard(Map<String, dynamic> user, int originalIndex) {
    bool isSuspended = user['status'] == 'Suspended';
    Color roleColor = user['color'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSuspended ? Colors.red.shade100 : Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isSuspended ? Colors.red.shade50 : roleColor.withOpacity(0.1),
            child: Icon(Icons.person_rounded, color: isSuspended ? Colors.red : roleColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'], 
                  style: TextStyle(
                    fontWeight: FontWeight.w800, 
                    fontSize: 16, 
                    color: isSuspended ? Colors.grey.shade500 : Colors.black87, 
                    decoration: isSuspended ? TextDecoration.lineThrough : null
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user['id']} • ${user['email']}', 
                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(user['role'], style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSuspended ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user['status'], 
                        style: TextStyle(color: isSuspended ? Colors.red.shade700 : Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('Login: ${user['lastLogin']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _showUserOptions(context, user, originalIndex),
          )
        ],
      ),
    );
  }

  // ==============================================================
  // ACTIONS & MODALS
  // ==============================================================

  void _showUserOptions(BuildContext context, Map<String, dynamic> user, int index) {
    bool isSuspended = user['status'] == 'Suspended';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.black87),
                title: const Text('Edit User Details', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(isSuspended ? Icons.check_circle_outline_rounded : Icons.block_rounded, color: isSuspended ? Colors.green : Colors.orange),
                title: Text(isSuspended ? 'Reactivate Account' : 'Suspend Account', style: TextStyle(fontWeight: FontWeight.w600, color: isSuspended ? Colors.green : Colors.orange.shade800)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleUserStatus(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded, color: Colors.black87),
                title: const Text('Force Password Reset', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent to ${user['email']}'), backgroundColor: adminTheme));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text('Delete User', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteUser(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateUserModal(BuildContext context) {
    String newRole = 'Student';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Provision New User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                  const SizedBox(height: 24),
                  
                  // Role Selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: newRole,
                        isExpanded: true,
                        items: ['Student', 'Instructor', 'Admin'].map((role) {
                          return DropdownMenuItem(value: role, child: Text(role, style: const TextStyle(fontWeight: FontWeight.w600)));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) setModalState(() => newRole = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField('Full Name', Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  _buildTextField('ID Number', Icons.badge_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('Email Address', Icons.email_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('Temporary Password', Icons.lock_outline_rounded, isObscure: true),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _users.insert(0, {
                            'id': 'NEW-0001',
                            'name': 'New Provisioned User',
                            'email': 'new.user@ssu.edu.ph',
                            'role': newRole,
                            'status': 'Active',
                            'lastLogin': 'Never',
                            'color': newRole == 'Student' ? Colors.blueAccent : (newRole == 'Instructor' ? Colors.teal : Colors.deepPurple),
                          });
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Account successfully created!'), backgroundColor: Colors.green.shade600));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: adminTheme,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, {bool isObscure = false}) {
    return TextField(
      obscureText: isObscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: adminTheme, width: 2)),
      ),
    );
  }
}