import 'package:flutter/material.dart';

class LiveClassroomEmbed extends StatelessWidget {
  const LiveClassroomEmbed({
    super.key,
    required this.connection,
    required this.onLeave,
  });
  final Map<String, dynamic> connection;
  final VoidCallback onLeave;
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Open the LMS in Chrome or Edge to join this live class.'),
  );
}
