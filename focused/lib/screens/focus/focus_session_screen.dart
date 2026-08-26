import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  bool _isPaused = false;
  bool _isBreak = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _showExitConfirmation,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  Text(
                    _isBreak ? 'Break' : 'Focus',
                    style: TextStyle(
                      color: _isBreak
                          ? const Color(0xFF34B27B)
                          : AppTheme.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),

              const Spacer(),

              Icon(
                _isBreak ? Icons.free_breakfast_rounded : Icons.code_rounded,
                size: 42,
                color: _isBreak
                    ? const Color(0xFF34B27B)
                    : AppTheme.primaryBlue,
              ),

              const SizedBox(height: 18),

              Text(
                _isBreak ? 'Take a break' : 'Study Flutter',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isBreak
                    ? 'Step away for a few minutes.'
                    : 'Focus block 1 of 3',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.50),
                ),
              ),

              const SizedBox(height: 44),

              SizedBox(
                width: 270,
                height: 270,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: _isBreak ? 0.25 : 0.18,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        backgroundColor:
                            (_isBreak
                                    ? const Color(0xFF34B27B)
                                    : AppTheme.primaryBlue)
                                .withOpacity(0.12),
                        color: _isBreak
                            ? const Color(0xFF34B27B)
                            : AppTheme.primaryBlue,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isBreak ? '08:42' : '41:27',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isPaused ? 'Paused' : 'Remaining',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              if (!_isBreak)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showExitConfirmation,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('End'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _isPaused = !_isPaused;
                          });
                        },
                        icon: Icon(
                          _isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(_isPaused ? 'Resume' : 'Pause'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                  ],
                ),

              if (_isBreak)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _isBreak = false;
                          });
                        },
                        child: const Text(
                          'Continue',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        context.push('/focus/complete');
                      },
                      child: const Text('Skip Break'),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              if (!_isBreak)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isBreak = true;
                      _isPaused = false;
                    });
                  },
                  child: const Text('Preview break screen'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
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
                const Icon(Icons.timer_off_outlined, size: 42),
                const SizedBox(height: 12),
                Text(
                  'End focus session?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your completed focus time will eventually still be recorded.',
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
                      context.go('/');
                    },
                    child: const Text('End Session'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Keep Focusing'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
