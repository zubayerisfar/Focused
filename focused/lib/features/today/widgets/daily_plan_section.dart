import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../tasks/models/task.dart';
import '../../../core/widgets/glass_container.dart';
import 'next_today_task.dart';

Color _priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.critical:
      return const Color(0xFFEF4444);
    case TaskPriority.important:
      return const Color(0xFFF59E0B);
    case TaskPriority.growth:
      return const Color(0xFF10B981);
  }
}

String _priorityLabel(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.critical:
      return 'High';
    case TaskPriority.important:
      return 'Medium';
    case TaskPriority.growth:
      return 'Low';
  }
}

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class DailyPlanSection extends StatelessWidget {
  final NextTodayTask? next;
  final DateTime date;
  final int completedTasksCount;
  final int totalTasksCount;

  const DailyPlanSection({
    super.key,
    required this.next,
    required this.date,
    required this.completedTasksCount,
    required this.totalTasksCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allDone =
        totalTasksCount > 0 && completedTasksCount == totalTasksCount;
    final progressLabel = totalTasksCount == 0
        ? 'No tasks planned'
        : (allDone
              ? 'All $totalTasksCount done'
              : '$completedTasksCount of $totalTasksCount done');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/today_screen_icons/task_icon_today_screen.svg',
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white : const Color(0xFF1E293B),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Today\'s Plan',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: allDone
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : const Color(0xFFEDE9FE)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                progressLabel,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: allDone
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white70 : const Color(0xFF6366F1)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (allDone)
          const _AllCompletedCard()
        else if (next == null)
          _EmptyPlanCard(date: date)
        else
          _NextTaskCard(next: next!),
      ],
    );
  }
}

class _NextTaskCard extends StatelessWidget {
  final NextTodayTask next;

  const _NextTaskCard({required this.next});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final task = next.task;
    final isSquad = task.isSquadTask;
    const squadColor = Color(0xFF2563EB);
    final color = isSquad ? squadColor : _priorityColor(task.priority);
    final priorityText = isSquad ? 'Squad' : _priorityLabel(task.priority);

    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.push(
        '/task/${Uri.encodeComponent(task.id)}?date=${_dateQuery(next.date)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Priority Capsule Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  priorityText,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (task.scheduledStart != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(task.scheduledStart!),
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          if (task.description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Focus Now',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanCard extends StatelessWidget {
  final DateTime date;

  const _EmptyPlanCard({required this.date});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Text(
            'No tasks planned yet',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap below to add your first priority for today',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 12.5,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => context.push('/task/new'),
            child: const Text(
              'Add Task',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllCompletedCard extends StatelessWidget {
  const _AllCompletedCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'All tasks completed!',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You have crushed all your scheduled tasks for today.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 12.5,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
