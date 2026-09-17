import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/account_provider.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/widgets/glass_container.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/providers/user_profile_provider.dart';

enum _AuthMode { register, login }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.register;
  bool _hidePassword = true;

  bool get _isRegister => _mode == _AuthMode.register;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final account = context.watch<AccountProvider>();

    return GlassScaffoldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              const _Brand(),
              const SizedBox(height: 24),
              Text(
                _isRegister ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  color: scheme.onSurface,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 22),
              _ModeSelector(
                mode: _mode,
                onChanged: (mode) {
                  setState(() => _mode = mode);
                  context.read<AccountProvider>().clearError();
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: account.isBusy ? null : _continueWithGoogle,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark
                        ? scheme.surface.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.9),
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _GoogleMark(),
                      const SizedBox(width: 12),
                      Text(
                        _isRegister
                            ? 'Continue with Google'
                            : 'Login with Google',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 15.0,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _OrDivider(),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: scheme.onSurface),
                        cursorColor: scheme.primary,
                        decoration: _authInputDecoration(
                          context: context,
                          label: 'Your name',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().length < 2) {
                            return 'Enter your name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 13),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: TextStyle(color: scheme.onSurface),
                      cursorColor: scheme.primary,
                      decoration: _authInputDecoration(
                        context: context,
                        label: 'Email',
                        prefixIcon: Icons.alternate_email_rounded,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (!text.contains('@') || !text.contains('.')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 13),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      textInputAction: _isRegister
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: _isRegister
                          ? null
                          : (_) => _submitEmail(),
                      style: TextStyle(color: scheme.onSurface),
                      cursorColor: scheme.primary,
                      decoration: _authInputDecoration(
                        context: context,
                        label: 'Password',
                        helperText: _isRegister
                            ? 'Your Focused password — not your Google password.'
                            : null,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _hidePassword = !_hidePassword);
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'Use at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    if (_isRegister) ...[
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitEmail(),
                        style: TextStyle(color: scheme.onSurface),
                        cursorColor: scheme.primary,
                        decoration: _authInputDecoration(
                          context: context,
                          label: 'Confirm password',
                          prefixIcon: Icons.verified_user_outlined,
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (!_isRegister)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: account.isBusy ? null : _sendPasswordReset,
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 20),
              if (account.errorMessage != null) ...[
                _ErrorCard(message: account.errorMessage!),
                const SizedBox(height: 14),
              ],
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: account.isBusy ? null : _submitEmail,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1CB0F6),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 2,
                    shadowColor: const Color(
                      0xFF1CB0F6,
                    ).withValues(alpha: 0.35),
                  ),
                  child: account.isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isRegister ? 'Create account' : 'Sign in',
                          style: const TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
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

  InputDecoration _authInputDecoration({
    required BuildContext context,
    required String label,
    required IconData prefixIcon,
    String? helperText,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: isDark
          ? scheme.surface.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.9),
      labelStyle: TextStyle(
        fontFamily: 'Quicksand',
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        fontFamily: 'Quicksand',
        color: Color(0xFF1CB0F6),
        fontWeight: FontWeight.w700,
      ),
      helperStyle: TextStyle(
        fontFamily: 'Quicksand',
        color: scheme.onSurfaceVariant,
      ),
      errorStyle: TextStyle(
        fontFamily: 'Quicksand',
        color: scheme.error,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(prefixIcon, size: 22),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIcon: suffixIcon,
      suffixIconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF1CB0F6), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.error, width: 1.8),
      ),
    );
  }

  Future<void> _continueWithGoogle() async {
    final account = context.read<AccountProvider>();

    try {
      final user = await account.continueWithGoogle();
      if (user == null || !mounted) return;
      await _syncLocalProfile(user);
    } catch (_) {
      // Provider exposes a user-friendly error in the form.
    }
  }

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final account = context.read<AccountProvider>();

    try {
      late final User user;

      if (_isRegister) {
        user = await account.registerWithEmail(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        user = await account.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      await _syncLocalProfile(user);

      if (!mounted) return;

      if (_isRegister && !account.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. A verification email was sent.'),
          ),
        );
      }
    } catch (_) {
      // Provider exposes a user-friendly error in the form.
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }

    try {
      await context.read<AccountProvider>().sendPasswordReset(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (_) {}
  }

  Future<void> _syncLocalProfile(User user) async {
    final account = context.read<AccountProvider>();
    final email = user.email ?? '';

    await context.read<UserProfileProvider>().updateProfile(
      displayName: account.displayName,
      email: email,
      username: UserProfile.defaultUsernameFromEmail(email),
    );

    if (mounted) {
      await context.read<UserProfileProvider>().syncFromFirestore(user.uid);
      await PushNotificationService.syncUserToken(user.uid);
    }
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Image.asset(
                'assets/app_icon/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Focused',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Lifestyle Manager',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Create account',
              selected: mode == _AuthMode.register,
              onTap: () => onChanged(_AuthMode.register),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Sign in',
              selected: mode == _AuthMode.login,
              onTap: () => onChanged(_AuthMode.login),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1CB0F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1CB0F6).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Quicksand',
            color: selected ? Colors.white : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(child: Divider(color: theme.dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: theme.dividerColor)),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'Quicksand',
          color: scheme.error,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
