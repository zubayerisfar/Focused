import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AppUsageDetailsScreen extends StatefulWidget {
  const AppUsageDetailsScreen({super.key});

  @override
  State<AppUsageDetailsScreen> createState() => _AppUsageDetailsScreenState();
}

class _AppUsageDetailsScreenState extends State<AppUsageDetailsScreen> {
  int _selectedPeriod = 0;

  final List<String> _periods = const ['Day', 'Week', 'Month'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Usage')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SegmentedButton<int>(
            segments: List.generate(
              _periods.length,
              (index) => ButtonSegment<int>(
                value: index,
                label: Text(_periods[index]),
              ),
            ),
            selected: {_selectedPeriod},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedPeriod = selection.first;
              });
            },
          ),
          const SizedBox(height: 22),
          const _TotalUsageCard(),
          const SizedBox(height: 24),
          Text(
            'Usage trend',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const _UsageChart(),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Most used apps',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AppListCard(),
          const SizedBox(height: 26),
          Text(
            'Comparison',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const _ComparisonCard(),
        ],
      ),
    );
  }
}

class _TotalUsageCard extends StatelessWidget {
  const _TotalUsageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B5E).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '↑ 12%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF6B5E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '4h 18m',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            'Total screen time today',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '28 minutes more than yesterday',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _UsageChart extends StatelessWidget {
  const _UsageChart();

  @override
  Widget build(BuildContext context) {
    const values = [0.46, 0.68, 0.52, 0.88, 0.72, 0.42, 0.62];
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: values[index],
                        child: Container(
                          decoration: BoxDecoration(
                            color: index == 6
                                ? AppTheme.primaryBlue
                                : AppTheme.primaryBlue.withOpacity(0.30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    days[index],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AppListCard extends StatelessWidget {
  const _AppListCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          _AppUsageItem(
            icon: Icons.photo_camera_outlined,
            name: 'Instagram',
            duration: '1h 28m',
            percent: '34%',
            change: '↑ 21%',
            changeColor: Color(0xFFFF6B5E),
            progress: 0.82,
          ),
          SizedBox(height: 20),
          _AppUsageItem(
            icon: Icons.play_circle_outline_rounded,
            name: 'YouTube',
            duration: '58m',
            percent: '22%',
            change: '↓ 14%',
            changeColor: Color(0xFF34B27B),
            progress: 0.58,
          ),
          SizedBox(height: 20),
          _AppUsageItem(
            icon: Icons.public_rounded,
            name: 'Chrome',
            duration: '47m',
            percent: '18%',
            change: '↑ 5%',
            changeColor: Color(0xFFFF8A65),
            progress: 0.46,
          ),
          SizedBox(height: 20),
          _AppUsageItem(
            icon: Icons.chat_bubble_outline_rounded,
            name: 'WhatsApp',
            duration: '31m',
            percent: '12%',
            change: '↓ 3%',
            changeColor: Color(0xFF34B27B),
            progress: 0.32,
          ),
          SizedBox(height: 20),
          _AppUsageItem(
            icon: Icons.more_horiz_rounded,
            name: 'Other apps',
            duration: '34m',
            percent: '14%',
            change: '↑ 2%',
            changeColor: Color(0xFFFF8A65),
            progress: 0.35,
          ),
        ],
      ),
    );
  }
}

class _AppUsageItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String duration;
  final String percent;
  final String change;
  final Color changeColor;
  final double progress;

  const _AppUsageItem({
    required this.icon,
    required this.name,
    required this.duration,
    required this.percent,
    required this.change,
    required this.changeColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    duration,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(
                    percent,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.52),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    change,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: changeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: AppTheme.primaryBlue,
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          _ComparisonRow(
            label: 'Today vs yesterday',
            value: '+12%',
            positive: false,
          ),
          Divider(height: 28),
          _ComparisonRow(
            label: 'This week vs last week',
            value: '-6%',
            positive: true,
          ),
          Divider(height: 28),
          _ComparisonRow(
            label: 'This month vs last month',
            value: '-9%',
            positive: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String value;
  final bool positive;

  const _ComparisonRow({
    required this.label,
    required this.value,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF34B27B) : const Color(0xFFFF6B5E);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
