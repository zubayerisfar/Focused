import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, User;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;

import '../services/auth_service.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider({
    required AuthService authService,
  }) : _authService = authService;

  final AuthService _authService;

  StreamSubscription<User?>? _subscription;

  User? _user;
  bool _busy = false;
  bool _initialized = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isBusy => _busy;
  bool get isInitialized => _initialized;
  String? get errorMessage => _errorMessage;

  String get displayName {
    final name = _user?.displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return displayNameFromEmail(_user?.email);
  }

  String get email => _user?.email?.trim() ?? '';

  String? get photoUrl {
    final value = _user?.photoURL?.trim();

    return value == null || value.isEmpty
        ? null
        : value;
  }

  bool get emailVerified =>
      _user?.emailVerified ?? false;

  bool get signedInWithGoogle {
    final providers =
        _user?.providerData ?? const [];

    return providers.any(
      (provider) =>
          provider.providerId == 'google.com',
    );
  }

  Future<void> initialize() async {
    // FirebaseAuth restores its own signed-in session. Google Sign-In is
    // initialized only when the user actually taps Continue with Google,
    // so a Google OAuth configuration issue can never block email login
    // or app startup.
    _user = _authService.currentUser;
    _initialized = true;

    _subscription =
        _authService.authStateChanges.listen(
      (user) {
        _user = user;
        notifyListeners();
      },
    );
  }

  Future<User> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) {
    return _runAuthAction(() async {
      final credential =
          await _authService.registerWithEmail(
        name: name,
        email: email,
        password: password,
      );

      await _authService.reloadCurrentUser();

      final user =
          _authService.currentUser ??
          credential.user;

      if (user == null) {
        throw StateError(
          'Firebase did not return a user.',
        );
      }

      _user = user;
      notifyListeners();

      return user;
    });
  }

  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _runAuthAction(() async {
      final credential =
          await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw StateError(
          'Firebase did not return a user.',
        );
      }

      _user = user;
      notifyListeners();

      return user;
    });
  }

  Future<User?> continueWithGoogle() async {
    _setBusy(true);
    _errorMessage = null;

    try {
      final credential =
          await _authService.signInWithGoogle();

      final user = credential.user;

      if (user == null) {
        throw StateError(
          'Firebase did not return a Google user.',
        );
      }

      _user = user;
      notifyListeners();

      return user;
    } on GoogleSignInException catch (error) {
      final description =
          (error.description ?? '').toLowerCase();

      // On Android Credential Manager, some OAuth configuration errors
      // unfortunately arrive as "canceled". A genuine back/cancel usually
      // has no useful description, while reauth/configuration failures do.
      if (error.code ==
          GoogleSignInExceptionCode.canceled) {
        final looksLikeConfigurationFailure =
            description.contains('reauth') ||
            description.contains('configuration') ||
            description.contains('client') ||
            description.contains('serverclientid');

        if (!looksLikeConfigurationFailure) {
          return null;
        }

        _errorMessage =
            'Google could open the account picker but could not '
            'authenticate this Android build. Check the debug SHA-1/'
            'SHA-256 and confirm google-services.json contains a Web '
            'OAuth client (client_type 3).';
      } else {
        _errorMessage =
            _friendlyGoogleMessage(error);
      }

      notifyListeners();
      rethrow;
    } on FirebaseAuthException catch (error) {
      _errorMessage =
          _friendlyFirebaseMessage(error);
      notifyListeners();
      rethrow;
    } catch (error) {
      _errorMessage = error
          .toString()
          .replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> sendPasswordReset(
    String email,
  ) async {
    _errorMessage = null;

    try {
      await _authService
          .sendPasswordReset(email);
    } on FirebaseAuthException catch (error) {
      _errorMessage =
          _friendlyFirebaseMessage(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> resendVerificationEmail() async {
    _errorMessage = null;

    try {
      await _authService
          .sendVerificationEmail();
    } on FirebaseAuthException catch (error) {
      _errorMessage =
          _friendlyFirebaseMessage(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshUser() async {
    await _authService.reloadCurrentUser();
    _user = _authService.currentUser;
    notifyListeners();
  }

  Future<void> updateDisplayName(
    String name,
  ) async {
    _setBusy(true);
    _errorMessage = null;

    try {
      await _authService
          .updateDisplayName(name);

      _user = _authService.currentUser;
      notifyListeners();
    } on FirebaseAuthException catch (error) {
      _errorMessage =
          _friendlyFirebaseMessage(error);
      notifyListeners();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    _errorMessage = null;

    try {
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    notifyListeners();
  }

  Future<T> _runAuthAction<T>(
    Future<T> Function() action,
  ) async {
    _setBusy(true);
    _errorMessage = null;

    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      _errorMessage =
          _friendlyFirebaseMessage(error);
      notifyListeners();
      rethrow;
    } catch (error) {
      _errorMessage = error
          .toString()
          .replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (_busy == value) return;

    _busy = value;
    notifyListeners();
  }

  static String displayNameFromEmail(
    String? email,
  ) {
    final cleanEmail = email?.trim() ?? '';

    if (cleanEmail.isEmpty) {
      return 'Focused User';
    }

    final localPart =
        cleanEmail.split('@').first.trim();

    if (localPart.isEmpty) {
      return 'Focused User';
    }

    final words = localPart
        .replaceAll(RegExp(r'[._\-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}'
                  '${word.substring(1)}',
        )
        .toList();

    return words.isEmpty
        ? 'Focused User'
        : words.join(' ');
  }

  static String _friendlyGoogleMessage(
    GoogleSignInException error,
  ) {
    switch (error.code) {
      case GoogleSignInExceptionCode
            .clientConfigurationError:
      case GoogleSignInExceptionCode
            .providerConfigurationError:
        return 'Google Sign-In is not configured correctly for this '
            'Android build. Check the debug SHA fingerprints and Web '
            'OAuth client.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google Sign-In was interrupted. Please try again.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google Sign-In cannot open its account picker right now.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Google returned a different account than expected. '
            'Sign out and try again.';
      default:
        return error.description ??
            'Google Sign-In failed. Please try again.';
    }
  }

  static String _friendlyFirebaseMessage(
    FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'email-already-in-use':
        return 'This email already has an account. Sign in instead.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'account-exists-with-different-credential':
        return 'An account already exists for this email using another '
            'sign-in method.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'network-request-failed':
        return 'Could not reach Firebase. Check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase '
            'Authentication.';
      default:
        return error.message ??
            'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
