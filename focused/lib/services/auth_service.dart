import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, GoogleAuthProvider, User, UserCredential;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  bool _googleInitialized = false;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  bool get _supportsNativeGoogleSignIn {
    if (kIsWeb) return true;

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _initializeGoogleIfNeeded() async {
    if (_googleInitialized) return;

    if (!_supportsNativeGoogleSignIn) {
      throw UnsupportedError(
        'Google Sign-In is not available on this platform yet.',
      );
    }

    // Android reads the Web OAuth client ID from google-services.json.
    // We intentionally do not hard-code an OAuth client ID here.
    await GoogleSignIn.instance.initialize();

    _googleInitialized = true;
  }

  Future<UserCredential> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential =
        await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      final cleanName = name.trim();

      if (cleanName.isNotEmpty) {
        await user.updateDisplayName(cleanName);
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }

      await user.reload();
    }

    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    await _initializeGoogleIfNeeded();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google Sign-In cannot start an interactive login on this platform.',
      );
    }

    final googleUser =
        await GoogleSignIn.instance.authenticate();

    final googleAuthentication =
        googleUser.authentication;

    final idToken = googleAuthentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google Sign-In completed without returning an ID token.',
      );
    }

    final firebaseCredential =
        GoogleAuthProvider.credential(
      idToken: idToken,
    );

    return _firebaseAuth.signInWithCredential(
      firebaseCredential,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _firebaseAuth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  Future<void> sendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('No signed-in Firebase user.');
    }

    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    await user.reload();
  }

  Future<void> updateDisplayName(String name) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('No signed-in Firebase user.');
    }

    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError(
        'Display name cannot be empty.',
      );
    }

    await user.updateDisplayName(cleanName);
    await user.reload();
  }

  Future<void> signOut() async {
    if (_googleInitialized &&
        _supportsNativeGoogleSignIn) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase sign-out still needs to complete even if the native
        // Google session has already disappeared.
      }
    }

    await _firebaseAuth.signOut();
  }
}
