import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/onboarding_provider.dart';

class IntroSequenceScreen extends StatefulWidget {
  const IntroSequenceScreen({super.key});

  @override
  State<IntroSequenceScreen> createState() =>
      _IntroSequenceScreenState();
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || _finishing) return;

    setState(() => _visible = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _finishing) return;

    setState(() => _visible = false);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || _finishing) return;

    setState(() {
      _scene = 1;
      _visible = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (!mounted || _finishing) return;

    setState(() => _visible = false);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (mounted && !_finishing) {
      await _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await context.read<OnboardingProvider>().completeIntro();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.08),
                    radius: 0.9,
                    colors: [
                      Color(0xFF08111F),
                      Color(0xFF03070D),
                      Color(0xFF02050A),
                    ],
                    stops: [0.0, 0.58, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 14,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Color(0xFF7789A3),
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
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: _visible
                        ? Offset.zero
                        : const Offset(0, 0.035),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    child: _scene == 0
                        ? const Text(
                            'Welcome.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFF4F7FC),
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.9,
                            ),
                          )
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Let’s set up your account\nto get started.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFF4F7FC),
                                  fontSize: 30,
                                  height: 1.16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.7,
                                ),
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Your workspace stays local-first and private by design.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF8293AC),
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
    );
  }
}
