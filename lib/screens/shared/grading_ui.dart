import 'package:flutter/material.dart';

const gradeBlue = Color(0xFF1769FF);
const gradeTeal = Color(0xFF00897B);
const gradeInk = Color(0xFF14233D);
const gradeMuted = Color(0xFF687B94);
const gradeBackground = Color(0xFFF4F7FC);
const gradeBorder = Color(0xFFE4EBF5);

Duration gradeMotion(BuildContext context, [int milliseconds = 240]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class GradeRoute<T> extends PageRouteBuilder<T> {
  GradeRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(.025, .02),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      );
}

/// One-way entrance: removing this widget never retains an outgoing grade.
class GradeEntrance extends StatelessWidget {
  const GradeEntrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: gradeMotion(context, 300),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

class GradeSurface extends StatelessWidget {
  const GradeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: gradeBorder),
      boxShadow: [
        BoxShadow(
          color: gradeInk.withValues(alpha: .025),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class GradeHero extends StatelessWidget {
  const GradeHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = gradeBlue,
    this.eyebrow = 'YOUR LEARNING',
    this.trailing,
  });
  final String title, subtitle, eyebrow;
  final IconData icon;
  final Color accent;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent, Color.lerp(accent, const Color(0xFF122C66), .5)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .16),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  eyebrow,
                  style: const TextStyle(
                    color: Color(0xFFDCEAFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              if (constraints.maxWidth > 600 && trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: constraints.maxWidth < 480 ? 24 : 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFE2EAFF),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          if (constraints.maxWidth <= 600 && trailing != null)
            Padding(padding: const EdgeInsets.only(top: 16), child: trailing!),
        ],
      ),
    ),
  );
}

class RoundGradeAction extends StatefulWidget {
  const RoundGradeAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = gradeTeal,
    this.size = 44,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color accent;
  final double size;
  @override
  State<RoundGradeAction> createState() => _RoundGradeActionState();
}

class _RoundGradeActionState extends State<RoundGradeAction> {
  bool _hover = false, _pressed = false, _focus = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.label,
    child: Semantics(
      button: true,
      label: widget.label,
      enabled: widget.onTap != null,
      child: AnimatedScale(
        scale: _pressed
            ? .93
            : _hover && widget.onTap != null
            ? 1.045
            : 1,
        duration: gradeMotion(context, 140),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.onTap == null
                  ? const Color(0xFFF0F3F8)
                  : widget.accent.withValues(alpha: _hover ? .16 : .09),
              border: Border.all(
                color: _focus
                    ? widget.accent
                    : widget.accent.withValues(alpha: .16),
                width: _focus ? 2 : 1,
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              onHover: (value) => setState(() => _hover = value),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              onFocusChange: (value) => setState(() => _focus = value),
              child: Icon(
                widget.icon,
                size: widget.size > 50 ? 27 : 21,
                color: widget.onTap == null ? gradeMuted : widget.accent,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class GradeShortcut extends StatefulWidget {
  const GradeShortcut({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = gradeTeal,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final Color accent;
  @override
  State<GradeShortcut> createState() => _GradeShortcutState();
}

class _GradeShortcutState extends State<GradeShortcut> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: gradeMotion(context, 180),
    decoration: BoxDecoration(
      color: _hover ? widget.accent.withValues(alpha: .035) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: _hover ? widget.accent.withValues(alpha: .45) : gradeBorder,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hover = value),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent.withValues(alpha: .09),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: gradeInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: gradeMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 18, color: widget.accent),
            ],
          ),
        ),
      ),
    ),
  );
}

class GradeStats extends StatelessWidget {
  const GradeStats({super.key, required this.items});
  final List<({String label, String value, IconData icon, Color color})> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => SizedBox(
              width:
                  (constraints.maxWidth - (items.length - 1) * 10) /
                  items.length,
              child: GradeSurface(
                padding: EdgeInsets.all(constraints.maxWidth < 600 ? 10 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item.icon, color: item.color, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.value,
                            style: const TextStyle(
                              color: gradeInk,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      style: const TextStyle(color: gradeMuted, fontSize: 12),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class GradeBadge extends StatelessWidget {
  const GradeBadge(this.text, {super.key, this.color = gradeBlue, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class GradeStateMessage extends StatelessWidget {
  const GradeStateMessage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.onRetry,
  });
  final String title, message;
  final IconData icon;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => GradeSurface(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEDF3FF),
            ),
            child: Icon(icon, color: gradeBlue, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: gradeInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: gradeMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
        ],
      ),
    ),
  );
}

InputDecoration gradeInput(String label, {IconData? icon, String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: gradeBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: gradeBorder),
      ),
    );

IconData gradeTypeIcon(String type) => switch (type) {
  'quiz' => Icons.quiz_outlined,
  'unit_test' => Icons.rule_folder_outlined,
  'assignment' => Icons.assignment_outlined,
  'exam' => Icons.fact_check_outlined,
  _ => Icons.task_alt_rounded,
};
String gradeNumber(double? value) => value == null
    ? '—'
    : value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
