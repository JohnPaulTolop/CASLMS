import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// A decorative course cover; the existing heading owns its typography.
class CourseBanner extends StatelessWidget {
  const CourseBanner({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final accent = AppColors.resolve(context, color);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final compact = constraints.maxWidth < 700;
      final surface = Theme.of(context).colorScheme.surface;
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accent.withValues(alpha: dark ? .08 : .07),
              surface,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: accent.withValues(alpha: dark ? .20 : .14),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: compact ? 240 : 460,
                        height: double.infinity,
                        child: CustomPaint(
                          painter: _CourseCoverArt(
                            accent: accent,
                            opacity: compact ? .18 : .65,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: compact ? 144 : 160),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 22 : 30,
                    vertical: compact ? 16 : 20,
                  ),
                  child: Align(alignment: Alignment.bottomLeft, child: child),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CourseCoverArt extends CustomPainter {
  const _CourseCoverArt({required this.accent, required this.opacity});
  final Color accent;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw in a fixed coordinate space so the cover crops like a thumbnail.
    canvas.save();
    canvas.translate(size.width - 440, (size.height - 220) / 2);
    final ink = Paint()..color = accent.withValues(alpha: opacity * .12);
    canvas.drawCircle(const Offset(352, 104), 154, ink);
    ink.color = accent.withValues(alpha: opacity * .10);
    canvas.drawCircle(const Offset(265, 118), 104, ink);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 4; column++) {
        ink.color = accent.withValues(alpha: opacity * .24);
        canvas.drawCircle(Offset(100 + column * 14, 32 + row * 14), 2, ink);
      }
    }

    canvas.save();
    canvas.translate(235, 100);
    canvas.rotate(-.20);
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, -63, 179, 118),
      const Radius.circular(10),
    );
    ink.color = accent.withValues(alpha: opacity * .23);
    canvas.drawRRect(frame, ink);
    ink.color = accent.withValues(alpha: opacity * .28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, -53, 159, 94),
        const Radius.circular(5),
      ),
      ink,
    );
    final line = Paint()
      ..color = accent.withValues(alpha: opacity * .65)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 4; row++) {
      final y = -31.0 + row * 15;
      canvas.drawLine(
        Offset(28 + (row.isOdd ? 12 : 0), y),
        Offset(112 + row * 8, y),
        line,
      );
    }
    ink.color = accent.withValues(alpha: opacity * .22);
    final keyboard = Path()
      ..moveTo(0, 60)
      ..lineTo(179, 60)
      ..lineTo(200, 77)
      ..lineTo(-21, 77)
      ..close();
    canvas.drawPath(keyboard, ink);
    canvas.restore();

    canvas.save();
    canvas.translate(198, 133);
    canvas.rotate(.22);
    ink.color = accent.withValues(alpha: opacity * .35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-32, -54, 64, 111),
        const Radius.circular(10),
      ),
      ink,
    );
    ink.color = accent.withValues(alpha: opacity * .25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-25, -41, 50, 77),
        const Radius.circular(4),
      ),
      ink,
    );
    line.strokeWidth = 3;
    canvas.drawLine(const Offset(-13, -12), const Offset(-20, -4), line);
    canvas.drawLine(const Offset(-20, -4), const Offset(-13, 4), line);
    canvas.drawLine(const Offset(13, -12), const Offset(20, -4), line);
    canvas.drawLine(const Offset(20, -4), const Offset(13, 4), line);
    canvas.drawLine(const Offset(4, -16), const Offset(-4, 8), line);
    canvas.drawCircle(const Offset(0, 46), 3, line);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CourseCoverArt oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.opacity != opacity;
}
