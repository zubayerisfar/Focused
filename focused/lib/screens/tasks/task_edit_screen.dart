import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  String _priority = 'Important';

  bool _hasDeadline = true;
  bool _scheduleOnCalendar = false;

  int _estimatedMinutes = 60;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Task',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          Text(
            'What needs to be done?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 18),

          const TextField(
            decoration: InputDecoration(hintText: 'Task title'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 12),

          const TextField(
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Add a description...',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 28),

          const _SectionTitle('Priority'),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _PriorityButton(
                  label: 'Critical',
                  color: const Color(0xFFFF6B5E),
                  selected: _priority == 'Critical',
                  onTap: () {
                    setState(() {
                      _priority = 'Critical';
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriorityButton(
                  label: 'Important',
                  color: AppTheme.primaryBlue,
                  selected: _priority == 'Important',
                  onTap: () {
                    setState(() {
                      _priority = 'Important';
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriorityButton(
                  label: 'Growth',
                  color: const Color(0xFF34B27B),
                  selected: _priority == 'Growth',
                  onTap: () {
                    setState(() {
                      _priority = 'Growth';
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          const _SectionTitle('Planning'),

          const SizedBox(height: 12),

          _SettingsCard(
            children: [
              _SettingRow(
                icon: Icons.timer_outlined,
                title: 'Estimated duration',
                value: _durationLabel(_estimatedMinutes),
                onTap: _showDurationPicker,
              ),
              const Divider(height: 1),
              _SettingRow(
                icon: Icons.flag_outlined,
                title: 'Deadline',
                value: _hasDeadline ? 'Today' : 'None',
                onTap: _showDeadlineSheet,
              ),
            ],
          ),

          const SizedBox(height: 22),

          const _SectionTitle('Calendar'),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              value: _scheduleOnCalendar,
              onChanged: (value) {
                setState(() {
                  _scheduleOnCalendar = value;
                });
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              secondary: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: const Text(
                'Schedule task',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('Add this task to Google Calendar'),
              ),
            ),
          ),

          if (_scheduleOnCalendar) ...[
            const SizedBox(height: 12),

            _SettingsCard(
              children: [
                _SettingRow(
                  icon: Icons.calendar_today_outlined,
                  title: 'Date',
                  value: 'Today',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.schedule_outlined,
                  title: 'Start',
                  value: '2:00 PM',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.timelapse_outlined,
                  title: 'End',
                  value: '3:00 PM',
                  onTap: () {},
                ),
              ],
            ),
          ],

          const SizedBox(height: 30),

          SizedBox(
            height: 58,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Create Task',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    return '${hours}h ${remaining}m';
  }

  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Estimated duration',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _DurationChoice(label: '30 min', onTap: () => _setDuration(30)),
                _DurationChoice(label: '45 min', onTap: () => _setDuration(45)),
                _DurationChoice(label: '1 hour', onTap: () => _setDuration(60)),
                _DurationChoice(
                  label: '1 hour 30 min',
                  onTap: () => _setDuration(90),
                ),
                _DurationChoice(
                  label: '2 hours',
                  onTap: () => _setDuration(120),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setDuration(int value) {
    setState(() {
      _estimatedMinutes = value;
    });

    Navigator.pop(context);
  }

  void _showDeadlineSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deadline',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.today_outlined),
                  title: const Text('Today'),
                  onTap: () {
                    setState(() {
                      _hasDeadline = true;
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Tomorrow'),
                  onTap: () {
                    setState(() {
                      _hasDeadline = true;
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Choose date'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('No deadline'),
                  onTap: () {
                    setState(() {
                      _hasDeadline = false;
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.14)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : null,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

class _DurationChoice extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DurationChoice({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
