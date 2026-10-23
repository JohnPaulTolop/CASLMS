import 'package:flutter/material.dart';

/// Responsive navigation shared by the student and instructor portals.
///
/// Phones keep the four most-used destinations visible and place secondary
/// destinations in a bottom sheet. Wider layouts show every destination.
/// The destination indexes intentionally match the existing main pages.
class RoleNavigationBar extends StatelessWidget {
  const RoleNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.instructor,
  });

  static const double _wideBreakpoint = 720;

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool instructor;

  Color get _accentColor =>
      instructor ? const Color(0xFF00897B) : const Color(0xFF1769FF);

  List<_RoleDestination> get _destinations => <_RoleDestination>[
    _RoleDestination(
      index: 0,
      label: instructor ? 'Dashboard' : 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _RoleDestination(
      index: 1,
      label: instructor ? 'My Courses' : 'My Classes',
      icon: instructor ? Icons.class_outlined : Icons.folder_outlined,
      activeIcon: instructor ? Icons.class_rounded : Icons.folder_rounded,
    ),
    _RoleDestination(
      index: 2,
      label: instructor ? 'Grading' : 'Tasks',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
    ),
    _RoleDestination(
      index: 3,
      label: instructor ? 'Analytics' : 'Progress',
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
    ),
    const _RoleDestination(
      index: 4,
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
    const _RoleDestination(
      index: 5,
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
    ),
    const _RoleDestination(
      index: 6,
      label: 'AI Assistant',
      icon: Icons.smart_toy_outlined,
      activeIcon: Icons.smart_toy_rounded,
    ),
    if (!instructor)
      const _RoleDestination(
        index: 7,
        label: 'Activities & Scores',
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check,
      ),
    if (!instructor)
      const _RoleDestination(
        index: 8,
        label: 'Posted Grades',
        icon: Icons.lock_outline,
        activeIcon: Icons.lock,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    // A full-width container that sits flush against the bottom edges
    // to look like a standard navigation bar.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE8ECF3))),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF172033).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4), // Shadow points upwards
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide =
                constraints.maxWidth >= (instructor ? _wideBreakpoint : 1000);

            return Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 7,
                  ),
                  child: wide
                      ? _buildWideNavigation()
                      : _buildCompactNavigation(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWideNavigation() {
    return Row(
      children: _destinations
          .map(
            (_RoleDestination destination) => Expanded(
              child: _NavigationItem(
                destination: destination,
                selected: selectedIndex == destination.index,
                accentColor: _accentColor,
                onTap: () => onSelected(destination.index),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCompactNavigation(BuildContext context) {
    final List<_RoleDestination> allDestinations = _destinations;
    final List<_RoleDestination> primaryDestinations = <_RoleDestination>[
      allDestinations[0],
      allDestinations[1],
      allDestinations[2],
      allDestinations[instructor ? 6 : 5],
    ];
    final bool secondaryDestinationSelected = !primaryDestinations.any(
      (destination) => destination.index == selectedIndex,
    );

    return Row(
      children: <Widget>[
        ...primaryDestinations.map(
          (_RoleDestination destination) => Expanded(
            child: _NavigationItem(
              destination: destination,
              selected: selectedIndex == destination.index,
              accentColor: _accentColor,
              onTap: () => onSelected(destination.index),
            ),
          ),
        ),
        Expanded(
          child: _NavigationItem(
            destination: const _RoleDestination(
              index: -1,
              label: 'More',
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view_rounded,
            ),
            selected: secondaryDestinationSelected,
            accentColor: _accentColor,
            onTap: () => _showMoreDestinations(context),
          ),
        ),
      ],
    );
  }

  Future<void> _showMoreDestinations(BuildContext context) async {
    final List<_RoleDestination> allDestinations = _destinations;
    final List<_RoleDestination> secondaryDestinations = <_RoleDestination>[
      allDestinations[3],
      allDestinations[4],
      allDestinations[instructor ? 5 : 6],
      if (!instructor) allDestinations[7],
      if (!instructor) allDestinations[8],
    ];

    final int? destinationIndex = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      useSafeArea: true,
      builder: (BuildContext _) {
        return _MoreDestinationsSheet(
          destinations: secondaryDestinations,
          selectedIndex: selectedIndex,
          accentColor: _accentColor,
        );
      },
    );

    if (destinationIndex != null) {
      onSelected(destinationIndex);
    }
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final _RoleDestination destination;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? accentColor : const Color(0xFF7B8498);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 57),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.11)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: destination.index >= 7
                            ? accentColor.withValues(
                                alpha: selected ? .16 : .08,
                              )
                            : Colors.transparent,
                      ),
                      child: Icon(
                        selected ? destination.activeIcon : destination.icon,
                        size: 23,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 10.5,
                      height: 1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}

class _MoreDestinationsSheet extends StatelessWidget {
  const _MoreDestinationsSheet({
    required this.destinations,
    required this.selectedIndex,
    required this.accentColor,
  });

  final List<_RoleDestination> destinations;
  final int selectedIndex;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DEE9),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'More',
              style: TextStyle(
                color: Color(0xFF10182F),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Open another part of your workspace',
              style: TextStyle(
                color: Color(0xFF68738A),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            GridView(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 132,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: destinations
                  .map(
                    (_RoleDestination destination) => _MoreDestinationCard(
                      destination: destination,
                      selected: selectedIndex == destination.index,
                      accentColor: accentColor,
                      onTap: () => Navigator.of(context).pop(destination.index),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreDestinationCard extends StatelessWidget {
  const _MoreDestinationCard({
    required this.destination,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final _RoleDestination destination;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accentColor.withValues(alpha: 0.10)
          : const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.28)
                  : const Color(0xFFE8ECF3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor
                      : accentColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? destination.activeIcon : destination.icon,
                  color: selected ? Colors.white : accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                destination.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? accentColor : const Color(0xFF263149),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleDestination {
  const _RoleDestination({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
