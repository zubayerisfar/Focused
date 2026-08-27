import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../calendar/calendar_screen.dart';
import '../focus/focus_screen.dart';
import '../habits/habits_screen.dart';
import '../planner/planner_screen.dart';
import '../today/today_screen.dart';
import '../wellbeing/wellbeing_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TodayScreen(),
    PlannerScreen(),
    CalendarScreen(),
    FocusScreen(),
    HabitsScreen(),
    WellbeingScreen(),
  ];

  final List<String> _titles = const [
    'Today',
    'Planner',
    'Calendar',
    'Focus',
    'Habits',
    'Insights',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_currentIndex == 0 || _currentIndex == 1)
            IconButton(
              tooltip: 'New task',
              onPressed: () {
                context.push('/task/new');
              },
              icon: const Icon(Icons.add_rounded),
            ),

          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
            icon: const Icon(Icons.settings_outlined),
          ),

          const SizedBox(width: 4),
        ],
      ),

      body: IndexedStack(index: _currentIndex, children: _screens),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,

        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,

        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Today',
          ),

          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Planner',
          ),

          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),

          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Focus',
          ),

          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Habits',
          ),

          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
