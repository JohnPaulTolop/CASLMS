import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import '../../services/instructor_course_service.dart';

import 'instructor_class_details_page.dart';

class InstructorCreateCourseScreen extends StatefulWidget {
  const InstructorCreateCourseScreen({super.key});

  @override
  State<InstructorCreateCourseScreen> createState() =>
      _InstructorCreateCourseScreenState();
}

class _InstructorCreateCourseScreenState
    extends State<InstructorCreateCourseScreen> {
  static const Color primaryTeal = Color(0xFF00897B);

  static const Color background = Color(0xFFF7F9FC);

  static const Color textDark = Color(0xFF10182F);

  static const Color textGrey = Color(0xFF68738A);

  static const Color borderColor = Color(0xFFE6EAF0);

  final InstructorCourseService _courseService = InstructorCourseService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _courseCodeController = TextEditingController();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _academicYearController = TextEditingController();

  bool _isSaving = false;

  String? _errorMessage;

  String _semester = '1st Semester';

  final List<String> _semesters = const [
    '1st Semester',
    '2nd Semester',
    'Summer',
  ];

  @override
  void initState() {
    super.initState();

    final int year = DateTime.now().year;

    _academicYearController.text = '$year-${year + 1}';
  }

  @override
  void dispose() {
    _courseCodeController.dispose();

    _titleController.dispose();

    _descriptionController.dispose();

    _academicYearController.dispose();

    super.dispose();
  }

  Future<void> _createCourse() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;

      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> course = await _courseService.createCourse(
        code: _courseCodeController.text,

        title: _titleController.text,

        description: _descriptionController.text,

        semester: _semester,

        academicYear: _academicYearController.text,
      );

      if (!mounted) {
        return;
      }

      final String courseId = (course['id'] ?? '').toString();

      final String code = (course['code'] ?? '').toString();

      final String title = (course['title'] ?? '').toString();

      final String instructorName = (course['instructorName'] ?? 'Instructor')
          .toString();

      Navigator.pushReplacement(
        context,

        MaterialPageRoute(
          builder: (context) => InstructorClassDetailsScreen(
            courseId: courseId,

            title: title,

            courseCode: code,

            instructorName: instructorName,
          ),
        ),
      );
    } on InstructorCourseServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;

        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;

        _errorMessage = 'Unable to create course.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return instructorScaffold(
      context: context,
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,

        elevation: 0,

        centerTitle: true,

        leading: IconButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context);
                },

          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,

            color: textDark,

            size: 20,
          ),
        ),

        title: const Text(
          'Create New Subject',

          style: TextStyle(
            color: textDark,

            fontSize: 18,

            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),

            child: Form(
              key: _formKey,

              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _buildHeader(),

                    const SizedBox(height: 26),

                    _buildTextField(
                      controller: _courseCodeController,

                      label: 'Course Code',

                      hint: 'e.g. IT302',

                      icon: Icons.tag_rounded,

                      capitalization: TextCapitalization.characters,

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Course code is required.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    _buildTextField(
                      controller: _titleController,

                      label: 'Course Title',

                      hint: 'e.g. Advanced Mobile Development',

                      icon: Icons.menu_book_rounded,

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Course title is required.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    _buildTextField(
                      controller: _descriptionController,

                      label: 'Description',

                      hint: 'Describe what students will learn.',

                      icon: Icons.description_outlined,

                      maxLines: 4,

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Course description is required.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      initialValue: _semester,

                      decoration: _inputDecoration(
                        label: 'Semester',

                        icon: Icons.calendar_month_rounded,
                      ),

                      items: _semesters.map((semester) {
                        return DropdownMenuItem<String>(
                          value: semester,

                          child: Text(semester),
                        );
                      }).toList(),

                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _semester = value;
                              });
                            },
                    ),

                    const SizedBox(height: 15),

                    _buildTextField(
                      controller: _academicYearController,

                      label: 'Academic Year',

                      hint: 'e.g. 2026-2027',

                      icon: Icons.school_outlined,

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Academic year is required.';
                        }

                        return null;
                      },
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 18),

                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.all(14),

                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.08),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Text(
                          _errorMessage!,

                          style: const TextStyle(
                            color: Colors.redAccent,

                            fontSize: 11.5,

                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    _buildClassCodeInfo(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),

          color: background,

          child: ElevatedButton(
            onPressed: _isSaving ? null : _createCourse,

            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,

              disabledBackgroundColor: primaryTeal.withValues(alpha: 0.5),

              elevation: 0,

              padding: const EdgeInsets.symmetric(vertical: 16),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),

            child: _isSaving
                ? const SizedBox(
                    width: 22,

                    height: 22,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,

                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Create Subject',

                    style: TextStyle(
                      color: Colors.white,

                      fontSize: 14,

                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(19),

      decoration: BoxDecoration(
        color: primaryTeal,

        borderRadius: BorderRadius.circular(18),
      ),

      child: const Row(
        children: [
          Icon(Icons.add_box_rounded, color: Colors.white, size: 32),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'New Subject / Course',

                  style: TextStyle(
                    color: Colors.white,

                    fontSize: 16,

                    fontWeight: FontWeight.w800,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Create the course first. You will add modules and assessments afterward.',

                  style: TextStyle(
                    color: Colors.white70,

                    fontSize: 11,

                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCodeInfo() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F5),

        borderRadius: BorderRadius.circular(15),
      ),

      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.vpn_key_rounded, color: primaryTeal),

          SizedBox(width: 11),

          Expanded(
            child: Text(
              'A unique class code will be generated automatically after the course is created. Share that code with students so they can join the class.',

              style: TextStyle(color: textGrey, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) {
    return TextFormField(
      controller: controller,

      enabled: !_isSaving,

      maxLines: maxLines,

      textCapitalization: capitalization,

      validator: validator,

      decoration: _inputDecoration(label: label, hint: hint, icon: icon),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,

      hintText: hint,

      prefixIcon: Icon(icon, color: primaryTeal),

      filled: true,

      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: const BorderSide(color: borderColor),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: const BorderSide(color: borderColor),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: const BorderSide(color: primaryTeal, width: 1.8),
      ),
    );
  }
}
