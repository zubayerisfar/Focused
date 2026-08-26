import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FocusInterruptionDetailsScreen extends StatelessWidget {
  const FocusInterruptionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Interruptions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const _SessionSummaryCard(),
          const SizedBox(height: 24),
          Text(
            'Interruption timeline',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const _TimelineCard(),
          const SizedBox(height: 26),
          Text(
            'Top interrupter apps',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const _TopInterruptersCard(),
          const SizedBox(height: 26),
          Text(
            'Session insight',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const _SessionInsightCard(),
        ],
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard();

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
                  Icons.timer_outlined,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Flutter',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text('2:00 PM – 3:30 PM'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF34B27B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '86%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF34B27B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Expanded(child: _SummaryMetric(label: 'Planned', value: '90m')),
              Expanded(child: _SummaryMetric(label: 'Effective', value: '77m')),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: _SummaryMetric(label: 'Distracted', value: '13m')),
              Expanded(child: _SummaryMetric(label: 'Interruptions', value: '3')),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              value: 0.856,
              minHeight: 9,
              color: Color(0xFF34B27B),
              backgroundColor: Color(0x1F34B27B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Focus quality = effective focus ÷ planned time',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.50),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard();

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
          _TimelineItem(
            time: '2:17 PM',
            icon: Icons.photo_camera_outlined,
            app: 'Instagram',
            duration: '4m',
          ),
          _TimelineDivider(),
          _TimelineItem(
            time: '2:42 PM',
            icon: Icons.chat_bubble_outline_rounded,
            app: 'WhatsApp',
            duration: '2m',
          ),
          _TimelineDivider(),
          _TimelineItem(
            time: '3:05 PM',
            icon: Icons.play_circle_outline_rounded,
            app: 'YouTube',
            duration: '7m',
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String time;
  final IconData icon;
  final String app;
  final String duration;

  const _TimelineItem({
    required this.time,
    required this.icon,
    required this.app,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8A65).withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFF8A65), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(app, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        Text(
          duration,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFFFF8A65),
          ),
        ),
      ],
    );
  }
}

class _TimelineDivider extends StatelessWidget {
  const _TimelineDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 82),
      child: Divider(
        height: 24,
        color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
      ),
    );
  }
}

class _TopInterruptersCard extends StatelessWidget {
  const _TopInterruptersCard();

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
          _InterrupterRow(
            rank: '1',
            app: 'YouTube',
            time: '7m',
            interruptions: '1 interruption',
            progress: 1.0,
          ),
          SizedBox(height: 18),
          _InterrupterRow(
            rank: '2',
            app: 'Instagram',
            time: '4m',
            interruptions: '1 interruption',
            progress: 0.57,
          ),
          SizedBox(height: 18),
          _InterrupterRow(
            rank: '3',
            app: 'WhatsApp',
            time: '2m',
            interruptions: '1 interruption',
            progress: 0.29,
          ),
        ],
      ),
    );
  }
}

class _InterrupterRow extends StatelessWidget {
  final String rank;
  final String app;
  final String time;
  final String interruptions;
  final double progress;

  const _InterrupterRow({
    required this.rank,
    required this.app,
    required this.time,
    required this.interruptions,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.10),
          child: Text(
            rank,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(time, style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                interruptions,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.52),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  color: const Color(0xFFFF8A65),
                  backgroundColor: const Color(0xFFFF8A65).withOpacity(0.10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionInsightCard extends StatelessWidget {
  const _SessionInsightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.09),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You planned 90 minutes and lost 13 minutes to other apps. '
              'YouTube caused the longest interruption, reducing your effective focus to 77 minutes.',
              style: TextStyle(
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
