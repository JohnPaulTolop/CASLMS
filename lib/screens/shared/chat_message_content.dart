import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatMessageContent extends StatelessWidget {
  const ChatMessageContent({
    super.key,
    required this.message,
    required this.isMine,
    required this.accentColor,
    required this.textColor,
  });

  final Map<String, dynamic> message;
  final bool isMine;
  final Color accentColor;
  final Color textColor;

  String get _text => (message['text'] ?? '').toString().trim();
  String get _url => (message['attachmentUrl'] ?? '').toString().trim();
  String get _name =>
      (message['attachmentName'] ?? 'Attachment').toString().trim();
  String get _mimeType =>
      (message['attachmentMimeType'] ?? '').toString().toLowerCase();
  String get _kind =>
      (message['attachmentKind'] ?? '').toString().toLowerCase();

  bool get _isImage => _kind == 'image' || _mimeType.startsWith('image/');

  int get _sizeBytes {
    final value = message['attachmentSizeBytes'];
    return value is num ? value.toInt() : 0;
  }

  Future<void> _openAttachment(BuildContext context) async {
    final uri = Uri.tryParse(_url);
    if (uri == null || !uri.hasScheme) {
      _showOpenError(context);
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened && context.mounted) _showOpenError(context);
    } catch (_) {
      if (context.mounted) _showOpenError(context);
    }
  }

  void _showOpenError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Unable to open this attachment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _fileIcon() {
    if (_mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (_mimeType.contains('presentation')) return Icons.slideshow_outlined;
    if (_mimeType.contains('spreadsheet') || _mimeType.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (_mimeType.contains('word') || _mimeType == 'text/plain') {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final hasAttachment = _url.isNotEmpty;

    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (hasAttachment && _isImage)
          _buildImage(context)
        else if (hasAttachment)
          _buildFile(context),
        if (hasAttachment && _text.isNotEmpty) const SizedBox(height: 8),
        if (_text.isNotEmpty)
          Text(
            _text,
            style: TextStyle(color: textColor, fontSize: 13.5, height: 1.4),
          ),
      ],
    );
  }

  Widget _buildImage(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAttachment(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 150,
            maxWidth: 290,
            maxHeight: 260,
          ),
          child: Image.network(
            _url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 220,
                height: 150,
                alignment: Alignment.center,
                color: Colors.black12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isMine ? Colors.white : accentColor,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              width: 220,
              height: 120,
              alignment: Alignment.center,
              color: Colors.black12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: isMine ? Colors.white70 : accentColor,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFile(BuildContext context) {
    final size = _formatSize(_sizeBytes);

    return Material(
      color: isMine ? Colors.white.withValues(alpha: 0.15) : Colors.black12,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openAttachment(context),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 210, maxWidth: 310),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                Icon(
                  _fileIcon(),
                  color: isMine ? Colors.white : accentColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (size.isNotEmpty)
                        Text(
                          size,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.72),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.open_in_new_rounded,
                  color: textColor.withValues(alpha: 0.75),
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
