import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../tasks/models/task.dart';
import '../../tasks/providers/task_provider.dart';
import '../../../core/widgets/glass_container.dart';

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

/// Two-part side-by-side section: Priority Tasks checklist on the left,
/// and Focus & Progress stats on the right (inspired by TaskityAI reference).
class TwoPartFocusTaskSection extends StatelessWidget {
  final List<Task> tasks;
  final DateTime date;
  final Duration focusedToday;
  final int focusSessionsCount;
  final int completedTasksCount;
  final int totalTasksCount;
  final VoidCallback onAddTask;

  const TwoPartFocusTaskSection({
    super.key,
    required this.tasks,
    required this.date,
    required this.focusedToday,
    this.focusSessionsCount = 0,
    required this.completedTasksCount,
    required this.totalTasksCount,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskProvider = context.watch<TaskProvider>();

    final double completionPercent = totalTasksCount > 0
        ? (completedTasksCount / totalTasksCount).clamp(0.0, 1.0)
        : (completedTasksCount > 0 ? 1.0 : 0.0);

    // Filter priority tasks (critical tasks only - all tasks displayed, scrollable)
    final criticalTasks = tasks
        .where((t) => t.priority == TaskPriority.critical)
        .toList();

    final cardGreen = isDark
        ? const Color(0xFFD2F86A)
        : const Color(0xFFD8F878);

    // Colorful glossy tints for right-hand cards
    final completedBg = isDark
        ? const Color(0xFF2D1525).withValues(alpha: 0.72)
        : const Color(0xFFFDF2F8).withValues(alpha: 0.88);

    final completedBorder = Border.all(
      color: isDark
          ? const Color(0xFFF472B6).withValues(alpha: 0.25)
          : const Color(0xFFF472B6).withValues(alpha: 0.40),
      width: 1.2,
    );

    final completedShadow = BoxShadow(
      color: const Color(0xFFEC4899).withValues(alpha: isDark ? 0.25 : 0.12),
      blurRadius: 18,
      offset: const Offset(0, 6),
    );

    final focusBg = isDark
        ? const Color(0xFF0F2338).withValues(alpha: 0.72)
        : const Color(0xFFF0F9FF).withValues(alpha: 0.88);

    final focusBorder = Border.all(
      color: isDark
          ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
          : const Color(0xFF38BDF8).withValues(alpha: 0.40),
      width: 1.2,
    );

    final focusShadow = BoxShadow(
      color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.12),
      blurRadius: 18,
      offset: const Offset(0, 6),
    );

    return SizedBox(
      height: 236,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── LEFT PART: Priority Tasks Checklist (Greenish, Scrollable with bottom blur) ──
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardGreen,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFD2F86A,
                    ).withValues(alpha: isDark ? 0.25 : 0.40),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Priority Task',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF111827),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (criticalTasks.isNotEmpty)
                        GestureDetector(
                          onTap: onAddTask,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (criticalTasks.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'No critical tasks yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF111827),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: onAddTask,
                              child: const Text(
                                'Add',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Stack(
                        children: [
                          ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(
                              bottom: criticalTasks.length >= 4 ? 28 : 6,
                            ),
                            itemCount: criticalTasks.length,
                            itemBuilder: (context, index) {
                              final task = criticalTasks[index];
                              final isCompleted = taskProvider
                                  .isTaskCompletedForDate(task, date);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () async {
                                    await taskProvider.setCompletedForDate(
                                      task.id,
                                      date,
                                      !isCompleted,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCompleted
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                          size: 19,
                                          color: isCompleted
                                              ? const Color(0xFF111827)
                                              : const Color(
                                                  0xFF111827,
                                                ).withValues(alpha: 0.7),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Quicksand',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: const Color(0xFF111827),
                                              decoration: isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (criticalTasks.length >= 4)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 36,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        cardGreen.withValues(alpha: 0.0),
                                        cardGreen.withValues(alpha: 0.96),
                                      ],
                                    ),
                                  ),
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

          const SizedBox(width: 12),

          // ── RIGHT PART: Focus & Progress (Colorful Glossy Stacked Cards) ──
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Card: Completed Ratio & Progress (Rose / Pink Glossy Tint)
                GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  borderRadius: BorderRadius.circular(22),
                  color: completedBg,
                  border: completedBorder,
                  shadow: completedShadow,
                  child: Row(
                    children: [
                      // Progress ring
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: completionPercent,
                              strokeWidth: 4.5,
                              strokeCap: StrokeCap.round,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08),
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFEC4899),
                              ),
                            ),
                            Text(
                              '${(completionPercent * 100).round()}%',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$completedTasksCount/$totalTasksCount task',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Bottom Card: Focus Time (Sky Blue / Cyan Glossy Tint)
                Expanded(
                  child: GlassContainer(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    color: focusBg,
                    border: focusBorder,
                    shadow: focusShadow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/navbar_icon/nav_focus.svg',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Focus Time',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(focusedToday),
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              focusSessionsCount == 1
                                  ? '1 focus made'
                                  : '$focusSessionsCount focus made',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 30,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1CB0F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => context.push('/focus/setup'),
                            child: const Text(
                              'Focus Now',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
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
    );
  }
}
