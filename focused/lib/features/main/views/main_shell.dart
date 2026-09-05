import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../tasks/providers/task_provider.dart';
import '../../wellbeing/providers/usage_provider.dart';
import '../../focus/views/focus_screen.dart';
import '../../friends/views/friends_screen.dart';
import '../../planner/views/planner_hub_body.dart';
import '../../planner/views/planner_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../today/views/today_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  final PlannerArea? plannerArea;

  const MainShell({super.key, this.initialIndex = 0, this.plannerArea});

  static bool switchToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    if (state != null) {
      state.setIndex(index);
      return true;
    }
    return false;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  late final List<Widget> _screens;

  void setIndex(int index) {
    setState(() {
      _currentIndex = _safeIndex(index);
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _safeIndex(widget.initialIndex);
    _screens = [
      const PrimaryScrollController.none(child: TodayScreen()),
      PrimaryScrollController.none(
        child: PlannerScreen(initialArea: widget.plannerArea),
      ),
      const PrimaryScrollController.none(child: FocusScreen()),
      const PrimaryScrollController.none(child: FriendsScreen()),
      const PrimaryScrollController.none(child: SettingsScreen(embedded: true)),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialPermissions();
    });
  }

  Future<void> _requestInitialPermissions() async {
    if (!mounted) return;
    // 1. Request native notification permission popup directly
    await context.read<TaskProvider>().requestNotificationPermission();

    // 2. Check and refresh usage permission state
    if (!mounted) return;
    await context.read<UsageProvider>().refreshPermissionAndUsage();
  }

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
      child: PopScope(
        canPop: _currentIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            setState(() {
              _currentIndex = 0;
            });
          }
        },
        child: Scaffold(
          body: IndexedStack(index: _currentIndex, children: _screens),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF171A23)
                  : Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                height: 68,
                labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                  states,
                ) {
                  final isSelected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.1,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF1E293B))
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.55)
                              : const Color(0xFF64748B)),
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                height: 68,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
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
                    icon: _NavIcon(
                      assetName: 'nav_home.svg',
                      fallbackIcon: Icons.home_outlined,
                      color: Color(0xFFFF8228), // Orange
                      isSelected: false,
                      size: 24,
                    ),
                    selectedIcon: _NavIcon(
                      assetName: 'nav_home.svg',
                      fallbackIcon: Icons.home_rounded,
                      color: Color(0xFFFF8228), // Orange
                      isSelected: true,
                      size: 24,
                    ),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: _NavIcon(
                      assetName: 'nav_planner.svg',
                      fallbackIcon: Icons.view_timeline_outlined,
                      color: Color(0xFF58CC02), // Green
                      isSelected: false,
                      size: 24,
                    ),
                    selectedIcon: _NavIcon(
                      assetName: 'nav_planner.svg',
                      fallbackIcon: Icons.view_timeline_rounded,
                      color: Color(0xFF58CC02), // Green
                      isSelected: true,
                      size: 24,
                    ),
                    label: 'Planner',
                  ),
                  NavigationDestination(
                    icon: _NavIcon(
                      assetName: 'nav_focus.svg',
                      fallbackIcon: Icons.center_focus_strong_outlined,
                      color: Color(0xFFFF5252), // Red
                      isSelected: false,
                      size: 24,
                    ),
                    selectedIcon: _NavIcon(
                      assetName: 'nav_focus.svg',
                      fallbackIcon: Icons.center_focus_strong_rounded,
                      color: Color(0xFFFF5252), // Red
                      isSelected: true,
                      size: 24,
                    ),
                    label: 'Focus',
                  ),
                  NavigationDestination(
                    icon: _NavIcon(
                      assetName: 'nav_friends.svg',
                      alternateAssetName: 'friends_icon.svg',
                      fallbackIcon: Icons.people_alt_outlined,
                      color: Color(0xFF9B51E0), // Purple
                      isSelected: false,
                      size: 24,
                    ),
                    selectedIcon: _NavIcon(
                      assetName: 'nav_friends.svg',
                      alternateAssetName: 'friends_icon.svg',
                      fallbackIcon: Icons.people_alt_rounded,
                      color: Color(0xFF9B51E0), // Purple
                      isSelected: true,
                      size: 24,
                    ),
                    label: 'Friends',
                  ),
                  NavigationDestination(
                    icon: _NavIcon(
                      assetName: 'nav_settings.svg',
                      fallbackIcon: Icons.settings_outlined,
                      color: Color(0xFF0EA5E9), // Bluish
                      isSelected: false,
                      size: 24,
                    ),
                    selectedIcon: _NavIcon(
                      assetName: 'nav_settings.svg',
                      fallbackIcon: Icons.settings_rounded,
                      color: Color(0xFF0EA5E9), // Bluish
                      isSelected: true,
                      size: 24,
                    ),
                    label: 'Settings',
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

class _NavIcon extends StatelessWidget {
  final String assetName;
  final String? alternateAssetName;
  final IconData fallbackIcon;
  final Color color;
  final bool isSelected;
  final double size;

  const _NavIcon({
    required this.assetName,
    this.alternateAssetName,
    required this.fallbackIcon,
    required this.color,
    required this.isSelected,
    this.size = 24.0,
  });

  static final Map<String, bool> _assetCache = {};

  static Future<String?> _resolveAssetPath(
    String primaryName, [
    String? alternateName,
  ]) async {
    final primaryPath = 'assets/navbar_icon/$primaryName';
    if (_assetCache[primaryPath] == true) return primaryPath;
    try {
      await rootBundle.load(primaryPath);
      _assetCache[primaryPath] = true;
      return primaryPath;
    } catch (_) {
      _assetCache[primaryPath] = false;
    }

    if (alternateName != null) {
      final altPath = 'assets/navbar_icon/$alternateName';
      if (_assetCache[altPath] == true) return altPath;
      try {
        await rootBundle.load(altPath);
        _assetCache[altPath] = true;
        return altPath;
      } catch (_) {
        _assetCache[altPath] = false;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<String?>(
      future: _resolveAssetPath(assetName, alternateAssetName),
      builder: (context, snapshot) {
        final path = snapshot.data;
        Widget iconWidget;

        if (path != null) {
          iconWidget = SvgPicture.asset(
            path,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        } else {
          iconWidget = Icon(
            fallbackIcon,
            size: size - 2,
            color: isSelected
                ? color
                : (isDark ? Colors.white70 : const Color(0xFF4A5568)),
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 10 : 4,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedScale(
            scale: isSelected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: iconWidget,
          ),
        );
      },
    );
  }
}

int _safeIndex(int value) => value.clamp(0, 4).toInt();
