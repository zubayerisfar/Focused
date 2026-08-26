import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class FocusSetupScreen extends StatefulWidget {
  const FocusSetupScreen({super.key});

  @override
  State<FocusSetupScreen> createState() => _FocusSetupScreenState();
}

class _FocusSetupScreenState extends State<FocusSetupScreen> {
  String _selectedTask = 'Study Flutter';

  int _totalMinutes = 120;
  int _focusMinutes = 50;
  int _breakMinutes = 10;

  @override
  Widget build(BuildContext context) {
    final sessionPlan = _buildSessionPlan();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Set Up Focus',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Plan your session',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose what you want to work on and how you want to focus.',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 28),

          // Task
          _SectionTitle(title: 'Task'),

          const SizedBox(height: 12),

          _AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: _showTaskPicker,
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.code_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: Text(
                _selectedTask,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Tap to choose another task',
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
              ),
            ),
          ),

          const SizedBox(height: 26),

          // Session settings
          _SectionTitle(title: 'Session'),

          const SizedBox(height: 12),

          _AppCard(
            child: Column(
              children: [
                _SettingRow(
                  title: 'Total duration',
                  value: _formatDuration(_totalMinutes),
                  onTap: _showTotalDurationPicker,
                ),
                const Divider(height: 1),
                _SettingRow(
                  title: 'Focus block',
                  value: '$_focusMinutes min',
                  onTap: _showFocusDurationPicker,
                ),
                const Divider(height: 1),
                _SettingRow(
                  title: 'Break',
                  value: '$_breakMinutes min',
                  onTap: _showBreakDurationPicker,
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Preview
          Row(
            children: [
              _SectionTitle(title: 'Session plan'),
              const Spacer(),
              Text(
                '${sessionPlan.where((item) => item.isWork).length} focus blocks',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.50),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _AppCard(
            child: Column(
              children: List.generate(
                sessionPlan.length,
                (index) {
                  final item = sessionPlan[index];

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          index == sessionPlan.length - 1 ? 0 : 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.isWork
                                ? AppTheme.primaryBlue.withOpacity(0.12)
                                : const Color(0xFF34B27B)
                                    .withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.isWork
                                ? Icons.timer_rounded
                                : Icons.free_breakfast_rounded,
                            color: item.isWork
                                ? AppTheme.primaryBlue
                                : const Color(0xFF34B27B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.isWork ? 'Focus' : 'Break',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${item.minutes} min',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: () {
                context.push('/focus/session');
              },
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: const Text(
                'Start Focus Session',
                style: TextStyle(
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

  List<_FocusPlanItem> _buildSessionPlan() {
    final plan = <_FocusPlanItem>[];

    int remainingMinutes = _totalMinutes;

    while (remainingMinutes > 0) {
      final currentFocusMinutes =
          remainingMinutes >= _focusMinutes
              ? _focusMinutes
              : remainingMinutes;

      plan.add(
        _FocusPlanItem(
          isWork: true,
          minutes: currentFocusMinutes,
        ),
      );

      remainingMinutes -= currentFocusMinutes;

      if (remainingMinutes > 0) {
        plan.add(
          _FocusPlanItem(
            isWork: false,
            minutes: _breakMinutes,
          ),
        );
      }
    }

    return plan;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  void _showTaskPicker() {
    _showOptions(
      title: 'Choose task',
      options: const [
        'Study Flutter',
        'Finish assignment',
        'Review project presentation',
        'Read 20 pages',
      ],
      onSelected: (value) {
        setState(() {
          _selectedTask = value;
        });
      },
    );
  }

  void _showTotalDurationPicker() {
    _showOptions(
      title: 'Total duration',
      options: const [
        '30',
        '60',
        '90',
        '120',
        '180',
      ],
      displayText: (value) {
        return _formatDuration(int.parse(value));
      },
      onSelected: (value) {
        setState(() {
          _totalMinutes = int.parse(value);
        });
      },
    );
  }

  void _showFocusDurationPicker() {
    _showOptions(
      title: 'Focus block',
      options: const [
        '25',
        '30',
        '45',
        '50',
        '60',
        '90',
      ],
      displayText: (value) => '$value min',
      onSelected: (value) {
        setState(() {
          _focusMinutes = int.parse(value);
        });
      },
    );
  }

  void _showBreakDurationPicker() {
    _showOptions(
      title: 'Break',
      options: const [
        '5',
        '10',
        '15',
        '20',
      ],
      displayText: (value) => '$value min',
      onSelected: (value) {
        setState(() {
          _breakMinutes = int.parse(value);
        });
      },
    );
  }

  void _showOptions({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
    String Function(String value)? displayText,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (value) {
                    return ListTile(
                      title: Text(
                        displayText?.call(value) ?? value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        onSelected(value);
                        Navigator.pop(context);
                      },
                    );
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

class _FocusPlanItem {
  final bool isWork;
  final int minutes;

  const _FocusPlanItem({
    required this.isWork,
    required this.minutes,
  });
}

class _AppCard extends StatelessWidget {
  final Widget child;

  const _AppCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
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

  const _SectionTitle({
    required this.title,
  });

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