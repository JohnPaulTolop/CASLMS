import 'package:flutter/material.dart';

import 'workspace_shell.dart';

/// Compatibility entry point for callers that render only the navigation bar.
/// Destination indexes remain identical to the existing role screens.
class RoleNavigationBar extends StatelessWidget {
  const RoleNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.instructor,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool instructor;
  @override
  Widget build(BuildContext context) => WorkspaceBottomNavigation(
    destinations: instructor ? instructorDestinations : studentDestinations,
    selectedIndex: selectedIndex,
    onSelected: onSelected,
  );
}
