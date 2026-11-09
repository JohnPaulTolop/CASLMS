import '../../core/app_colors.dart';

import 'package:flutter/material.dart';

import 'instructor_task_widgets.dart';

import '../../services/module_service.dart';
import 'section_audience_picker.dart';

class InstructorModuleBuilderScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final ModuleService? moduleService;
  final String? initialSectionId;
  final List<Map<String, dynamic>> sections;

  const InstructorModuleBuilderScreen({
    super.key,
    this.courseId = '',
    this.courseCode = '',
    this.courseTitle = '',
    this.moduleService,
    this.initialSectionId,
    required this.sections,
  });

  @override
  State<InstructorModuleBuilderScreen> createState() =>
      _InstructorModuleBuilderScreenState();
}

class _InstructorModuleBuilderScreenState
    extends State<InstructorModuleBuilderScreen> {
  Color get primaryTeal => AppColors.resolve(context, AppColors.primaryBlue);

  Color get background => AppColors.resolve(context, AppColors.background);

  Color get textDark => AppColors.resolve(context, AppColors.darkText);

  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);

  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  late final ModuleService _moduleService =
      widget.moduleService ?? ModuleService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _orderController = TextEditingController();

  bool _isPreparing = true;

  bool _isSaving = false;

  bool _publishImmediately = true;

  String? _errorMessage;
  List<Map<String, dynamic>> _sections = const [];
  List<String> _sectionIds = const [];

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
      final sections = widget.sections
          .where((section) => section['status'] == 'active')
          .toList();

      if (!mounted) {
        return;
      }

      _orderController.text = '$nextOrder';

      final requested = widget.initialSectionId?.trim() ?? '';

      setState(() {
        _isPreparing = false;
        _sections = sections;
        _sectionIds = sections.any((section) => section['id'] == requested)
            ? <String>[requested]
            : const <String>[];
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
    if (_sectionIds.isEmpty) {
      setState(() {
        _errorMessage = 'Choose the sections assigned to this module.';
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

        sectionIds: _sectionIds,

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
  Widget build(BuildContext context) => InstructorTaskScaffold(
    loading: _isPreparing,
    title: 'Create module',
    subtitle: 'Create learning content and assign its student audience.',
    contextLabel: [
      widget.courseCode,
      widget.courseTitle,
    ].where((v) => v.trim().isNotEmpty).join(' · '),
    busy: _isSaving,
    body: _buildBody(),
    footer: _isPreparing || widget.courseId.trim().isEmpty
        ? null
        : InstructorTaskActions(
            children: [
              FilledButton(
                onPressed: _isSaving ? null : _saveModule,
                child: Text(
                  _isSaving
                      ? 'Saving module…'
                      : _publishImmediately
                      ? 'Publish module'
                      : 'Save draft',
                ),
              ),
            ],
          ),
  );

  Widget _buildBody() {
    if (_isPreparing) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null && widget.courseId.trim().isEmpty) {
      return _buildFatalError();
    }
    return SingleChildScrollView(
      padding: InstructorTaskScaffold.paddingOf(context),
      child: Form(
        key: _formKey,
        child: InstructorFormColumns(
          primary: InstructorFormSection(
            title: 'Module details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('module-title'),
                  controller: _titleController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Introduction to Flutter',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Module title is required.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('module-description'),
                  controller: _descriptionController,
                  enabled: !_isSaving,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What will students learn?',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Module description is required.'
                      : null,
                ),
              ],
            ),
          ),
          secondary: InstructorFormSection(
            title: 'Availability',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('module-order'),
                  controller: _orderController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Module order'),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Enter a valid module order.'
                      : null,
                ),
                const SizedBox(height: 18),
                Text(
                  'Assigned sections',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'This controls who can access the module. It is separate from the section currently being viewed.',
                  style: TextStyle(fontSize: 12, height: 1.5, color: textGrey),
                ),
                const SizedBox(height: 8),
                SectionAudiencePicker(
                  sections: _sections,
                  value: _sectionIds,
                  enabled: !_isSaving,
                  onChanged: (value) => setState(() => _sectionIds = value),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Publish immediately',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: _publishImmediately,
                      onChanged: _isSaving
                          ? null
                          : (v) => setState(() => _publishImmediately = v),
                    ),
                  ],
                ),
                Text(
                  _publishImmediately
                      ? 'Enrolled students can access this module.'
                      : 'Only you can access this module until it is published.',
                  style: TextStyle(fontSize: 12, height: 1.6, color: textGrey),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  InstructorTaskNotice(text: _errorMessage!, error: true),
                ],
              ],
            ),
          ),
        ),
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

              style: TextStyle(color: textGrey, fontWeight: FontWeight.w600),
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
}
