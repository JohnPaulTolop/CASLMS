import '../../core/app_colors.dart';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'instructor_task_widgets.dart';

import '../../services/learning_material_service.dart';
import '../../services/section_audience_service.dart';
import 'section_audience_picker.dart';

class InstructorAddLearningMaterialScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final String moduleTitle;
  final LearningMaterialService? materialService;
  final List<Map<String, dynamic>> sections;
  final List<String> moduleSectionIds;
  final String? initialSectionId;

  const InstructorAddLearningMaterialScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.moduleTitle,
    required this.sections,
    required this.moduleSectionIds,
    this.initialSectionId,
    this.materialService,
  });

  @override
  State<InstructorAddLearningMaterialScreen> createState() =>
      _InstructorAddLearningMaterialScreenState();
}

class _InstructorAddLearningMaterialScreenState
    extends State<InstructorAddLearningMaterialScreen> {
  // ============================================================
  // DESIGN
  // ============================================================

  Color get primaryTeal => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  Color get red => AppColors.resolve(context, AppColors.error);
  Color get blue => AppColors.resolve(context, AppColors.primaryBlue);
  Color get green => AppColors.resolve(context, AppColors.green);

  // ============================================================
  // SERVICE
  // ============================================================

  late final LearningMaterialService _materialService =
      widget.materialService ?? LearningMaterialService();

  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _urlController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isUploadingFile = true;

  bool _isSaving = false;

  String _status = 'published';

  String _linkType = 'link';

  PlatformFile? _selectedFile;

  Uint8List? _selectedFileBytes;
  late List<String> _sectionIds;

  @override
  void initState() {
    super.initState();
    final parent = SectionAudienceService.validate(widget.moduleSectionIds);
    final initial = widget.initialSectionId?.trim() ?? '';
    _sectionIds =
        initial.isNotEmpty && SectionAudienceService.allows(parent, initial)
        ? <String>[initial]
        : List<String>.from(parent);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();

    super.dispose();
  }

  // ============================================================
  // CHANGE MATERIAL SOURCE
  // ============================================================

  void _changeMode(bool uploadFile) {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isUploadingFile = uploadFile;
    });
  }

  // ============================================================
  // FILE PICKER
  //
  // Compatible with file_picker v12.
  // ============================================================

  // ============================================================
  // FILE PICKER
  //
  // FileType.any is used intentionally.
  //
  // Some Android document providers do not correctly expose
  // .doc / .docx files when FileType.custom is used.
  //
  // CASLMS therefore lets Android show normal files first,
  // then validates the extension itself.
  // ============================================================

  Future<void> _pickFile() async {
    if (_isSaving) {
      return;
    }

    try {
      final PlatformFile? file = await FilePicker.pickFile(type: FileType.any);

      // User cancelled.
      if (file == null) {
        return;
      }

      // ========================================================
      // VALIDATE EXTENSION
      // ========================================================

      final String extension = (file.extension ?? '').trim().toLowerCase();

      const Set<String> supportedExtensions = {
        // PDF
        'pdf',

        // Microsoft Word
        'doc',
        'docx',

        // PowerPoint
        'ppt',
        'pptx',

        // Excel
        'xls',
        'xlsx',

        // Text
        'txt',

        // Images
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',

        // Videos
        'mp4',
        'webm',
      };

      if (extension.isEmpty) {
        if (!mounted) {
          return;
        }

        _showError('The selected file has no supported extension.');

        return;
      }

      if (!supportedExtensions.contains(extension)) {
        if (!mounted) {
          return;
        }

        _showError('Unsupported file type: .$extension');

        return;
      }

      // ========================================================
      // READ FILE
      // ========================================================

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        if (!mounted) {
          return;
        }

        _showError('The selected file is empty.');

        return;
      }

      // ========================================================
      // 50 MB LIMIT
      // ========================================================

      const int maxFileSize = 50 * 1024 * 1024;

      if (bytes.length > maxFileSize) {
        if (!mounted) {
          return;
        }

        _showError('The selected file exceeds the 50 MB limit.');

        return;
      }

      if (!mounted) {
        return;
      }

      // ========================================================
      // SAVE SELECTED FILE
      // ========================================================

      setState(() {
        _selectedFile = file;
        _selectedFileBytes = bytes;
      });

      // Automatically use filename as title
      // when the title field is empty.
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = _fileNameWithoutExtension(file.name);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError('Unable to select file: $e');
    }
  }

  // ============================================================
  // REMOVE SELECTED FILE
  // ============================================================

  void _removeSelectedFile() {
    if (_isSaving) {
      return;
    }

    setState(() {
      _selectedFile = null;
      _selectedFileBytes = null;
    });
  }

  // ============================================================
  // SAVE MATERIAL
  // ============================================================

  Future<void> _saveMaterial() async {
    if (_isSaving) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // ==========================================================
    // FILE VALIDATION
    // ==========================================================

    if (_isUploadingFile) {
      if (_selectedFile == null || _selectedFileBytes == null) {
        _showError('Please select a file first.');

        return;
      }
    }
    if (_sectionIds.isEmpty) {
      _showError('Choose the sections assigned to this material.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      // ========================================================
      // UPLOAD FILE
      // ========================================================

      if (_isUploadingFile) {
        await _materialService.uploadLearningMaterial(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          title: _titleController.text,
          description: _descriptionController.text,
          fileName: _selectedFile!.name,
          fileBytes: _selectedFileBytes!,
          sectionIds: _sectionIds,
          status: _status,
        );
      }
      // ========================================================
      // EXTERNAL LINK
      // ========================================================
      else {
        await _materialService.createLinkMaterial(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          title: _titleController.text,
          description: _descriptionController.text,
          url: _urlController.text,
          sectionIds: _sectionIds,
          resourceType: _linkType,
          status: _status,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _status == 'published'
                ? 'Learning material published successfully.'
                : 'Learning material saved as draft.',
          ),
          backgroundColor: primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Return true so the module page refreshes.
      Navigator.of(context).pop(true);
    } on LearningMaterialException catch (e) {
      if (!mounted) {
        return;
      }

      _showError(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError('Unable to save learning material: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _fileNameWithoutExtension(String fileName) {
    final int lastDot = fileName.lastIndexOf('.');

    if (lastDot <= 0) {
      return fileName;
    }

    return fileName
        .substring(0, lastDot)
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final double kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final double mb = kb / 1024;

    return '${mb.toStringAsFixed(1)} MB';
  }

  IconData _fileIcon(String fileName) {
    final String extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;

      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_rounded;

      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;

      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;

      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;

      case 'mp4':
      case 'webm':
        return Icons.video_file_rounded;

      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileColor(String fileName) {
    final String extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return red;

      case 'ppt':
      case 'pptx':
        return AppColors.amber;

      case 'xls':
      case 'xlsx':
        return green;

      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return AppColors.purple;

      case 'mp4':
      case 'webm':
        return blue;

      default:
        return primaryTeal;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) => InstructorTaskScaffold(
    title: 'Add learning material',
    subtitle: 'Upload a file or share a useful link with your class.',
    contextLabel: widget.moduleTitle,
    busy: _isSaving,
    body: SingleChildScrollView(
      padding: InstructorTaskScaffold.paddingOf(context),
      child: Form(
        key: _formKey,
        child: InstructorFormColumns(
          primary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InstructorFormSection(
                title: 'Material details',
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('material-title'),
                      controller: _titleController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Chapter 1 lecture notes',
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Please enter a material title'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_isSaving,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              InstructorFormSection(
                title: 'Source',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 18),
                    if (_isUploadingFile)
                      _buildFileSection()
                    else
                      _buildLinkSection(),
                  ],
                ),
              ),
            ],
          ),
          secondary: InstructorFormSection(
            title: 'Visibility',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Assigned sections',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Defaults to the module audience and can only be narrowed.',
                ),
                SectionAudiencePicker(
                  sections: widget.sections,
                  parentAudience: widget.moduleSectionIds,
                  value: _sectionIds,
                  enabled: !_isSaving,
                  onChanged: (value) => setState(() => _sectionIds = value),
                ),
                const Divider(height: 28),
                _buildStatusSection(),
              ],
            ),
          ),
        ),
      ),
    ),
    footer: InstructorTaskActions(
      children: [
        FilledButton(
          onPressed: _isSaving ? null : _saveMaterial,
          child: Text(
            _isSaving
                ? 'Saving material…'
                : _status == 'published'
                ? 'Publish material'
                : 'Save draft',
          ),
        ),
      ],
    ),
  );

  // ============================================================
  // MODULE CARD
  // ============================================================

  // ============================================================
  // SOURCE SELECTOR
  // ============================================================

  Widget _buildModeSelector() => SegmentedButton<bool>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(
        value: true,
        icon: Icon(Icons.upload_file_outlined),
        label: Text('File'),
      ),
      ButtonSegment(
        value: false,
        icon: Icon(Icons.link_rounded),
        label: Text('Link'),
      ),
    ],
    selected: {_isUploadingFile},
    onSelectionChanged: _isSaving ? null : (v) => _changeMode(v.first),
  );

  // ============================================================
  // FILE SECTION
  // ============================================================

  Widget _buildFileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildLabel('File'),

        const SizedBox(height: 8),

        if (_selectedFile == null)
          InkWell(
            onTap: _isSaving ? null : _pickFile,

            borderRadius: BorderRadius.circular(18),

            child: Container(
              width: double.infinity,

              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),

              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,

                borderRadius: BorderRadius.circular(18),

                border: Border.all(color: borderColor, width: 1.5),
              ),

              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,

                    backgroundColor: Color(0xFFE7F5F2),

                    child: Icon(
                      Icons.cloud_upload_outlined,

                      color: primaryTeal,

                      size: 31,
                    ),
                  ),

                  SizedBox(height: 13),

                  Text(
                    'Choose Learning Material',

                    style: TextStyle(
                      color: textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    'PDF, Word, PowerPoint, Excel, images, text or video',

                    textAlign: TextAlign.center,

                    style: TextStyle(color: textGrey, fontSize: 11.5),
                  ),

                  SizedBox(height: 3),

                  Text(
                    'Maximum file size: 50 MB',

                    style: TextStyle(color: textGrey, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          )
        else
          _buildSelectedFileCard(),
      ],
    );
  }

  // ============================================================
  // SELECTED FILE
  // ============================================================

  Widget _buildSelectedFileCard() {
    final PlatformFile file = _selectedFile!;

    final Color color = _fileColor(file.name);

    final int byteSize = _selectedFileBytes?.length ?? 0;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(13),
            ),

            child: Icon(_fileIcon(file.name), color: color),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  file.name,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _formatFileSize(byteSize),

                  style: TextStyle(color: textGrey, fontSize: 11),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _isSaving ? null : _removeSelectedFile,

            icon: Icon(Icons.close_rounded, color: textGrey),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LINK SECTION
  // ============================================================

  Widget _buildLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildLabel('Link Type'),

        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _linkType,

          items: const [
            DropdownMenuItem(
              value: 'link',
              child: Text('Website / Resource Link'),
            ),

            DropdownMenuItem(value: 'video', child: Text('Video Link')),
          ],

          onChanged: _isSaving
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _linkType = value;
                  });
                },

          decoration: _inputDecoration(
            hint: 'Select type',
            icon: Icons.category_outlined,
          ),
        ),

        const SizedBox(height: 18),

        _buildLabel('External URL'),

        const SizedBox(height: 8),

        TextFormField(
          controller: _urlController,

          enabled: !_isSaving,

          keyboardType: TextInputType.url,

          autocorrect: false,

          decoration: _inputDecoration(
            hint: 'https://example.com/resource',
            icon: Icons.link_rounded,
          ),

          validator: (value) {
            if (_isUploadingFile) {
              return null;
            }

            if (value == null || value.trim().isEmpty) {
              return 'Please enter the external URL';
            }

            final Uri? uri = Uri.tryParse(value.trim());

            if (uri == null ||
                !uri.hasScheme ||
                !uri.hasAuthority ||
                (uri.scheme != 'http' && uri.scheme != 'https')) {
              return 'Enter a valid HTTP or HTTPS URL';
            }

            return null;
          },
        ),
      ],
    );
  }

  // ============================================================
  // VISIBILITY STATUS
  // ============================================================

  Widget _buildStatusSection() => RadioGroup<String>(
    groupValue: _status,
    onChanged: (v) {
      if (!_isSaving && v != null) setState(() => _status = v);
    },
    child: Column(
      children: [
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: 'published',
          enabled: !_isSaving,
          title: const Text('Publish now'),
          subtitle: const Text('Available to enrolled students.'),
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: 'draft',
          enabled: !_isSaving,
          title: const Text('Save as draft'),
          subtitle: const Text('Keep private until you publish.'),
        ),
      ],
    ),
  );

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(String title, {bool optional = false}) {
    return Row(
      children: [
        Text(
          title,

          style: TextStyle(
            color: textDark,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),

        if (optional) ...[
          const SizedBox(width: 5),

          Text('(optional)', style: TextStyle(color: textGrey, fontSize: 10.5)),
        ],
      ],
    );
  }

  // ============================================================
  // INPUT STYLE
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,

      hintStyle: const TextStyle(color: Color(0xFFA0A8B7), fontSize: 12.5),

      prefixIcon: Icon(icon, color: textGrey, size: 20),

      filled: true,

      fillColor: Theme.of(context).colorScheme.surface,

      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: BorderSide(color: borderColor),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: BorderSide(color: borderColor),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: BorderSide(color: primaryTeal, width: 1.6),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: BorderSide(color: red),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: BorderSide(color: red, width: 1.5),
      ),
    );
  }
}
