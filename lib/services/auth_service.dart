import 'package:firebase_auth/firebase_auth.dart';

abstract interface class AuthService {
  Future<void> login({required String email, required String password});

  Future<void> register({
    required String name,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> logout();

  /// Updates the signed-in user's login email. Firebase may require a
  /// recent sign-in for this — callers should catch [AuthException] and
  /// prompt a re-login if it fails for that reason.
  Future<void> updateEmail({required String email});

  /// Updates the signed-in user's password. Same recent-sign-in caveat as
  /// [updateEmail].
  Future<void> updatePassword({required String password});

  /// Permanently deletes the signed-in user's Auth account. Callers should
  /// delete the user's Firestore data first (see
  /// `ProfileRepository.deleteProfileData`) since this invalidates their
  /// session immediately.
  Future<void> deleteAccount();

  /// The signed-in user's uid, or null if nobody's signed in. Used right
  /// after registration to create that user's Firestore profile document —
  /// see ProfileRepository.ensureProfileDocument() and register_screen.dart.
  String? get currentUserId;

  /// The signed-in user's display name, or null. Used when posting a
  /// Moodify — see MoodifyRepository.post() and create_controller.dart.
  String? get currentUserName;
}

/// Thrown by [FirebaseAuthService] with a message safe to show in the UI.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<void> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> logout() => _auth.signOut();

  @override
  Future<void> updateEmail({required String email}) async {
    try {
      // verifyBeforeUpdateEmail sends a confirmation link to the new
      // address rather than switching immediately — the safer modern
      // replacement for the now-deprecated updateEmail().
      await _auth.currentUser?.verifyBeforeUpdateEmail(email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> updatePassword({required String password}) async {
    try {
      await _auth.currentUser?.updatePassword(password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentUserName => _auth.currentUser?.displayName;

  /// Not part of [AuthService] — nothing else in the app needs the raw
  /// email, only account-details.html's edit form. Kept here rather than
  /// widening the shared interface for a single caller.
  String? get currentUserEmail => _auth.currentUser?.email;

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'requires-recent-login':
        return 'For security, please log out and back in before changing this.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

/// Kept for local/offline dev and widget tests — no longer wired to any
/// screen by default now that FirebaseAuthService is live.
class FakeAuthService implements AuthService {
  @override
  Future<void> login({required String email, required String password}) =>
      Future.delayed(const Duration(milliseconds: 600));

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) =>
      Future.delayed(const Duration(milliseconds: 600));

  @override
  Future<void> sendPasswordReset({required String email}) =>
      Future.delayed(const Duration(milliseconds: 400));

  @override
  Future<void> logout() => Future.delayed(const Duration(milliseconds: 200));

  @override
  Future<void> updateEmail({required String email}) => Future.delayed(const Duration(milliseconds: 300));

  @override
  Future<void> updatePassword({required String password}) => Future.delayed(const Duration(milliseconds: 300));

  @override
  Future<void> deleteAccount() => Future.delayed(const Duration(milliseconds: 300));

  @override
  String? get currentUserId => null;

  @override
  String? get currentUserName => null;
}