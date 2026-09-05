import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/habit_provider.dart';

class HabitEditScreen extends StatefulWidget {
  final String? habitId;

  const HabitEditScreen({super.key, this.habitId});

  bool get isEditing => habitId != null;

  @override
  State<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends State<HabitEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'times');

  HabitGoalType _goalType = HabitGoalType.checkIn;
  Set<int> _weekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };
  int _iconCodePoint = Icons.check_rounded.codePoint;
  int _colorValue = const Color(0xFF4D7CFE).value;
  bool _reminderEnabled = false;
  int _reminderMinutesFromMidnight = 20 * 60;
  bool _enableLateReminder = false;
  int _lateReminderMinutes = 30;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final id = widget.habitId;
    if (id == null) return;

    final habit = context.read<HabitProvider>().getHabitById(id);
    if (habit == null) return;

    _titleController.text = habit.title;
    _targetController.text = '${habit.targetValue}';
    _unitController.text = habit.unit;
    _goalType = habit.goalType;
    _weekdays = Set<int>.from(habit.weekdays);
    _iconCodePoint = habit.iconCodePoint;
    _colorValue = habit.colorValue;
    _reminderEnabled = habit.reminderMinutesFromMidnight != null;
    _reminderMinutesFromMidnight =
        habit.reminderMinutesFromMidnight ?? _reminderMinutesFromMidnight;
    _enableLateReminder = habit.lateReminderMinutesAfter != null;
    _lateReminderMinutes = habit.lateReminderMinutesAfter ?? 30;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit habit' : 'New habit'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: 'Delete habit',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _saving ? null : _delete,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Habit name',
                hintText: 'Read, exercise, drink water…',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a habit name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Goal'),
            const SizedBox(height: 8),
            SegmentedButton<HabitGoalType>(
              segments: const [
                ButtonSegment(
                  value: HabitGoalType.checkIn,
                  label: Text('Check-in'),
                ),
                ButtonSegment(value: HabitGoalType.count, label: Text('Count')),
                ButtonSegment(
                  value: HabitGoalType.duration,
                  label: Text('Duration'),
                ),
              ],
              selected: {_goalType},
              onSelectionChanged: (selection) {
                setState(() {
                  _goalType = selection.first;
                  if (_goalType == HabitGoalType.checkIn) {
                    _targetController.text = '1';
                    _unitController.text = 'done';
                  } else if (_goalType == HabitGoalType.duration) {
                    if (_targetController.text == '1') {
                      _targetController.text = '30';
                    }
                    _unitController.text = 'minutes';
                  } else {
                    if (_targetController.text == '1') {
                      _targetController.text = '8';
                    }
                    _unitController.text = 'times';
                  }
                });
              },
            ),
            if (_goalType != HabitGoalType.checkIn) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Target'),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed < 1) {
                          return 'Use a number above 0.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a unit.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const _SectionLabel('Repeat'),
            const SizedBox(height: 8),
            _WeekdaySelector(
              selected: _weekdays,
              onToggle: (weekday) {
                setState(() {
                  if (_weekdays.contains(weekday)) {
                    if (_weekdays.length > 1) {
                      _weekdays.remove(weekday);
                    }
                  } else {
                    _weekdays.add(weekday);
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Reminder'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _reminderEnabled,
                    onChanged: (value) {
                      setState(() => _reminderEnabled = value);
                    },
                    title: const Text(
                      'Habit reminder',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _reminderEnabled
                          ? 'Only on the repeat days selected above.'
                          : 'Off',
                    ),
                  ),
                  if (_reminderEnabled) ...[
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: const Text('Reminder time'),
                      subtitle: const Text('Uses your device timezone'),
                      trailing: Text(
                        _reminderTime.format(context),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: _pickReminderTime,
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    SwitchListTile.adaptive(
                      value: _enableLateReminder,
                      onChanged: (value) {
                        setState(() => _enableLateReminder = value);
                      },
                      title: const Text(
                        'Follow-up if delayed',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _enableLateReminder
                            ? 'Remind $_lateReminderMinutes min later if not checked in'
                            : 'No late notification',
                      ),
                    ),
                    if (_enableLateReminder) ...[
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Follow-up delay'),
                        trailing: Text(
                          '$_lateReminderMinutes min after',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onTap: _pickLateDelay,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Style'),
            const SizedBox(height: 8),
            _StylePicker(
              iconCodePoint: _iconCodePoint,
              colorValue: _colorValue,
              onIconChanged: (value) => setState(() => _iconCodePoint = value),
              onColorChanged: (value) => setState(() => _colorValue = value),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _saving
                      ? 'Saving…'
                      : widget.isEditing
                      ? 'Save changes'
                      : 'Create habit',
                ),
              ),
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete habit'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TimeOfDay get _reminderTime => TimeOfDay(
    hour: _reminderMinutesFromMidnight ~/ 60,
    minute: _reminderMinutesFromMidnight % 60,
  );

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Habit reminder time',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _reminderMinutesFromMidnight = selected.hour * 60 + selected.minute;
    });
  }

  Future<void> _pickLateDelay() async {
    final options = [15, 20, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Follow-up delay',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ...options.map((mins) {
              return ListTile(
                title: Text('$mins minutes after'),
                trailing: _lateReminderMinutes == mins
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  setState(() => _lateReminderMinutes = mins);
                  Navigator.pop(sheetContext);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final provider = context.read<HabitProvider>();

    try {
      final target = _goalType == HabitGoalType.checkIn
          ? 1
          : int.parse(_targetController.text);
      final unit = _goalType == HabitGoalType.checkIn
          ? 'done'
          : _unitController.text.trim();
      final lateMins = (_reminderEnabled && _enableLateReminder)
          ? _lateReminderMinutes
          : null;

      if (widget.habitId == null) {
        await provider.createHabit(
          title: _titleController.text,
          goalType: _goalType,
          targetValue: target,
          unit: unit,
          weekdays: _weekdays,
          iconCodePoint: _iconCodePoint,
          colorValue: _colorValue,
          reminderMinutesFromMidnight: _reminderEnabled
              ? _reminderMinutesFromMidnight
              : null,
          lateReminderMinutesAfter: lateMins,
        );
      } else {
        final existing = provider.getHabitById(widget.habitId!);
        if (existing == null) {
          throw StateError('Habit no longer exists.');
        }
        await provider.updateHabit(
          existing.copyWith(
            title: _titleController.text.trim(),
            goalType: _goalType,
            targetValue: target,
            unit: unit,
            weekdays: Set<int>.from(_weekdays),
            iconCodePoint: _iconCodePoint,
            colorValue: _colorValue,
            reminderMinutesFromMidnight: _reminderEnabled
                ? _reminderMinutesFromMidnight
                : null,
            lateReminderMinutesAfter: lateMins,
          ),
        );
      }

      if (!mounted) return;
      final reminderResult = provider.lastReminderResult;
      if (_reminderEnabled &&
          reminderResult != null &&
          !reminderResult.isSuccess) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reminderResult.message)));
      }
      Navigator.pop(context);
    } catch (e, stack) {
      debugPrint('Error saving habit: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save habit: $e')));
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.habitId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete habit?'),
        content: const Text('This also removes its local progress history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<HabitProvider>().deleteHabit(id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete habit.')));
      setState(() => _saving = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  const _WeekdaySelector({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: List.generate(7, (index) {
        final day = index + 1;
        final active = selected.contains(day);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onToggle(day),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _StylePicker extends StatelessWidget {
  final int iconCodePoint;
  final int colorValue;
  final ValueChanged<int> onIconChanged;
  final ValueChanged<int> onColorChanged;

  const _StylePicker({
    required this.iconCodePoint,
    required this.colorValue,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  static const _icons = [
    Icons.check_rounded,
    Icons.menu_book_rounded,
    Icons.fitness_center_rounded,
    Icons.water_drop_rounded,
    Icons.self_improvement_rounded,
    Icons.bedtime_outlined,
  ];

  static const _colors = [
    Color(0xFF4D7CFE),
    Color(0xFF34B27B),
    Color(0xFF8E67D4),
    Color(0xFFFF8A65),
    Color(0xFFFFB84D),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _icons.map((icon) {
            final active = icon.codePoint == iconCodePoint;
            return ChoiceChip(
              selected: active,
              showCheckmark: false,
              label: Icon(icon, size: 20),
              onSelected: (_) => onIconChanged(icon.codePoint),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: _colors.map((color) {
            final active = color.value == colorValue;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onColorChanged(color.value),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 2,
                        )
                      : null,
                ),
                child: active
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
