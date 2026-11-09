import 'package:flutter/material.dart';

/// Keeps navigation controls inside the same column and inset as page content.
class AlignedPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AlignedPageAppBar({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
    this.inset = 16,
  });
  final AppBar child;
  final double maxWidth, inset;
  @override
  Size get preferredSize => child.preferredSize;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: child,
      ),
    ),
  );
}
