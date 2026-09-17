import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/glass_container.dart';
import '../../focus/providers/focus_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../tasks/providers/task_provider.dart';

/// A GitHub-style monthly productivity contribution graph (heatmap)
/// displaying daily task completions, focus sessions, and habit completions.
class MonthlyContributionGraph extends StatefulWidget {
  const MonthlyContributionGraph({super.key});

  @override
  State<MonthlyContributionGraph> createState() =>
      _MonthlyContributionGraphState();
}

class _MonthlyContributionGraphState extends State<MonthlyContributionGraph> {
  late DateTime _selectedMonth;
  DateTime? _selectedDate;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdayLabels = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() {
        _selectedMonth = next;
        _selectedDate = null;
      });
    }
  }

  bool get _canGoNext {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    return _selectedMonth.isBefore(currentMonthStart);
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = _dateOnly(now);

    final taskProvider = context.watch<TaskProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final habitProvider = context.watch<HabitProvider>();

    // ── Aggregate counts per date ──
    final taskCounts = taskProvider.completionActivityCountsByDate();
    final habitCounts = habitProvider.habitCompletionCountsByDate();

    // Focus session counts
    final focusCounts = <DateTime, int>{};
    for (final session in focusProvider.sessionHistory) {
      final d = _dateOnly(session.startedAt);
      focusCounts[d] = (focusCounts[d] ?? 0) + 1;
    }

    // Days in current selected month
    final firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    // Monday is 1 in Dart, Sunday is 7.
    final leadingSpaces = firstDayOfMonth.weekday - 1;

    // Calculate monthly totals
    int totalMonthContributions = 0;
    int activeDaysCount = 0;
    int bestDayContributions = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final tasks = taskCounts[date] ?? 0;
      final focus = focusCounts[date] ?? 0;
      final habits = habitCounts[date] ?? 0;
      final total = tasks + focus + habits;

      totalMonthContributions += total;
      if (total > 0) {
        activeDaysCount++;
        if (total > bestDayContributions) {
          bestDayContributions = total;
        }
      }
    }

    final monthName = _monthNames[_selectedMonth.month - 1];
    final yearString = '${_selectedMonth.year}';

    return GlassContainer(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title, Month Selector & Navigation ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2EA043,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            size: 15,
                            color: Color(0xFF2EA043),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '$monthName $yearString',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : scheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalMonthContributions contributions · $activeDaysCount active ${activeDaysCount == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF8B949E)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Previous month button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous month',
                onPressed: _previousMonth,
              ),
              // Next month button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next month',
                onPressed: _canGoNext ? _nextMonth : null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Weekday Headers (M, T, W, T, F, S, S) ──
          Row(
            children: List.generate(7, (index) {
              return Expanded(
                child: Center(
                  child: Text(
                    _weekdayLabels[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF6E7681)
                          : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),

          // ── Calendar Heatmap Grid ──
          _buildMonthGrid(
            daysInMonth: daysInMonth,
            leadingSpaces: leadingSpaces,
            today: today,
            isDark: isDark,
            scheme: scheme,
            taskCounts: taskCounts,
            focusCounts: focusCounts,
            habitCounts: habitCounts,
          ),
          const SizedBox(height: 10),

          // ── Legend Row (clean, no unnecessary labels) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF6E7681)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 5),
              ...List.generate(5, (level) {
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: _levelColor(level, isDark: isDark),
                    borderRadius: BorderRadius.circular(2.5),
                    border: Border.all(
                      color: _levelBorderColor(level, isDark: isDark),
                      width: 0.7,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 5),
              Text(
                'More',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF6E7681)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),

          // ── Day Breakdown Card (when a day is selected) ──
          if (_selectedDate != null) ...[
            const SizedBox(height: 14),
            _buildDayBreakdownCard(
              date: _selectedDate!,
              today: today,
              isDark: isDark,
              scheme: scheme,
              taskCount: taskCounts[_selectedDate!] ?? 0,
              focusCount: focusCounts[_selectedDate!] ?? 0,
              habitCount: habitCounts[_selectedDate!] ?? 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthGrid({
    required int daysInMonth,
    required int leadingSpaces,
    required DateTime today,
    required bool isDark,
    required ColorScheme scheme,
    required Map<DateTime, int> taskCounts,
    required Map<DateTime, int> focusCounts,
    required Map<DateTime, int> habitCounts,
  }) {
    final totalCells = leadingSpaces + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(totalRows, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.5),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final dayNumber = cellIndex - leadingSpaces + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(
                  child: AspectRatio(aspectRatio: 1, child: SizedBox.shrink()),
                );
              }

              final cellDate = DateTime(
                _selectedMonth.year,
                _selectedMonth.month,
                dayNumber,
              );
              final isFuture = cellDate.isAfter(today);
              final isToday = cellDate.isAtSameMomentAs(today);
              final isSelected =
                  _selectedDate != null &&
                  cellDate.isAtSameMomentAs(_selectedDate!);

              final tasks = taskCounts[cellDate] ?? 0;
              final focus = focusCounts[cellDate] ?? 0;
              final habits = habitCounts[cellDate] ?? 0;
              final total = tasks + focus + habits;
              final level = isFuture ? 0 : _calculateLevel(total);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GestureDetector(
                      onTap: isFuture
                          ? null
                          : () {
                              setState(() {
                                _selectedDate = cellDate;
                              });
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isFuture
                              ? (isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.03))
                              : _levelColor(level, isDark: isDark),
                          borderRadius: BorderRadius.circular(4.5),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1CB0F6)
                                : isToday
                                ? const Color(0xFF2EA043)
                                : isFuture
                                ? Colors.transparent
                                : _levelBorderColor(level, isDark: isDark),
                            width: isSelected ? 2 : (isToday ? 1.5 : 0.7),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1CB0F6,
                                    ).withValues(alpha: 0.35),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected || isToday || total > 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isFuture
                                  ? (isDark
                                        ? const Color(0xFF484F58)
                                        : const Color(0xFFD0D7DE))
                                  : _levelTextColor(level, isDark: isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildDayBreakdownCard({
    required DateTime date,
    required DateTime today,
    required bool isDark,
    required ColorScheme scheme,
    required int taskCount,
    required int focusCount,
    required int habitCount,
  }) {
    final total = taskCount + focusCount + habitCount;
    final isToday = date.isAtSameMomentAs(today);
    final weekdayName = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];
    final dateFormatted =
        '$weekdayName, ${_monthNames[date.month - 1]} ${date.day}${isToday ? ' (Today)' : ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateFormatted,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : scheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: total > 0
                      ? const Color(0xFF2EA043).withValues(alpha: 0.15)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  total == 1 ? '1 contribution' : '$total contributions',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: total > 0
                        ? const Color(0xFF2EA043)
                        : (isDark
                              ? const Color(0xFF8B949E)
                              : scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (taskCount > 0)
                  _DetailPill(
                    icon: Icons.check_circle_outline_rounded,
                    label: '$taskCount ${taskCount == 1 ? 'task' : 'tasks'}',
                    color: const Color(0xFF58CC02),
                  ),
                if (focusCount > 0)
                  _DetailPill(
                    icon: Icons.timer_outlined,
                    label:
                        '$focusCount ${focusCount == 1 ? 'focus session' : 'focus sessions'}',
                    color: const Color(0xFF1CB0F6),
                  ),
                if (habitCount > 0)
                  _DetailPill(
                    icon: Icons.auto_awesome_rounded,
                    label:
                        '$habitCount ${habitCount == 1 ? 'habit' : 'habits'}',
                    color: const Color(0xFFFF9600),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'No recorded productivity activity on this day.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF8B949E)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _calculateLevel(int total) {
    if (total <= 0) return 0;
    if (total <= 2) return 1;
    if (total <= 4) return 2;
    if (total <= 6) return 3;
    return 4;
  }

  Color _levelColor(int level, {required bool isDark}) {
    if (isDark) {
      switch (level) {
        case 1:
          return const Color(0xFF0E4429);
        case 2:
          return const Color(0xFF006D32);
        case 3:
          return const Color(0xFF26A641);
        case 4:
          return const Color(0xFF39D353);
        case 0:
        default:
          return const Color(0xFF161B22);
      }
    } else {
      switch (level) {
        case 1:
          return const Color(0xFF9BE9A8);
        case 2:
          return const Color(0xFF40C463);
        case 3:
          return const Color(0xFF30A14E);
        case 4:
          return const Color(0xFF216E39);
        case 0:
        default:
          return const Color(0xFFEBEDF0);
      }
    }
  }

  Color _levelBorderColor(int level, {required bool isDark}) {
    if (isDark) {
      switch (level) {
        case 1:
          return const Color(0xFF0E4429).withValues(alpha: 0.8);
        case 2:
          return const Color(0xFF006D32);
        case 3:
          return const Color(0xFF26A641);
        case 4:
          return const Color(0xFF39D353);
        case 0:
        default:
          return const Color(0xFF30363D).withValues(alpha: 0.6);
      }
    } else {
      switch (level) {
        case 1:
          return const Color(0xFF80E090);
        case 2:
          return const Color(0xFF35B556);
        case 3:
          return const Color(0xFF2B9346);
        case 4:
          return const Color(0xFF1A5A2E);
        case 0:
        default:
          return const Color(0xFFD0D7DE).withValues(alpha: 0.7);
      }
    }
  }

  Color _levelTextColor(int level, {required bool isDark}) {
    if (isDark) {
      if (level == 0) return const Color(0xFF8B949E);
      if (level >= 3) return Colors.black87;
      return Colors.white;
    } else {
      if (level == 0) return const Color(0xFF57606A);
      if (level >= 3) return Colors.white;
      return const Color(0xFF1F2328);
    }
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
