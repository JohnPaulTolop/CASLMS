import 'package:flutter/material.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({Key? key}) : super(key: key);

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final Color adminTheme = Colors.indigo.shade600;

  String _searchQuery = '';
  String _selectedStatusFilter = 'Active';
  final List<String> _statusOptions = ['All', 'Active', 'Archived'];

  // Mock Course Database
  final List<Map<String, dynamic>> _courses = [
    {
      'code': 'IT301',
      'title': 'Mobile Development',
      'instructor': 'Mr. Santos',
      'students': 45,
      'status': 'Active',
      'color': Colors.blueAccent,
    },
    {
      'code': 'IT305',
      'title': 'System Integration',
      'instructor': 'Prof. Cruz',
      'students': 40,
      'status': 'Active',
      'color': Colors.deepPurple,
    },
    {
      'code': 'IT401',
      'title': 'IT Capstone Project 1',
      'instructor': 'Prof. Reyes',
      'students': 32,
      'status': 'Active',
      'color': Colors.purple.shade400,
    },
    {
      'code': 'CS101',
      'title': 'Introduction to Computing',
      'instructor': 'Dr. Gomez',
      'students': 120,
      'status': 'Archived',
      'color': Colors.grey,
    },
  ];

  // Dynamic Filtering Logic
  List<Map<String, dynamic>> get _filteredCourses {
    return _courses.where((course) {
      final matchesStatus = _selectedStatusFilter == 'All' || course['status'] == _selectedStatusFilter;
      final matchesSearch = course['title'].toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            course['code'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            course['instructor'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
  }

  void _toggleCourseStatus(int index) {
    setState(() {
      _courses[index]['status'] = _courses[index]['status'] == 'Active' ? 'Archived' : 'Active';
      _courses[index]['color'] = _courses[index]['status'] == 'Active' ? Colors.indigo.shade400 : Colors.grey;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_courses[index]['code']} is now ${_courses[index]['status']}'),
        backgroundColor: adminTheme,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteCourse(int index) {
    final title = _courses[index]['title'];
    setState(() {
      _courses.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title deleted successfully.'),
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
                'Course Administration',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87, letterSpacing: -0.5),
              ),
              Text(
                'Active Subjects & Enrollment',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.download_rounded, color: Colors.black87), tooltip: 'Export Roster', onPressed: () {}),
            const SizedBox(width: 24),
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
                const SizedBox(height: 24),

                if (_filteredCourses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('No courses found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  )
                else
                  ..._filteredCourses.map((course) {
                    int originalIndex = _courses.indexWhere((c) => c['code'] == course['code']);
                    return _buildSubjectCard(course, originalIndex);
                  }).toList(),
                  
                const SizedBox(height: 80), // Fab padding
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCourseModal(context),
        backgroundColor: adminTheme,
        elevation: 4,
        icon: const Icon(Icons.library_add_rounded, color: Colors.white),
        label: const Text('New Course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==============================================================
  // UI COMPONENTS
  // ==============================================================

  Widget _buildTopMetrics() {
    int active = _courses.where((c) => c['status'] == 'Active').length;
    int archived = _courses.where((c) => c['status'] == 'Archived').length;
    int totalStudents = _courses.where((c) => c['status'] == 'Active').fold(0, (sum, item) => sum + (item['students'] as int));

    return Row(
      children: [
        Expanded(child: _buildMetricCard('Active', active.toString(), Icons.class_rounded, adminTheme)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Enrolled', totalStudents.toString(), Icons.groups_rounded, Colors.blueAccent)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Archived', archived.toString(), Icons.inventory_2_rounded, Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search course code or title...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: adminTheme, width: 2)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatusFilter,
                isExpanded: true,
                icon: const Icon(Icons.filter_list_rounded, color: Colors.grey),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedStatusFilter = value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> course, int originalIndex) {
    bool isArchived = course['status'] == 'Archived';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isArchived ? Colors.grey.shade300 : Colors.transparent, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course['title'], 
                  style: TextStyle(
                    fontWeight: FontWeight.w800, 
                    fontSize: 16, 
                    color: isArchived ? Colors.grey.shade600 : Colors.black87
                  )
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
                onPressed: () => _showCourseOptions(context, course, originalIndex),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: course['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  course['code'], 
                  style: TextStyle(color: course['color'], fontSize: 11, fontWeight: FontWeight.w800)
                ),
              ),
              const SizedBox(width: 8),
              if (isArchived)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'Archived', 
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.w700)
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.person_rounded, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Text(course['instructor'], style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.groups_rounded, size: 16, color: isArchived ? Colors.grey[400] : adminTheme),
                  const SizedBox(width: 6),
                  Text('${course['students']} Enrolled', style: TextStyle(color: isArchived ? Colors.grey.shade500 : adminTheme, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // ACTIONS & MODALS
  // ==============================================================

  void _showCourseOptions(BuildContext context, Map<String, dynamic> course, int index) {
    bool isArchived = course['status'] == 'Archived';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_document, color: Colors.black87),
                title: const Text('Edit Course Details', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  // Trigger edit modal here
                },
              ),
              ListTile(
                leading: Icon(isArchived ? Icons.unarchive_rounded : Icons.archive_rounded, color: isArchived ? Colors.green : Colors.orange),
                title: Text(isArchived ? 'Restore Course' : 'Archive Course', style: TextStyle(fontWeight: FontWeight.w600, color: isArchived ? Colors.green : Colors.orange.shade800)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleCourseStatus(index);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text('Delete Course', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCourse(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateCourseModal(BuildContext context) {
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
                  const Text('Create New Course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                  const SizedBox(height: 24),
                  
                  _buildTextField('Course Code (e.g., IT501)', Icons.tag_rounded),
                  const SizedBox(height: 16),
                  _buildTextField('Course Title', Icons.title_rounded),
                  const SizedBox(height: 16),
                  _buildTextField('Assign Instructor Email', Icons.alternate_email_rounded),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _courses.insert(0, {
                            'code': 'NEW101',
                            'title': 'Newly Created Course',
                            'instructor': 'Pending Assignment',
                            'students': 0,
                            'status': 'Active',
                            'color': Colors.indigo.shade400,
                          });
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Course successfully created!'), backgroundColor: Colors.green.shade600));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: adminTheme,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Create Course', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildTextField(String label, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: adminTheme, width: 2)),
      ),
    );
  }
}