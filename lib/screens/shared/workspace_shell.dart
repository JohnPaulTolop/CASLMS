import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../core/app_colors.dart';
import '../../core/theme_notifier.dart';
import 'workspace_widgets.dart';

typedef WorkspaceDestination = ({int index, String label, IconData icon});

Future<bool> confirmWorkspaceLogout(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of your CASLMS account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    ) ??
    false;

const studentDestinations = <WorkspaceDestination>[
  (index: 0, label: 'Home', icon: Icons.space_dashboard_outlined),
  (index: 6, label: 'AI Assistant', icon: Icons.auto_awesome_rounded),
  (index: 1, label: 'Courses', icon: Icons.menu_book_outlined),
  (index: 2, label: 'Tasks', icon: Icons.assignment_outlined),
  (index: 11, label: 'Notes', icon: Icons.note_alt_outlined),
  (index: 10, label: 'Calendar', icon: Icons.calendar_month_outlined),
  (index: 3, label: 'Results', icon: Icons.insights_outlined),
  (index: 4, label: 'Profile', icon: Icons.person_outline_rounded),
  (index: 5, label: 'Messages', icon: Icons.chat_bubble_outline_rounded),
];

const instructorDestinations = <WorkspaceDestination>[
  (index: 0, label: 'Dashboard', icon: Icons.space_dashboard_outlined),
  (index: 1, label: 'My Courses', icon: Icons.menu_book_outlined),
  (index: 2, label: 'Grading', icon: Icons.fact_check_outlined),
  (index: 7, label: 'Calendar', icon: Icons.calendar_month_outlined),
  (index: 3, label: 'Insights', icon: Icons.insights_outlined),
  (index: 5, label: 'Messages', icon: Icons.chat_bubble_outline_rounded),
];

/// Layout only: authentication, destination indexes and page state stay with
/// the existing role screens. Every decision uses the available container.
class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({
    super.key,
    required this.child,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onInbox,
    required this.onLogout,
    required this.name,
    this.photoUrl,
    this.role = 'Student',
    this.unreadCount = 0,
    this.profileIndex = 4,
    this.notificationsAvailable = true,
  });
  final Widget child;
  final List<WorkspaceDestination> destinations;
  final int selectedIndex, unreadCount, profileIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onInbox, onLogout;
  final String name, role;
  final String? photoUrl;
  final bool notificationsAvailable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final desktop = box.maxWidth >= 1100 && scale <= 1.4;
      if (!desktop) {
        final inset = workspaceInset(box.maxWidth);
        return _MobileWorkspaceChrome(
          selectedIndex: selectedIndex,
          header: Padding(
            padding: EdgeInsets.fromLTRB(inset, 10, inset, 12),
            child: _topBar(context, false),
          ),
          navigation: WorkspaceBottomNavigation(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
          ),
          child: child,
        );
      }
      return Scaffold(
        backgroundColor: AppColors.resolve(context, AppColors.background),
        bottomNavigationBar: desktop
            ? null
            : WorkspaceBottomNavigation(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
              ),
        body: Row(
          children: [
            if (desktop) _sidebar(context),
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1450),
                    child: LayoutBuilder(
                      builder: (context, content) {
                        final inset = workspaceInset(content.maxWidth);
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                inset,
                                desktop ? 24 : 10,
                                inset,
                                desktop ? 36 : 12,
                              ),
                              child: _topBar(context, desktop),
                            ),
                            Expanded(child: child),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  String get _destinationLabel {
    for (final destination in destinations) {
      if (destination.index == selectedIndex) return destination.label;
    }
    // The bell can open Inbox even in shells that omit its sidebar entry.
    if (role == 'Instructor' && selectedIndex == profileIndex) return 'Profile';
    if (role == 'Instructor' && selectedIndex == 6) return 'Teaching AI';
    return selectedIndex == 9 ? 'Inbox' : 'Workspace';
  }

  Widget _topBar(BuildContext context, bool desktop) => Row(
    children: [
      Expanded(
        child: desktop
            ? Row(
                children: [
                  Icon(
                    Icons.home_outlined,
                    size: 17,
                    color: AppColors.resolve(context, AppColors.secondaryText),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '/',
                      style: TextStyle(color: Color(0xFFCCD3DF)),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _destinationLabel,
                      style: TextStyle(
                        color: AppColors.resolve(
                          context,
                          AppColors.secondaryText,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              )
            : const WorkspaceBrand(compact: true),
      ),
      const SizedBox(width: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.resolve(
                context,
                Colors.white,
              ).withValues(alpha: .8),
              border: Border.all(
                color: AppColors.resolve(context, AppColors.inputBorder),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (role == 'Instructor')
                  IconButton(
                    key: const ValueKey('instructor-assistant-entry'),
                    tooltip: 'Teaching AI',
                    onPressed: () => onSelected(6),
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.auto_awesome_rounded,
                      size: 21,
                      color: AppColors.resolve(context, AppColors.link),
                    ),
                  ),
                IconButton(
                  key: const ValueKey('header-theme-button'),
                  visualDensity: desktop
                      ? null
                      : const VisualDensity(horizontal: -2, vertical: -2),
                  padding: desktop ? null : EdgeInsets.zero,
                  constraints: desktop
                      ? null
                      : const BoxConstraints.tightFor(width: 40, height: 40),
                  tooltip: Theme.of(context).brightness == Brightness.dark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onPressed: () => ThemeNotifier.instance.setThemeMode(
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    size: 21,
                    color: AppColors.resolve(context, AppColors.darkText),
                  ),
                ),
                IconButton(
                  visualDensity: desktop
                      ? null
                      : const VisualDensity(horizontal: -2, vertical: -2),
                  padding: desktop ? null : EdgeInsets.zero,
                  constraints: desktop
                      ? null
                      : const BoxConstraints.tightFor(width: 40, height: 40),
                  tooltip: notificationsAvailable
                      ? 'Notifications${unreadCount > 0 ? ', $unreadCount unread' : ''}'
                      : 'Notifications unavailable',
                  onPressed: onInbox,
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    smallSize: 7,
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 21,
                      color: AppColors.resolve(context, AppColors.darkText),
                    ),
                  ),
                ),
                Container(
                  height: 18,
                  width: 1,
                  color: AppColors.resolve(context, AppColors.inputBorder),
                ),
                if (role == 'Instructor')
                  PopupMenuButton<String>(
                    key: const ValueKey('instructor-account-menu'),
                    tooltip: 'Account and preferences',
                    icon: const Icon(Icons.account_circle_outlined, size: 21),
                    onSelected: (value) {
                      if (value == 'profile') onSelected(profileIndex);
                      if (value == 'logout') onLogout();
                      if (value == 'theme') {
                        ThemeNotifier.instance.setThemeMode(
                          Theme.of(context).brightness == Brightness.dark
                              ? ThemeMode.light
                              : ThemeMode.dark,
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Text('My profile'),
                      ),
                      PopupMenuItem(
                        value: 'theme',
                        child: Text(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'Use light theme'
                              : 'Use dark theme',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Text('Log out'),
                      ),
                    ],
                  )
                else
                  IconButton(
                    visualDensity: desktop
                        ? null
                        : const VisualDensity(horizontal: -2, vertical: -2),
                    padding: desktop ? null : EdgeInsets.zero,
                    constraints: desktop
                        ? null
                        : const BoxConstraints.tightFor(width: 40, height: 40),
                    tooltip: 'Logout',
                    onPressed: onLogout,
                    icon: Icon(
                      Icons.logout_rounded,
                      size: 19,
                      color: AppColors.resolve(context, AppColors.darkText),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _sidebar(BuildContext context) => Container(
    key: const ValueKey('desktop-sidebar'),
    width: 224,
    decoration: BoxDecoration(
      color: AppColors.resolve(context, Colors.white),
      border: Border(
        right: BorderSide(
          color: AppColors.resolve(context, AppColors.inputBorder),
        ),
      ),
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          key: const ValueKey('sidebar-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, box.maxHeight - 56),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: WorkspaceBrand(),
                    ),
                    const SizedBox(height: 52),
                    const Padding(
                      padding: EdgeInsets.only(left: 14, bottom: 14),
                      child: WorkspaceEyebrow('WORKSPACE'),
                    ),
                    for (final d in destinations.where(
                      (d) => role != 'Student' || d.index != profileIndex,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _SidebarDestination(
                          destination: d,
                          selected: selectedIndex == d.index,
                          count: d.label == 'Inbox' ? unreadCount : 0,
                          onTap: () => onSelected(d.index),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: () => onSelected(profileIndex),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              WorkspaceAvatar(
                                name: name,
                                photoUrl: photoUrl,
                                size: 36,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$role account',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.resolve(
                                          context,
                                          AppColors.secondaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.unfold_more_rounded,
                                color: AppColors.resolve(
                                  context,
                                  AppColors.secondaryText,
                                ),
                                size: 18,
                              ),
                            ],
                          ),
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
  );
}

double workspaceInset(double width) => width >= 800
    ? 36
    : width >= 600
    ? 28
    : 20;

class WorkspaceBrand extends StatelessWidget {
  const WorkspaceBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 28 : 36,
        height: compact ? 28 : 36,
        decoration: BoxDecoration(
          color: AppColors.resolve(context, AppColors.primaryBlue),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          Icons.school_rounded,
          color: Colors.white,
          size: compact ? 18 : 21,
        ),
      ),
      SizedBox(width: compact ? 7 : 10),
      Flexible(
        child: Text(
          'caslms',
          maxLines: 1,
          style: TextStyle(
            color: AppColors.resolve(context, AppColors.darkText),
            fontSize: compact ? 18 : 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
    ],
  );
}

class WorkspaceAvatar extends StatelessWidget {
  const WorkspaceAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    required this.size,
  });
  final String name;
  final String? photoUrl;
  final double size;
  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : (words.first.characters.first +
                  (words.length > 1 ? words.last.characters.first : ''))
              .toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: const Color(0xFFECE9E3),
      child: Text(
        initials,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: const Color(0xFF6D675E),
          fontSize: size * .31,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Semantics(
      label: '$name profile',
      image: true,
      child: ClipOval(
        child: photoUrl == null || photoUrl!.isEmpty
            ? fallback
            : Image.network(
                photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, error, trace) => fallback,
              ),
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });
  final WorkspaceDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected
          ? AppColors.resolve(context, AppColors.blueTint)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('nav-${destination.index}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Icon(
                destination.icon,
                size: 20,
                color: AppColors.resolve(
                  context,
                  selected ? AppColors.primaryBlue : AppColors.secondaryText,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  destination.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.resolve(
                      context,
                      selected
                          ? AppColors.primaryBlue
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
              if (count > 0)
                WorkspacePill(
                  label: count > 99 ? '99+' : '$count',
                  color: AppColors.resolve(context, AppColors.secondaryText),
                  background: selected ? Colors.white : AppColors.background,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MobileWorkspaceChrome extends StatefulWidget {
  const _MobileWorkspaceChrome({
    required this.selectedIndex,
    required this.header,
    required this.navigation,
    required this.child,
  });
  final int selectedIndex;
  final Widget header, navigation, child;
  @override
  State<_MobileWorkspaceChrome> createState() => _MobileWorkspaceChromeState();
}

class _MobileWorkspaceChromeState extends State<_MobileWorkspaceChrome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _visibility;
  late final Animation<Offset> _headerSlide, _navigationSlide;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _visibility = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _headerSlide = Tween(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(_visibility);
    _navigationSlide = Tween(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(_visibility);
  }

  @override
  void didUpdateWidget(covariant _MobileWorkspaceChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _show(true);
  }

  void _show(bool visible) {
    if (_visible == visible) return;
    setState(() => _visible = visible);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = visible ? 1 : 0;
    } else if (visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.direction == ScrollDirection.reverse) {
      _show(false);
    } else if (notification.direction == ScrollDirection.forward) {
      _show(true);
    }
    return false;
  }

  Widget _bar(Widget child, {bool bottom = false}) => ClipRect(
    child: SizeTransition(
      sizeFactor: _visibility,
      alignment: bottom ? Alignment.bottomCenter : Alignment.topCenter,
      child: SlideTransition(
        position: bottom ? _navigationSlide : _headerSlide,
        child: IgnorePointer(
          ignoring: !_visible,
          child: ExcludeFocus(
            excluding: !_visible,
            child: ExcludeSemantics(excluding: !_visible, child: child),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    bottomNavigationBar: SafeArea(
      top: false,
      child: _bar(widget.navigation, bottom: true),
    ),
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          _bar(widget.header),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _visibility.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class WorkspaceBottomNavigation extends StatelessWidget {
  const WorkspaceBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<WorkspaceDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  bool get _student =>
      destinations.any((d) => d.index == 10 && d.label == 'Calendar') &&
      destinations.any((d) => d.index == 6) &&
      destinations.any((d) => d.index == 2 && d.label == 'Tasks');
  List<WorkspaceDestination> get _primary =>
      (_student ||
          destinations.any((d) => d.index == 2 && d.label == 'Grading'))
      ? [
          for (final index in (_student ? [0, 1, 6, 2] : [0, 1, 2, 5]))
            destinations.firstWhere((d) => d.index == index),
        ]
      : destinations.take(4).toList();
  List<WorkspaceDestination> get _secondary => destinations
      .where((d) => !_primary.any((primary) => primary.index == d.index))
      .toList();
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              key: const ValueKey('mobile-navigation'),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  for (final d in _primary)
                    _item(
                      context,
                      d.index == 6 ? 'AI' : d.label,
                      d.icon,
                      selectedIndex == d.index,
                      () => onSelected(d.index),
                      ValueKey('nav-${d.index}'),
                    ),
                  if (destinations.length > 4)
                    _item(
                      context,
                      'More',
                      Icons.more_horiz_rounded,
                      _secondary.any((d) => d.index == selectedIndex),
                      () => _more(context),
                      const ValueKey('nav-more'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _item(
    BuildContext context,
    String label,
    IconData icon,
    bool selected,
    VoidCallback tap,
    Key key,
  ) => Expanded(
    child: Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected
              ? AppColors.resolve(context, AppColors.blueTint)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            key: key,
            onTap: tap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 48,
              child: Center(
                child: Icon(
                  icon,
                  size: 23,
                  color: AppColors.resolve(
                    context,
                    selected || label == 'AI'
                        ? AppColors.primaryBlue
                        : AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _more(BuildContext context) async {
    final index = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your workspace',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                for (final d in _secondary)
                  _SidebarDestination(
                    destination: d,
                    selected: selectedIndex == d.index,
                    onTap: () => Navigator.pop(context, d.index),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (index != null) onSelected(index);
  }
}
