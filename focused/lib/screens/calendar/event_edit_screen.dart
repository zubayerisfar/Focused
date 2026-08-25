import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class EventEditScreen extends StatefulWidget {
  final bool isEditing;

  const EventEditScreen({super.key, this.isEditing = false});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  bool _allDay = false;
  bool _reminderEnabled = true;

  String _selectedColor = 'Blue';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Event' : 'New Event',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            widget.isEditing ? 'Update your event' : 'Plan something',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 18),

          TextField(
            controller: widget.isEditing
                ? TextEditingController(text: 'Study Flutter')
                : null,
            decoration: const InputDecoration(hintText: 'Event title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: widget.isEditing
                ? TextEditingController(text: 'Complete Provider section')
                : null,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Add description...'),
          ),

          const SizedBox(height: 26),

          const _SectionTitle('Schedule'),

          const SizedBox(height: 12),

          _SettingsCard(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'All-day',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                secondary: const Icon(Icons.today_outlined),
                value: _allDay,
                onChanged: (value) {
                  setState(() {
                    _allDay = value;
                  });
                },
              ),

              const Divider(height: 1),

              _SettingRow(
                icon: Icons.calendar_today_outlined,
                title: 'Date',
                value: 'Aug 25',
                onTap: _selectDate,
              ),

              if (!_allDay) ...[
                const Divider(height: 1),

                _SettingRow(
                  icon: Icons.schedule_outlined,
                  title: 'Starts',
                  value: '2:00 PM',
                  onTap: () {
                    _selectTime(const TimeOfDay(hour: 14, minute: 0));
                  },
                ),

                const Divider(height: 1),

                _SettingRow(
                  icon: Icons.schedule_rounded,
                  title: 'Ends',
                  value: '4:00 PM',
                  onTap: () {
                    _selectTime(const TimeOfDay(hour: 16, minute: 0));
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 22),

          const _SectionTitle('Google Calendar'),

          const SizedBox(height: 12),

          _SettingsCard(
            children: [
              const _GoogleAccountRow(),

              const Divider(height: 1),

              _SettingRow(
                icon: Icons.repeat_rounded,
                title: 'Repeat',
                value: 'Does not repeat',
                onTap: _showRepeatOptions,
              ),

              const Divider(height: 1),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.notifications_none_rounded),
                title: const Text(
                  'Reminder',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_reminderEnabled ? '10 minutes before' : 'Off'),
                value: _reminderEnabled,
                onChanged: (value) {
                  setState(() {
                    _reminderEnabled = value;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 22),

          const _SectionTitle('Color'),

          const SizedBox(height: 12),

          _ColorPicker(
            selected: _selectedColor,
            onSelected: (value) {
              setState(() {
                _selectedColor = value;
              });
            },
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 58,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                widget.isEditing ? 'Save Changes' : 'Create Event',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          if (widget.isEditing) ...[
            const SizedBox(height: 12),

            SizedBox(
              height: 54,
              child: TextButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text(
                  'Delete Event',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    await showDatePicker(
      context: context,
      initialDate: DateTime(2026, 8, 25),
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
  }

  Future<void> _selectTime(TimeOfDay initialTime) async {
    await showTimePicker(context: context, initialTime: initialTime);
  }

  void _showRepeatOptions() {
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
                  'Repeat',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const _BottomSheetOption(title: 'Does not repeat'),
                const _BottomSheetOption(title: 'Every day'),
                const _BottomSheetOption(title: 'Every week'),
                const _BottomSheetOption(title: 'Every month'),
                const _BottomSheetOption(title: 'Custom'),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 42,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  'Delete this event?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will eventually also delete the linked Google Calendar event.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Delete Event'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoogleAccountRow extends StatelessWidget {
  const _GoogleAccountRow();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Color(0x144D7CFE),
        child: Icon(Icons.calendar_month_rounded, color: AppTheme.primaryBlue),
      ),
      title: Text(
        'Google Calendar',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('Primary calendar'),
      trailing: Icon(Icons.chevron_right_rounded),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _ColorPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'Blue': AppTheme.primaryBlue,
      'Green': const Color(0xFF34B27B),
      'Purple': const Color(0xFF8E67D4),
      'Orange': const Color(0xFFFFB84D),
      'Pink': const Color(0xFFFF7A90),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: colors.entries.map((entry) {
          final isSelected = selected == entry.key;

          return InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () {
              onSelected(entry.key);
            },
            child: Container(
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? entry.value : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: entry.value,
                  shape: BoxShape.circle,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
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

class _BottomSheetOption extends StatelessWidget {
  final String title;

  const _BottomSheetOption({required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }
}
