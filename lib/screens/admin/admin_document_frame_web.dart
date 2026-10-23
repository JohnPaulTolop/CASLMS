import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class AdminDocumentFrame extends StatelessWidget {
  const AdminDocumentFrame({super.key, required this.uri});
  final Uri uri;
  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    key: ValueKey(uri.toString()),
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      // Render with our bundled PDF.js viewer rather than relying on a browser
      // PDF plugin inside a sandboxed cross-origin storage iframe.
      frame.src = Uri.parse(web.document.baseURI)
          .resolve('document-preview.html')
          .replace(
            fragment: Uri(queryParameters: {'file': uri.toString()}).query,
          )
          .toString();
      frame.title = 'Instructor document preview';
      frame.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-downloads',
      );
      frame.setAttribute('referrerpolicy', 'no-referrer');
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
    },
  );
}
