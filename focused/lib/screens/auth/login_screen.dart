import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/user_profile_provider.dart';

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
    final account = context.watch<AccountProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            const _Brand(),
            const SizedBox(height: 32),
            Text(
              _isRegister
                  ? 'Create your private\nFocused account.'
                  : 'Welcome back.',
              style: const TextStyle(
                color: Color(0xFFF3F7FF),
                fontSize: 33,
                height: 1.07,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isRegister
                  ? 'Create an account with Google or email. Tasks and habits can '
                      'sync across your devices; raw usage history stays on this device.'
                  : 'Sign in with Google or your Focused email/password.',
              style: const TextStyle(
                color: Color(0xFF91A2BB),
                height: 1.5,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 26),
            _ModeSelector(
              mode: _mode,
              onChanged: (mode) {
                setState(() => _mode = mode);
                context.read<AccountProvider>().clearError();
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: account.isBusy ? null : _continueWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B1423),
                  foregroundColor: const Color(0xFFEAF0FA),
                  side: const BorderSide(color: Color(0xFF223754)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleMark(),
                    SizedBox(width: 11),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
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
                      style: const TextStyle(color: Color(0xFFF3F7FF)),
                      cursorColor: const Color(0xFF7EA2FF),
                      decoration: _authInputDecoration(
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
                    style: const TextStyle(color: Color(0xFFF3F7FF)),
                    cursorColor: const Color(0xFF7EA2FF),
                    decoration: _authInputDecoration(
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
                    onFieldSubmitted:
                        _isRegister ? null : (_) => _submitEmail(),
                    style: const TextStyle(color: Color(0xFFF3F7FF)),
                    cursorColor: const Color(0xFF7EA2FF),
                    decoration: _authInputDecoration(
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
                      style: const TextStyle(color: Color(0xFFF3F7FF)),
                      cursorColor: const Color(0xFF7EA2FF),
                      decoration: _authInputDecoration(
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
                  backgroundColor: const Color(0xFF6F9AFF),
                  foregroundColor: const Color(0xFF06101F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: account.isBusy
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF06101F),
                        ),
                      )
                    : Text(
                        _isRegister ? 'Create account' : 'Sign in',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 22),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: Color(0xFF687D9C),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Your Focused account syncs productivity data across devices. '
                    'Raw screen-time, app-open, and notification history stays local.',
                    style: TextStyle(
                      color: Color(0xFF687D9C),
                      height: 1.45,
                      fontSize: 12.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _authInputDecoration({
    required String label,
    required IconData prefixIcon,
    String? helperText,
    Widget? suffixIcon,
  }) {
    const borderColor = Color(0xFF223754);
    const focusedBorderColor = Color(0xFF6F9AFF);

    return InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: const Color(0xFF0A1321),
      labelStyle: const TextStyle(color: Color(0xFF91A2BB)),
      floatingLabelStyle: const TextStyle(color: Color(0xFF9DB8FF)),
      helperStyle: const TextStyle(color: Color(0xFF687D9C)),
      errorStyle: const TextStyle(color: Color(0xFFFF9B9B)),
      prefixIcon: Icon(prefixIcon),
      prefixIconColor: const Color(0xFF7187A7),
      suffixIcon: suffixIcon,
      suffixIconColor: const Color(0xFF7187A7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: focusedBorderColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF8F3D49)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF7D8E), width: 1.5),
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
            content: Text(
              'Account created. A verification email was sent.',
            ),
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
        const SnackBar(
          content: Text('Enter your email address first.'),
        ),
      );
      return;
    }

    try {
      await context.read<AccountProvider>().sendPasswordReset(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent.'),
        ),
      );
    } catch (_) {}
  }

  Future<void> _syncLocalProfile(User user) {
    final account = context.read<AccountProvider>();

    return context.read<UserProfileProvider>().updateProfile(
          displayName: account.displayName,
          email: user.email ?? '',
        );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1A2D),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF25446F)),
          ),
          child: const Icon(
            Icons.center_focus_strong_rounded,
            color: Color(0xFF7EA2FF),
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FOCUSED',
              style: TextStyle(
                color: Color(0xFFF3F7FF),
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'PRIVATE • LOCAL FIRST',
              style: TextStyle(
                color: Color(0xFF6F829D),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D304B)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF152641) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? const Color(0xFFEAF1FF)
                : const Color(0xFF7588A4),
            fontWeight: FontWeight.w700,
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
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF3158A8),
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
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFF20304A))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: Color(0xFF61728D),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFF20304A))),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1218),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6B2B39)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFFB5C2),
          height: 1.4,
        ),
      ),
    );
  }
}
