import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import '../../services/learning_material_service.dart';

class InstructorAddLearningMaterialScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final String moduleTitle;

  const InstructorAddLearningMaterialScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.moduleTitle,
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

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);

  static const Color red = Color(0xFFE45757);
  static const Color blue = Color(0xFF1769FF);
  static const Color green = Color(0xFF26A65B);

  // ============================================================
  // SERVICE
  // ============================================================

  final LearningMaterialService _materialService = LearningMaterialService();

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
        return const Color(0xFFFF9418);

      case 'xls':
      case 'xlsx':
        return green;

      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return const Color(0xFF7B4DFF);

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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,

      child: instructorScaffold(
        context: context,
        backgroundColor: background,

        // ======================================================
        // APP BAR
        // ======================================================
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          foregroundColor: textDark,
          centerTitle: true,

          title: const Text(
            'Add Learning Material',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        // ======================================================
        // BODY
        //
        // IMPORTANT:
        // Align(topCenter) prevents the form from being
        // vertically centered / pushed away.
        // ======================================================
        body: SafeArea(
          top: false,

          child: Align(
            alignment: Alignment.topCenter,

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),

              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),

                child: Form(
                  key: _formKey,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // ========================================
                      // CURRENT MODULE
                      // ========================================

                      _buildModuleCard(),

                      const SizedBox(height: 24),

                      // ========================================
                      // SOURCE
                      // ========================================
                      const Text(
                        'Material Source',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 10),

                      _buildModeSelector(),

                      const SizedBox(height: 24),

                      // ========================================
                      // TITLE
                      // ========================================
                      _buildLabel('Title'),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _titleController,

                        enabled: !_isSaving,

                        textCapitalization: TextCapitalization.sentences,

                        textInputAction: TextInputAction.next,

                        decoration: _inputDecoration(
                          hint: 'e.g. Chapter 1 Lecture Notes',
                          icon: Icons.title_rounded,
                        ),

                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a material title';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // ========================================
                      // DESCRIPTION
                      // ========================================
                      _buildLabel('Description', optional: true),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _descriptionController,

                        enabled: !_isSaving,

                        minLines: 3,
                        maxLines: 5,

                        textCapitalization: TextCapitalization.sentences,

                        decoration: _inputDecoration(
                          hint: 'Add a short description or instructions...',
                          icon: Icons.notes_rounded,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ========================================
                      // FILE / LINK SECTION
                      // ========================================
                      if (_isUploadingFile)
                        _buildFileSection()
                      else
                        _buildLinkSection(),

                      const SizedBox(height: 24),

                      // ========================================
                      // VISIBILITY
                      // ========================================
                      _buildStatusSection(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ======================================================
        // BOTTOM SAVE BUTTON
        //
        // IMPORTANT FIX:
        // heightFactor: 1 prevents Center from taking the
        // entire remaining screen height.
        // ======================================================
        bottomNavigationBar: SafeArea(
          top: false,

          child: Container(
            color: background,

            padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),

            child: Center(
              heightFactor: 1,

              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),

                child: SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveMaterial,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,

                      disabledBackgroundColor: primaryTeal.withValues(
                        alpha: 0.55,
                      ),

                      foregroundColor: Colors.white,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),

                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,

                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _status == 'published'
                                ? Icons.publish_rounded
                                : Icons.save_outlined,
                          ),

                    label: Text(
                      _isSaving
                          ? _isUploadingFile
                                ? 'Uploading...'
                                : 'Saving...'
                          : _status == 'published'
                          ? 'Publish Material'
                          : 'Save as Draft',

                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MODULE CARD
  // ============================================================

  Widget _buildModuleCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: primaryTeal.withValues(alpha: 0.07),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: primaryTeal.withValues(alpha: 0.18)),
      ),

      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,

            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.12),

              borderRadius: BorderRadius.circular(13),
            ),

            child: const Icon(Icons.menu_book_rounded, color: primaryTeal),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Adding material to',
                  style: TextStyle(color: textGrey, fontSize: 11),
                ),

                const SizedBox(height: 3),

                Text(
                  widget.moduleTitle,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    color: textDark,
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

  // ============================================================
  // SOURCE SELECTOR
  // ============================================================

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),

      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF3),

        borderRadius: BorderRadius.circular(14),
      ),

      child: Row(
        children: [
          Expanded(
            child: _sourceButton(
              selected: _isUploadingFile,

              icon: Icons.upload_file_rounded,

              text: 'Upload File',

              onTap: () {
                _changeMode(true);
              },
            ),
          ),

          Expanded(
            child: _sourceButton(
              selected: !_isUploadingFile,

              icon: Icons.link_rounded,

              text: 'External Link',

              onTap: () {
                _changeMode(false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceButton({
    required bool selected,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(11),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        padding: const EdgeInsets.symmetric(vertical: 12),

        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,

          borderRadius: BorderRadius.circular(11),

          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),

                    blurRadius: 8,

                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, size: 18, color: selected ? primaryTeal : textGrey),

            const SizedBox(width: 7),

            Text(
              text,

              style: TextStyle(
                color: selected ? primaryTeal : textGrey,

                fontSize: 12,

                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                color: Colors.white,

                borderRadius: BorderRadius.circular(18),

                border: Border.all(color: borderColor, width: 1.5),
              ),

              child: const Column(
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
                      fontWeight: FontWeight.w800,
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
        color: Colors.white,

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

                  style: const TextStyle(
                    color: textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _formatFileSize(byteSize),

                  style: const TextStyle(color: textGrey, fontSize: 11),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _isSaving ? null : _removeSelectedFile,

            icon: const Icon(Icons.close_rounded, color: textGrey),
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

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Visibility',

          style: TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 10),

        _statusCard(
          value: 'published',

          title: 'Publish Now',

          subtitle: 'Students enrolled in the course can access this material.',

          icon: Icons.visibility_rounded,

          color: green,
        ),

        const SizedBox(height: 9),

        _statusCard(
          value: 'draft',

          title: 'Save as Draft',

          subtitle: 'Only you can access the material until it is published.',

          icon: Icons.edit_note_rounded,

          color: const Color(0xFFFF9418),
        ),
      ],
    );
  }

  Widget _statusCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final bool selected = _status == value;

    return InkWell(
      onTap: _isSaving
          ? null
          : () {
              setState(() {
                _status = value;
              });
            },

      borderRadius: BorderRadius.circular(15),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),

        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(15),

          border: Border.all(
            color: selected ? color : borderColor,

            width: selected ? 1.7 : 1,
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,

              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),

                borderRadius: BorderRadius.circular(12),
              ),

              child: Icon(icon, color: color, size: 21),
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,

                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            Radio<String>(
              value: value,
              groupValue: _status,
              activeColor: color,

              onChanged: _isSaving
                  ? null
                  : (newValue) {
                      if (newValue == null) {
                        return;
                      }

                      setState(() {
                        _status = newValue;
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(String title, {bool optional = false}) {
    return Row(
      children: [
        Text(
          title,

          style: const TextStyle(
            color: textDark,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),

        if (optional) ...[
          const SizedBox(width: 5),

          const Text(
            '(optional)',

            style: TextStyle(color: textGrey, fontSize: 10.5),
          ),
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

      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),

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

        borderSide: const BorderSide(color: primaryTeal, width: 1.6),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: const BorderSide(color: red),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),

        borderSide: const BorderSide(color: red, width: 1.5),
      ),
    );
  }
}
