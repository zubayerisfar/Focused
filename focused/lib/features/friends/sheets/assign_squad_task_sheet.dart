import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../tasks/models/task_group.dart';
import '../providers/task_mate_provider.dart';

void showAssignTaskSheet(BuildContext context, TaskGroup group) {
  final taskMateProvider = context.read<TaskMateProvider>();
  final customTaskController = TextEditingController();
  bool isDaily = false;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedStartTime = TimeOfDay.now();
  TimeOfDay selectedEndTime = TimeOfDay(
    hour:
        (TimeOfDay.now().hour + (TimeOfDay.now().minute + 30 >= 60 ? 1 : 0)) %
        24,
    minute: (TimeOfDay.now().minute + 30) % 60,
  );
  int? selectedReminderMinutes;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final scheme = Theme.of(ctx).colorScheme;
        final liveGroup = taskMateProvider.groups.firstWhere(
          (g) => g.id == group.id,
          orElse: () => group,
        );

        String reminderText(int? mins) {
          if (mins == null) return 'No reminder';
          if (mins == 0) return 'At start';
          return '$mins min before';
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2B3D47)
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Squad Task',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                // Task Type Selector: Single Task vs Daily Habit
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setSheetState(() => isDaily = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: !isDaily
                                ? const Color(
                                    0xFF9B51E0,
                                  ).withValues(alpha: isDark ? 0.22 : 0.12)
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !isDaily
                                  ? const Color(0xFF9B51E0)
                                  : scheme.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                              width: !isDaily ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Single Task',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: !isDaily
                                      ? (isDark
                                            ? Colors.white
                                            : const Color(0xFF6B21A8))
                                      : (isDark
                                            ? Colors.white70
                                            : scheme.onSurface),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'One-time quest',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setSheetState(() => isDaily = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDaily
                                ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: isDark ? 0.22 : 0.12)
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDaily
                                  ? const Color(0xFF10B981)
                                  : scheme.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                              width: isDaily ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Daily Habit',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDaily
                                      ? (isDark
                                            ? Colors.white
                                            : const Color(0xFF047857))
                                      : (isDark
                                            ? Colors.white70
                                            : scheme.onSurface),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Repeats everyday',
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: customTaskController,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: isDaily
                        ? 'Enter daily squad habit…'
                        : 'Enter squad task title…',
                    hintStyle: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 15,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? scheme.surfaceContainerHigh.withValues(alpha: 0.6)
                        : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF9B51E0),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Date Picker Row (for one-time task)
                if (!isDaily) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFF9B51E0),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat(
                                    'EEE, MMM d, yyyy',
                                  ).format(selectedDate),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_calendar_outlined, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Start & End Time Pickers
                Row(
                  children: [
                    // Start Time
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedStartTime,
                          );
                          if (picked != null) {
                            setSheetState(() {
                              selectedStartTime = picked;
                              selectedEndTime = TimeOfDay(
                                hour:
                                    (picked.hour +
                                        (picked.minute + 30 >= 60 ? 1 : 0)) %
                                    24,
                                minute: (picked.minute + 30) % 60,
                              );
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: Color(0xFF9B51E0),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Start Time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      selectedStartTime.format(ctx),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // End Time
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedEndTime,
                          );
                          if (picked != null) {
                            setSheetState(() => selectedEndTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timelapse_rounded,
                                color: Color(0xFF10B981),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'End Time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      selectedEndTime.format(ctx),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Reminder Picker
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final chosen = await showModalBottomSheet<int?>(
                      context: ctx,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (rCtx) => SafeArea(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(rCtx).height * 0.7,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    18,
                                    20,
                                    10,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.notifications_active_rounded,
                                        color: Color(0xFF9B51E0),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Choose Reminder Time',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : scheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                for (final mins in <int?>[
                                  null,
                                  0,
                                  5,
                                  10,
                                  15,
                                  30,
                                  60,
                                ])
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                      reminderText(mins),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            selectedReminderMinutes == mins
                                            ? FontWeight.w900
                                            : FontWeight.w700,
                                        color: selectedReminderMinutes == mins
                                            ? const Color(0xFF9B51E0)
                                            : (isDark
                                                  ? Colors.white
                                                  : scheme.onSurface),
                                      ),
                                    ),
                                    trailing: selectedReminderMinutes == mins
                                        ? Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF9B51E0),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          )
                                        : null,
                                    onTap: () => Navigator.pop(rCtx, mins),
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    setSheetState(() => selectedReminderMinutes = chosen);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF9B51E0),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reminder',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reminderText(selectedReminderMinutes),
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9B51E0),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final title = customTaskController.text.trim();
                      if (title.isEmpty) return;
                      Navigator.pop(ctx);

                      final ok = await taskMateProvider.assignTask(
                        groupId: group.id,
                        title: title,
                        category: isDaily ? 'Habit' : 'Task',
                        isHabit: isDaily,
                      );

                      if (ok) {
                        final baseDate = isDaily
                            ? DateTime.now()
                            : selectedDate;
                        final scheduledDateTime = DateTime(
                          baseDate.year,
                          baseDate.month,
                          baseDate.day,
                          selectedStartTime.hour,
                          selectedStartTime.minute,
                        );
                        final scheduledEndDateTime = DateTime(
                          baseDate.year,
                          baseDate.month,
                          baseDate.day,
                          selectedEndTime.hour,
                          selectedEndTime.minute,
                        );

                        await taskMateProvider.setMySchedule(
                          groupId: group.id,
                          scheduledTime: scheduledDateTime,
                          scheduledEnd: scheduledEndDateTime,
                          reminderMinutesBefore: selectedReminderMinutes,
                          taskTitle: title,
                          isHabit: isDaily,
                          taskIndex: liveGroup.activeTasks.length,
                        );
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: ok
                                ? const Color(0xFF9B51E0)
                                : Colors.redAccent,
                            content: Text(
                              ok
                                  ? '⚡ Squad Quest "$title" created!'
                                  : 'This squad already has an active task.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Add Task',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
