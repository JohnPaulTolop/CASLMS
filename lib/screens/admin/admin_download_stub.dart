import 'package:flutter/services.dart';

Future<void> downloadAdminCsv(String content, String filename) async {
  await Clipboard.setData(ClipboardData(text: content));
}
