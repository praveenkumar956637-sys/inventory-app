import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

/// A clean, user-friendly error. The UI shows [message] directly.
class AppException implements Exception {
  final String message;

  const AppException(this.message);

  /// Converts any error (Firebase or otherwise) into an [AppException].
  factory AppException.from(Object error) {
    if (error is AppException) return error;
    // FirebaseAuthException extends FirebaseException, so check it first.
    if (error is FirebaseAuthException) {
      return AppException(_authMessage(error.code));
    }
    if (error is FirebaseException) {
      return AppException(_firestoreMessage(error.code));
    }
    return const AppException('Something went wrong. Please try again.');
  }

  /// Convenience for UI code: the message to show for any caught error.
  static String messageOf(Object error) => AppException.from(error).message;

  @override
  String toString() => message;
}

String _authMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'user-not-found':
      return 'No account found with this email.';
    case 'wrong-password':
      return 'Incorrect password. Please try again.';
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Incorrect email or password.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'No internet connection. Please check your network.';
    default:
      return 'Login failed. Please try again.';
  }
}

String _firestoreMessage(String code) {
  switch (code) {
    case 'permission-denied':
      return 'You do not have permission to do this.';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'Network error. Please check your connection and try again.';
    case 'not-found':
      return 'The requested item was not found.';
    case 'aborted':
      return 'Another change happened at the same time. Please try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  User? get currentUser => _auth.currentUser;

  /// Logs in, then checks the Firestore user document (exists, active, valid role).
  /// If anything fails the user is signed out again and an [AppException] is thrown.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        throw const AppException('Login failed. Please try again.');
      }
      return await _loadAllowedProfile(user.uid);
    } catch (e) {
      await _safeSignOut();
      throw AppException.from(e);
    }
  }

  /// Used when the app starts. Returns null when nobody is signed in.
  /// Throws [AppException] when the saved account is no longer allowed in
  /// (in that case the user is also signed out).
  Future<UserModel?> restoreSession() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await _loadAllowedProfile(user.uid);
    } on AppException {
      await _safeSignOut();
      rethrow;
    } catch (e) {
      // Network or other read problems: keep the session, report the problem.
      throw AppException.from(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// The signed-in user's profile, re-checked against Firestore.
  /// Throws if not logged in, inactive, or role is invalid.
  Future<UserModel> requireActiveUser() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const AppException('Please log in to continue.');
    }
    try {
      return await _loadAllowedProfile(user.uid);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Same as [requireActiveUser] but the user must also be an admin.
  Future<UserModel> requireAdmin() async {
    final UserModel profile = await requireActiveUser();
    if (!profile.isAdmin) {
      throw const AppException('Only an administrator can do this.');
    }
    return profile;
  }

  /// All users. Admin only (checked before the stream starts).
  Stream<List<UserModel>> streamUsers() async* {
    await requireAdmin();
    yield* _users.snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<UserModel> list = snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                UserModel.fromMap(doc.data(), doc.id),
          )
          .toList();
      list.sort(
        (UserModel a, UserModel b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    });
  }

  /// Map of uid -> name, used to show "who did this" in transaction lists.
  Future<Map<String, String>> getUserNameMap() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await _users.get();
      final Map<String, String> names = <String, String>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        final String name = (doc.data()['name'] as String?) ?? '';
        names[doc.id] = name.isEmpty ? 'Unknown' : name;
      }
      return names;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<UserModel> _loadAllowedProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _users
        .doc(uid)
        .get();
    final Map<String, dynamic>? data = doc.data();
    if (!doc.exists || data == null) {
      throw const AppException(
        'Your account is not set up. Please contact the administrator.',
      );
    }
    final UserModel profile = UserModel.fromMap(data, doc.id);
    if (!profile.active) {
      throw const AppException(
        'Your account is inactive. Please contact the administrator.',
      );
    }
    if (!profile.isAdmin && !profile.isStaff) {
      throw const AppException(
        'Your account has no valid role. Please contact the administrator.',
      );
    }
    return profile;
  }

  Future<void> _safeSignOut() async {
    try {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
    } catch (_) {
      // Nothing useful to do if sign-out itself fails.
    }
  }
}
