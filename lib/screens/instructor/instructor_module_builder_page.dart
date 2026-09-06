import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import '../../services/module_service.dart';

class InstructorModuleBuilderScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseTitle;

  const InstructorModuleBuilderScreen({
    super.key,
    this.courseId = '',
    this.courseCode = '',
    this.courseTitle = '',
  });

  @override
  State<InstructorModuleBuilderScreen> createState() =>
      _InstructorModuleBuilderScreenState();
}

class _InstructorModuleBuilderScreenState
    extends State<InstructorModuleBuilderScreen> {
  static const Color primaryTeal = Color(0xFF00897B);

  static const Color background = Color(0xFFF7F9FC);

  static const Color textDark = Color(0xFF10182F);

  static const Color textGrey = Color(0xFF68738A);

  static const Color borderColor = Color(0xFFE6EAF0);

  final ModuleService _moduleService = ModuleService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _orderController = TextEditingController();

  bool _isPreparing = true;

  bool _isSaving = false;

  bool _publishImmediately = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _prepare();
  }

  Future<void> _prepare() async {
    final String courseId = widget.courseId.trim();

    if (courseId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparing = false;

        _errorMessage = 'Open a specific class before creating a module.';
      });

      return;
    }

    try {
      final int nextOrder = await _moduleService.getNextModuleOrder(
        courseId: courseId,
      );

      if (!mounted) {
        return;
      }

      _orderController.text = '$nextOrder';

      setState(() {
        _isPreparing = false;
      });
    } on ModuleServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparing = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreparing = false;

        _errorMessage = 'Unable to prepare the module form.';
      });
    }
  }

  Future<void> _saveModule() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int? order = int.tryParse(_orderController.text.trim());

    if (order == null || order <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid module order.';
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _moduleService.createModule(
        courseId: widget.courseId,

        title: _titleController.text,

        description: _descriptionController.text,

        order: order,

        status: _publishImmediately ? 'published' : 'draft',
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on ModuleServiceException catch (e) {
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

        _errorMessage = 'Unable to save the module.';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return instructorScaffold(
      context: context,
      backgroundColor: background,

      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: background,

        elevation: 0,

        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,

            color: textDark,

            size: 20,
          ),

          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),

        title: const Text(
          'Create New Module',

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
            constraints: const BoxConstraints(maxWidth: 800),

            child: _buildBody(),
          ),
        ),
      ),

      bottomNavigationBar: _errorMessage != null || _isPreparing
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),

                color: background,

                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveModule,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,

                    disabledBackgroundColor: primaryTeal.withValues(
                      alpha: 0.55,
                    ),

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
                      : Text(
                          _publishImmediately
                              ? 'Publish Module to Class'
                              : 'Save Module as Draft',

                          style: const TextStyle(
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

  Widget _buildBody() {
    if (_isPreparing) {
      return const Center(child: CircularProgressIndicator(color: primaryTeal));
    }

    if (_errorMessage != null && widget.courseId.trim().isEmpty) {
      return _buildFatalError();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),

      child: Form(
        key: _formKey,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _buildCourseCard(),

            const SizedBox(height: 26),

            const Text(
              'Module Details',

              style: TextStyle(
                color: textDark,

                fontSize: 18,

                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _titleController,

              enabled: !_isSaving,

              decoration: _inputDecoration(
                label: 'Module Title',

                hint: 'e.g. Introduction to Flutter',
              ),

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Module title is required.';
                }

                return null;
              },
            ),

            const SizedBox(height: 15),

            TextFormField(
              controller: _descriptionController,

              enabled: !_isSaving,

              minLines: 3,

              maxLines: 6,

              decoration: _inputDecoration(
                label: 'Module Description',

                hint: 'What will students learn in this module?',
              ),

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Module description is required.';
                }

                return null;
              },
            ),

            const SizedBox(height: 15),

            TextFormField(
              controller: _orderController,

              enabled: !_isSaving,

              keyboardType: TextInputType.number,

              decoration: _inputDecoration(label: 'Module Order', hint: '1'),

              validator: (value) {
                final int? parsed = int.tryParse(value?.trim() ?? '');

                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid module order.';
                }

                return null;
              },
            ),

            const SizedBox(height: 22),

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(17),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(16),

                border: Border.all(color: borderColor),
              ),

              child: Row(
                children: [
                  Container(
                    width: 42,

                    height: 42,

                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.10),

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: const Icon(
                      Icons.visibility_rounded,

                      color: primaryTeal,
                    ),
                  ),

                  const SizedBox(width: 13),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Publish immediately',

                          style: TextStyle(
                            color: textDark,

                            fontSize: 13,

                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        SizedBox(height: 3),

                        Text(
                          'Published modules become available to enrolled students.',

                          style: TextStyle(color: textGrey, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),

                  Switch(
                    value: _publishImmediately,

                    activeThumbColor: primaryTeal,

                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _publishImmediately = value;
                            });
                          },
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),

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

            _buildComingLaterCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard() {
    final String courseName = [
      widget.courseCode.trim(),
      widget.courseTitle.trim(),
    ].where((value) => value.isNotEmpty).join(' • ');

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: primaryTeal,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            width: 45,

            height: 45,

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),

              borderRadius: BorderRadius.circular(12),
            ),

            child: const Icon(Icons.school_rounded, color: Colors.white),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Creating module for',

                  style: TextStyle(color: Colors.white70, fontSize: 10.5),
                ),

                const SizedBox(height: 3),

                Text(
                  courseName.isEmpty ? widget.courseId : courseName,

                  style: const TextStyle(
                    color: Colors.white,

                    fontSize: 14,

                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingLaterCard() {
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
          Icon(Icons.info_outline_rounded, color: primaryTeal, size: 21),

          SizedBox(width: 11),

          Expanded(
            child: Text(
              'Learning-material uploads and AI-generated module content will be connected in later integration phases. This form currently creates the real Firestore module record.',

              style: TextStyle(color: textGrey, fontSize: 11, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFatalError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            const Icon(
              Icons.error_outline_rounded,

              color: Colors.redAccent,

              size: 50,
            ),

            const SizedBox(height: 12),

            Text(
              _errorMessage ?? 'Unable to create module.',

              textAlign: TextAlign.center,

              style: const TextStyle(
                color: textGrey,

                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 14),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,

      hintText: hint,

      filled: true,

      fillColor: Colors.white,

      labelStyle: const TextStyle(color: textGrey),

      hintStyle: const TextStyle(color: Color(0xFFA0A8B7)),

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
