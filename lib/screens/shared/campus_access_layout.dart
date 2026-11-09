import 'package:flutter/material.dart';

import '../../core/theme_notifier.dart';

/// Institutional framing for account access; the form retains its own state.
class CampusAccessLayout extends StatelessWidget {
  const CampusAccessLayout({
    super.key,
    required this.signUp,
    required this.busy,
    required this.child,
  });
  final bool signUp, busy;
  final Widget child;
  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: RepaintBoundary(
          key: const ValueKey('auth-page'),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: theme.scaffoldBackgroundColor),
              ),
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: dark ? .13 : .10,
                      child: Image.asset(
                        'assets/images/landing/ssu-campus.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    final wide =
                        viewport.maxWidth >= 1100 &&
                        MediaQuery.textScalerOf(context).scale(14) < 23;
                    final inset = viewport.maxWidth < 600 ? 20.0 : 40.0;
                    return SingleChildScrollView(
                      key: const ValueKey('auth-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 1240,
                            minHeight: viewport.maxHeight,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(inset, 18, inset, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Back to home',
                                      onPressed: busy
                                          ? null
                                          : () => _back(context),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ClipOval(
                                      child: Image.asset(
                                        'assets/images/CASlogo.jpg',
                                        width: 36,
                                        height: 36,
                                        semanticLabel:
                                            'College of Arts and Sciences seal',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'caslms',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -.9,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: dark
                                          ? 'Switch to light mode'
                                          : 'Switch to dark mode',
                                      onPressed: () =>
                                          ThemeNotifier.instance.setThemeMode(
                                            dark
                                                ? ThemeMode.light
                                                : ThemeMode.dark,
                                          ),
                                      icon: Icon(
                                        dark
                                            ? Icons.dark_mode_outlined
                                            : Icons.light_mode_outlined,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: wide ? 48 : 28,
                                  ),
                                  child: wide
                                      ? Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 36,
                                                  right: 60,
                                                ),
                                                child: _welcome(context),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 6,
                                              child: _form(context, true),
                                            ),
                                          ],
                                        )
                                      : Align(
                                          alignment: Alignment.topCenter,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 560,
                                            ),
                                            child: _form(context, false),
                                          ),
                                        ),
                                ),
                                Text(
                                  'College of Arts and Sciences · Samar State University',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    height: 1.5,
                                  ),
                                ),
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
      ),
    );
  }

  Widget _form(BuildContext context, bool wide) => Container(
    padding: wide ? const EdgeInsets.all(32) : EdgeInsets.zero,
    decoration: wide
        ? BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(24),
          )
        : null,
    child: child,
  );
  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR CAS COMMUNITY',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          signUp
              ? 'A new chapter,\ntogether.'
              : 'A familiar place.\nA fresh start.',
          style: const TextStyle(
            fontSize: 44,
            height: 1.12,
            letterSpacing: -1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          signUp
              ? 'Join a community that makes it easier to learn, ask questions, and move forward.'
              : 'Pick up where you left off. Your courses, conversations, and learning support are all here.',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 36),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.people_outline_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Learn with your classmates.\nStay connected with your instructors.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.65,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
