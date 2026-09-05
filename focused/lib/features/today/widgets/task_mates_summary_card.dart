import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/task_mate_provider.dart';

class TaskMatesSummaryCard extends StatelessWidget {
  const TaskMatesSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final taskMateProvider = context.watch<TaskMateProvider>();
    final groups = taskMateProvider.groups;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeGroups = groups.where((g) => g.activeTasks.isNotEmpty).toList();
    if (activeGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstGroup = activeGroups.first;
    final activeTaskCount = activeGroups.fold<int>(
      0,
      (sum, g) => sum + g.activeTasks.length,
    );

    // Eye-smoothing calm oceanic blue/indigo palette
    const squadColor = Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132238) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? squadColor.withValues(alpha: 0.35)
              : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/friends?tab=squads'),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A) : squadColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SvgPicture.asset(
                'assets/icon/group_task.svg',
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Task Mates Squad',
                        style: TextStyle(
                          color: isDark ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? squadColor.withValues(alpha: 0.35)
                              : squadColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$activeTaskCount active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : squadColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${firstGroup.name}: "${firstGroup.activeTasks.first.title}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: isDark ? const Color(0xFF93C5FD) : squadColor,
            ),
          ],
        ),
      ),
    );
  }
}

