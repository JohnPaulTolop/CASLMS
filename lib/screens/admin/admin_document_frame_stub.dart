import 'package:flutter/material.dart';

class AdminDocumentFrame extends StatelessWidget {
  const AdminDocumentFrame({super.key, required this.uri});
  final Uri uri;
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Use Open original to view this document.'));
}
