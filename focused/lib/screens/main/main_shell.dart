import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../focus/focus_screen.dart';
import '../friends/friends_screen.dart';
import '../planner/planner_screen.dart';
import '../settings/settings_screen.dart';
import '../today/today_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  static void switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    state?.setIndex(index);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex = _safeIndex(widget.initialIndex);

  void setIndex(int index) {
    setState(() {
      _currentIndex = _safeIndex(index);
    });
  }

  final List<Widget> _screens = const [
    PrimaryScrollController.none(child: TodayScreen()),
    PrimaryScrollController.none(child: PlannerScreen()),
    PrimaryScrollController.none(child: FocusScreen()),
    PrimaryScrollController.none(child: FriendsScreen()),
    PrimaryScrollController.none(child: SettingsScreen(embedded: true)),
  ];

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _currentIndex = _safeIndex(widget.initialIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark
          ? const Color(0xFF171A23)
          : Theme.of(context).colorScheme.surface,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF171A23)
                : Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              if (_currentIndex != index) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.view_timeline_outlined),
                selectedIcon: Icon(Icons.view_timeline_rounded),
                label: 'Planner',
              ),
              NavigationDestination(
                icon: Icon(Icons.center_focus_strong_outlined),
                selectedIcon: Icon(Icons.center_focus_strong_rounded),
                label: 'Focus',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: 'Friends',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _safeIndex(int value) => value.clamp(0, 4).toInt();
