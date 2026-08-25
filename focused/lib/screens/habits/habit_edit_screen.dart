import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HabitEditScreen extends StatefulWidget {
  final bool isEditing;

  const HabitEditScreen({
    super.key,
    this.isEditing = false,
  });

  @override
  State<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends State<HabitEditScreen> {
  IconData _selectedIcon = Icons.menu_book_rounded;

  Color _selectedColor = const Color(0xFF8E67D4);

  String _targetType = 'Count';

  int _targetValue = 20;

  String _unit = 'Pages';

  final Set<int> _selectedDays = {
    1,
    2,
    3,
    4,
    5,
  };

  bool _reminderEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Habit' : 'New Habit',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            widget.isEditing
                ? 'Update your routine'
                : 'Build a small routine',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: widget.isEditing
                ? TextEditingController(text: 'Read')
                : null,
            decoration: const InputDecoration(
              hintText: 'Habit name',
            ),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 26),

          const _SectionTitle('Icon'),

          const SizedBox(height: 12),

          _IconSelector(
            selectedIcon: _selectedIcon,
            color: _selectedColor,
            onSelected: (icon) {
              setState(() {
                _selectedIcon = icon;
              });
            },
          ),

          const SizedBox(height: 26),

          const _SectionTitle('Color'),

          const SizedBox(height: 12),

          _ColorSelector(
            selectedColor: _selectedColor,
            onSelected: (color) {
              setState(() {
                _selectedColor = color;
              });
            },
          ),

          const SizedBox(height: 26),

          const _SectionTitle('Goal'),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.track_changes_rounded,
                  title: 'Goal type',
                  value: _targetType,
                  onTap: _showTargetTypePicker,
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.numbers_rounded,
                  title: 'Target',
                  value: '$_targetValue',
                  onTap: _showTargetValuePicker,
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.straighten_rounded,
                  title: 'Unit',
                  value: _unit,
                  onTap: _showUnitPicker,
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          const _SectionTitle('Repeat'),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Repeat on',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _DaysSelector(
                  selectedDays: _selectedDays,
                  onTap: (day) {
                    setState(() {
                      if (_selectedDays.contains(day)) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          const _SectionTitle('Reminder'),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              secondary: const Icon(
                Icons.notifications_none_rounded,
              ),
              title: const Text(
                'Daily reminder',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                _reminderEnabled ? '8:00 PM' : 'Off',
              ),
              value: _reminderEnabled,
              onChanged: (value) {
                setState(() {
                  _reminderEnabled = value;
                });
              },
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 58,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                widget.isEditing
                    ? 'Save Changes'
                    : 'Create Habit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTargetTypePicker() {
    _showOptions(
      'Goal type',
      [
        'Check-in',
        'Count',
        'Duration',
      ],
      (value) {
        setState(() {
          _targetType = value;

          if (value == 'Check-in') {
            _targetValue = 1;
            _unit = 'Done';
          } else if (value == 'Duration') {
            _targetValue = 30;
            _unit = 'Minutes';
          }
        });
      },
    );
  }

  void _showTargetValuePicker() {
    _showOptions(
      'Target',
      [
        '1',
        '2',
        '3',
        '5',
        '8',
        '10',
        '20',
        '30',
        '60',
      ],
      (value) {
        setState(() {
          _targetValue = int.parse(value);
        });
      },
    );
  }

  void _showUnitPicker() {
    _showOptions(
      'Unit',
      [
        'Pages',
        'Cups',
        'Minutes',
        'Glasses',
        'Times',
        'Kilometers',
        'Done',
      ],
      (value) {
        setState(() {
          _unit = value;
        });
      },
    );
  }

  void _showOptions(
    String title,
    List<String> values,
    ValueChanged<String> onSelected,
  ) {
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
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ...values.map(
                  (value) => ListTile(
                    title: Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      onSelected(value);
                      Navigator.pop(context);
                    },
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

class _IconSelector extends StatelessWidget {
  final IconData selectedIcon;
  final Color color;
  final ValueChanged<IconData> onSelected;

  const _IconSelector({
    required this.selectedIcon,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.menu_book_rounded,
      Icons.water_drop_rounded,
      Icons.fitness_center_rounded,
      Icons.wb_sunny_rounded,
      Icons.bedtime_rounded,
      Icons.restaurant_rounded,
      Icons.self_improvement_rounded,
      Icons.school_rounded,
      Icons.directions_run_rounded,
      Icons.check_rounded,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: icons.map((icon) {
          final selected = icon == selectedIcon;

          return InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => onSelected(icon),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.18)
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: color,
                        width: 2,
                      )
                    : null,
              ),
              child: Icon(
                icon,
                color: selected ? color : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  const _ColorSelector({
    required this.selectedColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppTheme.primaryBlue,
      Color(0xFF34B27B),
      Color(0xFF8E67D4),
      Color(0xFFFFB84D),
      Color(0xFFFF7A90),
      Color(0xFF42A5F5),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: colors.map((color) {
          final selected = color.value == selectedColor.value;

          return InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () {
              onSelected(color);
            },
            child: Container(
              width: 45,
              height: 45,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: selected
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

class _DaysSelector extends StatelessWidget {
  final Set<int> selectedDays;
  final ValueChanged<int> onTap;

  const _DaysSelector({
    required this.selectedDays,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const days = [
      'M',
      'T',
      'W',
      'T',
      'F',
      'S',
      'S',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayNumber = index + 1;
        final selected = selectedDays.contains(dayNumber);

        return InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => onTap(dayNumber),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryBlue
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              days[index],
              style: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }),
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
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
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
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
          ),
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}