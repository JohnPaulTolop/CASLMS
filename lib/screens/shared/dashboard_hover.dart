import '../../core/app_colors.dart';

import 'package:flutter/material.dart';

/// Adds pointer/focus feedback without owning taps or adding a tab stop.
/// The existing button, link or list tile remains responsible for activation.
class DashboardHover extends StatefulWidget {
  const DashboardHover({
    super.key,
    required this.child,
    this.accent = AppColors.primaryBlue,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.lift = 3,
    this.showBorder = true,
    this.enabled = true,
  });

  final Widget child;
  final Color accent;
  final BorderRadius borderRadius;
  final double lift;
  final bool showBorder;
  final bool enabled;

  @override
  State<DashboardHover> createState() => _DashboardHoverState();
}

class _DashboardHoverState extends State<DashboardHover> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (_hovered || _focused);
    return MouseRegion(
      // Preserve child cursors: informational cards must not imply a click.
      cursor: MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedContainer(
          duration: Duration.zero,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(borderRadius: widget.borderRadius),
          foregroundDecoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: active && widget.showBorder
                  ? widget.accent.withValues(alpha: _focused ? .60 : .35)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          // Reuse the child across animation frames and hover changes. Data
          // listeners and dashboard state are unaffected by the decoration.
          child: widget.child,
        ),
      ),
    );
  }
}
