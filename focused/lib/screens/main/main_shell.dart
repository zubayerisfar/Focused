import 'package:flutter/material.dart';

import '../focus/focus_screen.dart';
import '../planner/planner_screen.dart';
import '../today/today_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Each destination owns its scrolling independently. Keeping the three
  // pages in an IndexedStack preserves Planner/Focus state when switching tabs,
  // while PrimaryScrollController.none prevents offstage scroll views from
  // sharing the Scaffold's primary controller during layout/tests.
  final List<Widget> _screens = const [
    PrimaryScrollController.none(child: TodayScreen()),
    PrimaryScrollController.none(child: PlannerScreen()),
    PrimaryScrollController.none(child: FocusScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _FocusedBottomNavigation(
        currentIndex: _currentIndex,
        onSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _FocusedBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const _FocusedBottomNavigation({
    required this.currentIndex,
    required this.onSelected,
  });

  static const _items = <_NavItem>[
    _NavItem(
      label: 'Today',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItem(
      label: 'Planner',
      icon: Icons.view_timeline_outlined,
      selectedIcon: Icons.view_timeline_rounded,
    ),
    _NavItem(
      label: 'Focus',
      icon: Icons.center_focus_strong_outlined,
      selectedIcon: Icons.center_focus_strong_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = index == currentIndex;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.label,
                  child: InkWell(
                    key: ValueKey(
                      'nav-${item.label.toLowerCase()}',
                    ),
                    onTap: () => onSelected(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 50,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: selected
                                ? Border.all(
                                    color: scheme.primary.withOpacity(0.28),
                                  )
                                : null,
                          ),
                          child: Icon(
                            selected ? item.selectedIcon : item.icon,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            size: 25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
