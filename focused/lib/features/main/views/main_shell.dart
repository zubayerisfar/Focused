import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/glass_container.dart';
import '../../tasks/providers/task_provider.dart';
import '../../groups/views/group_screen.dart';
import '../../friends/views/friends_screen.dart';
import '../../planner/views/planner_hub_body.dart';
import '../../planner/views/planner_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../today/views/today_screen.dart';
import '../../../core/network/network_connectivity_service.dart';

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
  final _plannerKey = GlobalKey<PlannerScreenState>();
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
        child: PlannerScreen(key: _plannerKey, initialArea: widget.plannerArea),
      ),
      const PrimaryScrollController.none(child: GroupScreen()),
      const PrimaryScrollController.none(child: FriendsScreen()),
      const PrimaryScrollController.none(child: SettingsScreen(embedded: true)),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialPermissions();
    });
  }

  Future<void> _requestInitialPermissions() async {
    if (!mounted) return;
    // Request native notification permission popup directly
    await context.read<TaskProvider>().requestNotificationPermission();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_currentIndex == 1) {
            final handled = _plannerKey.currentState?.handleBack() ?? false;
            if (handled) return;
          }
          if (_currentIndex != 0) {
            setState(() {
              _currentIndex = 0;
            });
            return;
          }
          SystemNavigator.pop();
        },
        child: GlassScaffoldBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: IndexedStack(index: _currentIndex, children: _screens),
            bottomNavigationBar: ValueListenableBuilder<bool>(
              valueListenable:
                  NetworkConnectivityService.instance.isOnlineNotifier,
              builder: (context, isOnline, _) {
                return _FloatingGlassNavBar(
                  currentIndex: _currentIndex,
                  isOnline: isOnline,
                  onTap: (index) {
                    if (index == 2 || index == 3) {
                      NetworkConnectivityService.instance.checkNow();
                    }
                    if (_currentIndex != index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isOnline;
  final ValueChanged<int> onTap;

  const _FloatingGlassNavBar({
    required this.currentIndex,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        bottomInset > 0 ? bottomInset + 4 : 14,
      ),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(33),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.55)
                  : const Color(0xFF6366F1).withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(33),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF131520).withValues(alpha: 0.86)
                    : Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(33),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.90),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavBarItem(
                    index: 0,
                    selectedIndex: currentIndex,
                    svgAsset: 'assets/navigation_modern/home_icon.svg',
                    fallbackIcon: Icons.home_rounded,
                    label: 'Home',
                    onTap: () => onTap(0),
                  ),
                  _NavBarItem(
                    index: 1,
                    selectedIndex: currentIndex,
                    svgAsset: 'assets/navigation_modern/planner_icon.svg',
                    fallbackIcon: Icons.calendar_today_rounded,
                    label: 'Planner',
                    onTap: () => onTap(1),
                  ),
                  _NavBarItem(
                    index: 2,
                    selectedIndex: currentIndex,
                    svgAsset: 'assets/navigation_modern/group_task_icon.svg',
                    fallbackIcon: Icons.groups_rounded,
                    label: 'Groups',
                    isGrayedOut: !isOnline,
                    onTap: () {
                      if (!isOnline) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              'Offline: Connect to internet to access Groups',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      onTap(2);
                    },
                  ),
                  _NavBarItem(
                    index: 3,
                    selectedIndex: currentIndex,
                    svgAsset: 'assets/navigation_modern/friends_icon.svg',
                    fallbackIcon: Icons.people_rounded,
                    label: 'Friends',
                    isGrayedOut: !isOnline,
                    onTap: () {
                      if (!isOnline) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              'Offline: Connect to internet to access Friends',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      onTap(3);
                    },
                  ),
                  _NavBarItem(
                    index: 4,
                    selectedIndex: currentIndex,
                    svgAsset: 'assets/navigation_modern/settings_icon.svg',
                    fallbackIcon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () => onTap(4),
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

class _NavBarItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final String svgAsset;
  final IconData fallbackIcon;
  final String label;
  final bool isGrayedOut;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.index,
    required this.selectedIndex,
    required this.svgAsset,
    required this.fallbackIcon,
    required this.label,
    this.isGrayedOut = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final unselectedIconColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF0F172A);

    final unselectedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : const Color(0xFF334155);

    final activeTextColor = isDark ? Colors.white : const Color(0xFF4F46E5);
    final iconSize = (index == 1 || index == 2) ? 23.5 : 22.0;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: isGrayedOut ? 0.38 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 16 : 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.40),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: SvgPicture.asset(
                  svgAsset,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(
                    isSelected ? Colors.white : unselectedIconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.1,
                  color: isSelected ? activeTextColor : unselectedTextColor,
                ),
                child: Text(label, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _safeIndex(int value) => value.clamp(0, 4).toInt();
