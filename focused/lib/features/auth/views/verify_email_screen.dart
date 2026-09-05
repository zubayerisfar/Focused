import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/account_provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _pollingTimer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  bool _isChecking = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Periodically poll every 4 seconds to detect when user verifies in browser
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkVerificationSilently();
    });

    // Run an immediate check on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationSilently();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns to Focused after clicking the link in their mail app
    if (state == AppLifecycleState.resumed) {
      _checkVerificationSilently();
    }
  }

  Future<void> _checkVerificationSilently() async {
    if (!mounted) return;
    try {
      final account = context.read<AccountProvider>();
      if (account.isSignedIn && !account.emailVerified) {
        await account.refreshUser();
      }
    } catch (_) {
      // Background poll silently ignores network blips
    }
  }

  Future<void> _checkVerificationManually() async {
    if (_isChecking || !mounted) return;
    setState(() => _isChecking = true);

    try {
      final account = context.read<AccountProvider>();
      await account.refreshUser();

      if (!mounted) return;

      if (!account.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: const Text(
              'Email not verified yet. Please check your inbox and tap the link.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not refresh status: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCooldown > 0 || _isResending || !mounted) return;
    setState(() => _isResending = true);

    try {
      final account = context.read<AccountProvider>();
      await account.resendVerificationEmail();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Text(
            'Verification email resent! Please check your inbox (and spam folder).',
          ),
        ),
      );

      // Start 60-second cooldown timer
      setState(() => _resendCooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_resendCooldown <= 1) {
          timer.cancel();
          setState(() => _resendCooldown = 0);
        } else {
          setState(() => _resendCooldown--);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Failed to resend: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _signOut() async {
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    try {
      await context.read<AccountProvider>().signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final account = context.watch<AccountProvider>();
    final userEmail = account.email;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated / highlighted mail icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(
                        alpha: isDark ? 0.22 : 0.12,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(
                          alpha: isDark ? 0.45 : 0.25,
                        ),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        size: 46,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Verify your email',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent an activation link to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // User email pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor,
                      ),
                    ),
                    child: Text(
                      userEmail.isNotEmpty ? userEmail : 'your email address',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Click the link in the email to activate your account. Once verified, you will be automatically redirected.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Helpful tip about spam folder
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Can't find the email? Check your Spam or Junk folder, or tap resend below.",
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Primary Check Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isChecking ? null : _checkVerificationManually,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isChecking
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Text(
                              "I've verified my email",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Resend Email Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: (_resendCooldown > 0 || _isResending)
                          ? null
                          : _resendVerificationEmail,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.dividerColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isResending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            )
                          : Text(
                              _resendCooldown > 0
                                  ? 'Resend email in ${_resendCooldown}s'
                                  : 'Resend verification email',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: _resendCooldown > 0
                                    ? scheme.onSurfaceVariant
                                    : scheme.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Wrong email / Sign out link
                  TextButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'Entered the wrong email? Back to sign in',
                      style: TextStyle(fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
