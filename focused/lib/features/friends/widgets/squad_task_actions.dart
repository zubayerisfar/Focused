import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../tasks/models/task_group.dart';
import '../providers/task_mate_provider.dart';
import '../../../core/services/ad_service.dart';

class SquadTaskActions {
  static Future<void> pickScheduleTime(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
    GroupActiveTask? task,
  }) async {
    final taskMateProvider = context.read<TaskMateProvider>();
    final targetTask =
        task ??
        (group.activeTasks.length > taskIndex
            ? group.activeTasks[taskIndex]
            : group.activeTask);
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null || !context.mounted) return;

    final scheduled = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await taskMateProvider.setMySchedule(
      groupId: group.id,
      taskTitle: targetTask?.title ?? 'Task Squad Goal',
      scheduledTime: scheduled,
      taskIndex: taskIndex,
      isHabit: targetTask?.isHabit ?? false,
    );

    if (context.mounted) {
      final syncNote = (targetTask?.isHabit == true)
          ? ' & synced to Habits'
          : ' & added to Today Tasks';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1CB0F6),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '⏰ Scheduled for ${DateFormat('EEE, MMM d • h:mm a').format(scheduled)}$syncNote!',
          ),
        ),
      );
    }
  }

  static Future<void> startTask(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
  }) async {
    final targetTask = group.activeTasks.length > taskIndex
        ? group.activeTasks[taskIndex]
        : group.activeTask;
    final taskTitle = targetTask?.title ?? 'Squad Goal';

    // Show a quick dialog or bottom sheet offering to jump into Focus Mode or complete
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final scheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2B3D47)
                      : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Squad Quest: $taskTitle',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Start a dedicated focus session to conquer this task with your squad!',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF58CC02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Start Focus Session',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: () => Navigator.pop(bCtx, 'focus'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'I Finished It • Claim Gems',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => Navigator.pop(bCtx, 'complete'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;

    if (action == 'focus') {
      context.push('/focus/setup');
    } else if (action == 'complete') {
      await completeTask(context, group, taskIndex: taskIndex);
    }
  }

  static Future<void> completeTask(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
  }) async {
    final taskMateProvider = context.read<TaskMateProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // Show Double Gems Offer Dialog
    final shouldWatchVideo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: const [
            Text('🎉', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Squad Task Completed!',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icon/gem.svg',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DOUBLE GEMS: 100 GEMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'You earned +50 Gems! Watch a quick video to double your reward to 100 Gems and climb the leaderboard faster.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark
                    ? const Color(0xFFAFBBC1)
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              // Smaller, slightly grayed button
              Expanded(
                flex: 4,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(
                    'Claim 50 Gems',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Prominent bold button to double
              Expanded(
                flex: 6,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                  label: const Text(
                    'Double to 100',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (shouldWatchVideo == true) {
      // User chose to watch video for double gems (100 Gems)
      AdService.instance.showRewardedAd(
        onUserEarnedReward: (reward) async {
          // Complete task with full 100 Gems
          await taskMateProvider.completeTask(
            groupId: group.id,
            taskIndex: taskIndex,
            xpAward: 100,
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0284C7),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icon/gem.svg',
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Awesome! 100 Gems added & synced to your account!',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
        onAdDismissed: () async {
          // If ad was dismissed or not ready, ensure task is completed with 50 Gems
          final task = group.activeTasks.length > taskIndex
              ? group.activeTasks[taskIndex]
              : null;
          final sched = task?.memberSchedules[taskMateProvider.currentUid];
          if (sched?.completed != true) {
            await taskMateProvider.completeTask(
              groupId: group.id,
              taskIndex: taskIndex,
              xpAward: 50,
            );
          }
        },
      );
    } else {
      // Standard completion (+50 Gems)
      await taskMateProvider.completeTask(
        groupId: group.id,
        taskIndex: taskIndex,
        xpAward: 50,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Task Complete!',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '+200 EXP added to your account & synced!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }
}
