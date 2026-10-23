import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> downloadAdminCsv(String content, String filename) async {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
}
