import 'package:flutter/material.dart';

import '../core/theme_notifier.dart';
import 'shared/landing_experience.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );
  bool _paused = false;
  bool get _motionEnabled =>
      !_paused &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  void _updateMotion() {
    if (_motionEnabled) {
      if (!_ambient.isAnimating) _ambient.repeat();
    } else {
      _ambient.stop();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  void _enter(BuildContext context) => Navigator.pushNamed(context, '/auth');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = theme.scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: background,
      body: RepaintBoundary(
        key: const ValueKey('landing-page'),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: background)),
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: dark ? .18 : .16,
                    child: Image.asset(
                      'assets/images/landing/ssu-campus.jpg',
                      fit: BoxFit.cover,
                      alignment: const Alignment(.45, 0),
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        background.withValues(alpha: .35),
                        background.withValues(alpha: .05),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: LandingConnections(
                        animation: _ambient,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, viewport) {
                  final wide =
                      viewport.maxWidth >= 1000 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 21;
                  final inset = viewport.maxWidth < 600 ? 24.0 : 48.0;
                  return SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 1320,
                          minHeight: viewport.maxHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: inset,
                            vertical: 24,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _header(context, wide),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: wide ? 72 : 48,
                                ),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 550),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) => Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 12 * (1 - value)),
                                      child: child,
                                    ),
                                  ),
                                  child: wide
                                      ? Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              flex: 7,
                                              child: _hero(context, true),
                                            ),
                                            const SizedBox(width: 72),
                                            Expanded(
                                              flex: 4,
                                              child: _community(context, true),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _hero(context, false),
                                            const SizedBox(height: 48),
                                            _community(context, false),
                                          ],
                                        ),
                                ),
                              ),
                              _footer(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool wide) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Semantics(
          image: true,
          label: 'College of Arts and Sciences, Samar State University seal',
          child: Container(
            width: wide ? 54 : 44,
            height: wide ? 54 : 44,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/CASlogo.jpg',
                excludeFromSemantics: true,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'caslms',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: wide ? 24 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              if (wide)
                Text(
                  'College of Arts and Sciences',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (wide)
          TextButton(
            onPressed: () => _enter(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            child: const Text(
              'Sign in',
              style: TextStyle(fontFamily: 'Roboto'),
            ),
          ),
        if (!MediaQuery.disableAnimationsOf(context))
          IconButton(
            key: const ValueKey('landing-motion'),
            tooltip: _paused ? 'Resume animation' : 'Pause animation',
            onPressed: () {
              setState(() => _paused = !_paused);
              _updateMotion();
            },
            icon: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 21,
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () => ThemeNotifier.instance.setThemeMode(
            dark ? ThemeMode.light : ThemeMode.dark,
          ),
          icon: Icon(
            dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 21,
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context, bool wide) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAMAR STATE UNIVERSITY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Learn together.\n'),
                TextSpan(
                  text: 'Go further.',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: wide ? 66 : 42,
              height: 1.08,
              fontWeight: FontWeight.w700,
              letterSpacing: wide ? -2.6 : -1.6,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            'Your college community, closer together. Find your lessons, connect with classmates and instructors, and get the support you need to learn with confidence.',
            style: TextStyle(
              fontSize: 16,
              height: 1.65,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 30),
        FilledButton.icon(
          key: const ValueKey('landing-start'),
          onPressed: () => _enter(context),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          label: const Text(
            'Get started',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          iconAlignment: IconAlignment.end,
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const ValueKey('landing-sign-in'),
          onPressed: () => _enter(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            foregroundColor: theme.colorScheme.primary,
          ),
          child: const Text(
            'Already part of CAS? Sign in',
            style: TextStyle(fontFamily: 'Roboto', fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _community(BuildContext context, bool wide) => LandingCommunityPreview(
    animation: _ambient,
    motionEnabled: _motionEnabled,
  );

  Widget _footer(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 18),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 24,
      runSpacing: 8,
      children: [
        Text(
          'College of Arts and Sciences · Samar State University',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          'Made for our CAS community.',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
