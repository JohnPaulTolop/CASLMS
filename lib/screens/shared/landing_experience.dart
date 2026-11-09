import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A paint-only ambient layer: text and the campus photograph stay still.
class LandingConnections extends CustomPainter {
  LandingConnections({required this.animation, required this.color})
    : super(repaint: animation);
  final Animation<double> animation;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value * math.pi * 2;
    final points = List.generate(
      8,
      (i) => Offset(
        size.width * (.42 + (i % 3) * .24) + math.sin(phase + i) * 14,
        size.height * (.13 + i * .105) + math.cos(phase + i * .8) * 12,
      ),
    );
    final line = Paint()
      ..color = color.withValues(alpha: .08)
      ..strokeWidth = 1;
    final dot = Paint()..color = color.withValues(alpha: .22);
    for (var i = 0; i < points.length; i++) {
      if (i > 0) canvas.drawLine(points[i - 1], points[i], line);
      canvas.drawCircle(points[i], i.isEven ? 3 : 2, dot);
    }
  }

  @override
  bool shouldRepaint(LandingConnections oldDelegate) =>
      oldDelegate.color != color || oldDelegate.animation != animation;
}

class LandingCommunityPreview extends StatefulWidget {
  const LandingCommunityPreview({
    super.key,
    required this.animation,
    required this.motionEnabled,
  });
  final Animation<double> animation;
  final bool motionEnabled;
  @override
  State<LandingCommunityPreview> createState() =>
      _LandingCommunityPreviewState();
}

class _LandingCommunityPreviewState extends State<LandingCommunityPreview> {
  int _selected = 0;
  static const _icons = [
    Icons.people_outline_rounded,
    Icons.menu_book_outlined,
    Icons.auto_awesome_outlined,
  ];
  static const _titles = [
    'Stay connected',
    'Learn at your pace',
    'Find your next step',
  ];
  static const _bodies = [
    'Keep conversations and class updates close.',
    'Lessons and resources, ready when you are.',
    'See what’s due and ask for help along the way.',
  ];
  static const _previews = [
    'Your community, connected.',
    'A little progress, every day.',
    'A helping hand, when you need it.',
  ];
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .90),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .8)),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A learning space\nfor all of us.',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: RepaintBoundary(
              child: SizedBox(
                height: 158,
                child: AnimatedBuilder(
                  animation: widget.animation,
                  builder: (context, _) {
                    final phase = widget.animation.value * math.pi * 2;
                    return LayoutBuilder(
                      builder: (context, bounds) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _OrbitPainter(
                                phase: phase,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary.withValues(alpha: .12),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: .3),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 250),
                              child: Icon(
                                _icons[_selected],
                                key: ValueKey(_selected),
                                color: colors.primary,
                                size: 30,
                              ),
                            ),
                          ),
                          for (var i = 0; i < 3; i++)
                            Positioned(
                              left:
                                  bounds.maxWidth / 2 +
                                  math.cos(i * math.pi * 2 / 3 - math.pi / 2) *
                                      math.min(110, bounds.maxWidth * .38) -
                                  18,
                              top:
                                  61 +
                                  math.sin(i * math.pi * 2 / 3 - math.pi / 2) *
                                      53 +
                                  (widget.motionEnabled
                                      ? math.sin(phase + i * 2) * 5
                                      : 0),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.primary.withValues(
                                      alpha: .25,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  _icons[i],
                                  color: colors.primary,
                                  size: 17,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Text(
            _previews[_selected],
            key: const ValueKey('landing-preview-caption'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Semantics(
              selected: _selected == i,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('landing-feature-$i'),
                  onTap: () => setState(() => _selected = i),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selected == i
                          ? colors.primary.withValues(alpha: .09)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            _icons[i],
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titles[i],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _bodies[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.phase, required this.color});
  final double phase;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final width = math.min(110.0, size.width * .38);
    final rect = Rect.fromCenter(center: center, width: width * 2, height: 106);
    canvas.drawOval(
      rect,
      Paint()
        ..color = color.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 3; i++) {
      final angle = phase + i * math.pi * 2 / 3;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * width, math.sin(angle) * 53),
        3,
        Paint()..color = color.withValues(alpha: .65),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
