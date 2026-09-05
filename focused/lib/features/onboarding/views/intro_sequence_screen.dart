import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/onboarding_provider.dart';

class IntroSequenceScreen extends StatefulWidget {
  const IntroSequenceScreen({super.key});

  @override
  State<IntroSequenceScreen> createState() => _IntroSequenceScreenState();
}

class _IntroSequenceScreenState extends State<IntroSequenceScreen> {
  int _scene = 0;
  bool _visible = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_play());
  }

  Future<void> _play() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || _finishing) return;

    setState(() => _visible = true);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted || _finishing) return;

    setState(() => _visible = false);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || _finishing) return;

    setState(() {
      _scene = 1;
      _visible = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 3600));
    if (!mounted || _finishing) return;

    setState(() => _visible = false);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (mounted && !_finishing) {
      await _finish();
    }
  }

  void _nextSceneOrFinish() {
    if (_finishing) return;
    if (_scene == 0) {
      setState(() {
        _scene = 1;
        _visible = true;
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await context.read<OnboardingProvider>().completeIntro();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF02050A)
          : const Color(0xFFF7F6F2),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _nextSceneOrFinish,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.08),
                      radius: 0.9,
                      colors: isDark
                          ? const [
                              Color(0xFF08111F),
                              Color(0xFF03070D),
                              Color(0xFF02050A),
                            ]
                          : const [
                              Color(0xFFFFFFFF),
                              Color(0xFFF9F8F5),
                              Color(0xFFF4F3EE),
                            ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 14,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF7789A3)
                          : const Color(0xFF7584B8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: AnimatedOpacity(
                    opacity: _visible ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOutCubic,
                    child: AnimatedSlide(
                      offset: _visible ? Offset.zero : const Offset(0, 0.035),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeInOutCubic,
                      child: _scene == 0
                          ? Text(
                              'Welcome',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFF4F7FC)
                                    : const Color(0xFF292B31),
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.9,
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Let’s set up your account\nto get started',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFF4F7FC)
                                        : const Color(0xFF292B31),
                                    fontSize: 30,
                                    height: 1.16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Your workspace stays local-first and private by design.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF8293AC)
                                        : const Color(0xFF6F727A),
                                    fontSize: 14,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
