import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../friends/providers/task_mate_provider.dart';
import '../../tasks/models/group_task_history.dart';

class GroupHistoryTab extends StatefulWidget {
  final bool isDark;

  const GroupHistoryTab({super.key, required this.isDark});

  @override
  State<GroupHistoryTab> createState() => _GroupHistoryTabState();
}

class _GroupHistoryTabState extends State<GroupHistoryTab> {
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<GroupTaskHistory> items) {
    setState(() {
      if (_selectedIds.length == items.length) {
        _selectedIds.clear();
        _isSelecting = false;
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(items.map((i) => i.id));
      }
    });
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskMateProvider provider,
    List<GroupTaskHistory> allItems,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final itemsToDelete = allItems
        .where((i) => _selectedIds.contains(i.id))
        .toList();
    if (itemsToDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Delete ${itemsToDelete.length} task ${itemsToDelete.length == 1 ? 'history' : 'histories'}?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'This will permanently remove the selected completed tasks from your squad history.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final count = itemsToDelete.length;
      await provider.deleteHistoryItems(itemsToDelete);
      setState(() {
        _selectedIds.clear();
        _isSelecting = false;
      });
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            'Deleted $count task ${count == 1 ? 'record' : 'records'} from history.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskMateProvider = context.watch<TaskMateProvider>();
    final scheme = Theme.of(context).colorScheme;
    final history = taskMateProvider.history;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF58CC02).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.history_rounded,
                    size: 38,
                    color: Color(0xFF58CC02),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Group History Yet',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? Colors.white : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When all members of a task squad finish their daily tasks, they will be archived here automatically with full details.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  color: widget.isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Selection toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Text(
                _isSelecting
                    ? '${_selectedIds.length} SELECTED'
                    : 'COMPLETED SQUAD TASKS (${history.length})',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_isSelecting) ...[
                TextButton(
                  onPressed: () => _selectAll(history),
                  child: Text(
                    _selectedIds.length == history.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Selected',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444),
                  ),
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () =>
                            _confirmDelete(context, taskMateProvider, history),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    setState(() {
                      _isSelecting = false;
                      _selectedIds.clear();
                    });
                  },
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isSelecting = true;
                    });
                  },
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text(
                    'Select',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),

        // History List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            itemCount: history.length,
            itemBuilder: (ctx, index) {
              final item = history[index];
              final isSelected = _selectedIds.contains(item.id);
              final groupColor = taskMateProvider.colorForGroupId(item.groupId);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1CB0F6)
                        : Theme.of(context).dividerColor.withValues(
                            alpha: widget.isDark ? 0.35 : 0.6,
                          ),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: widget.isDark ? 0.25 : 0.04,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (_isSelecting) {
                        _toggleSelect(item.id);
                      } else {
                        _showHistoryDetailsSheet(context, item, groupColor);
                      }
                    },
                    onLongPress: () {
                      if (!_isSelecting) {
                        setState(() {
                          _isSelecting = true;
                          _selectedIds.add(item.id);
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (_isSelecting) ...[
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF1CB0F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              onChanged: (_) => _toggleSelect(item.id),
                            ),
                            const SizedBox(width: 8),
                          ] else ...[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: groupColor.withValues(
                                  alpha: widget.isDark ? 0.28 : 0.14,
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF58CC02),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: groupColor.withValues(
                                          alpha: widget.isDark ? 0.25 : 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.groupName,
                                        style: TextStyle(
                                          fontFamily: 'Quicksand',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: groupColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat(
                                        'MMM d, yyyy • h:mm a',
                                      ).format(item.completedAt),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.group_rounded,
                                      size: 14,
                                      color: Color(0xFF58CC02),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${item.memberCompletions.length} members completed',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showHistoryDetailsSheet(
    BuildContext context,
    GroupTaskHistory item,
    Color groupColor,
  ) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: groupColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.groupName,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: groupColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed on ${DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(item.completedAt)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              'MEMBER COMPLETIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            ...item.memberCompletions.values.map((member) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF58CC02),
                      backgroundImage:
                          member.photoUrl != null && member.photoUrl!.isNotEmpty
                          ? NetworkImage(member.photoUrl!)
                          : null,
                      child: member.photoUrl == null || member.photoUrl!.isEmpty
                          ? Text(
                              member.displayName.isNotEmpty
                                  ? member.displayName[0].toUpperCase()
                                  : 'M',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: member.isLate
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : const Color(0xFF58CC02).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        member.isLate ? 'Done (Late)' : 'Done on time',
                        style: TextStyle(
                          color: member.isLate
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF58CC02),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
