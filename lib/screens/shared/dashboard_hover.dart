import 'package:flutter/material.dart';

/// Adds pointer/focus feedback without owning taps or adding a tab stop.
/// The existing button, link or list tile remains responsible for activation.
class DashboardHover extends StatefulWidget {
  const DashboardHover({
    super.key,
    required this.child,
    this.accent = const Color(0xFF2563EB),
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            active && !reduceMotion ? -widget.lift : 0,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: active ? .12 : 0),
                blurRadius: active ? 20 : 0,
                spreadRadius: active ? 1 : 0,
                offset: Offset(0, active ? 7 : 0),
              ),
            ],
          ),
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
