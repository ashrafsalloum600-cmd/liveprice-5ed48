import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  static const List<String> adminEmails = ['ashrafsalloum600@gmail.com'];

  Stream<User?> get authState => _firebaseAuth.authStateChanges();

  bool isAdmin(User? user) {
    final email = user?.email?.trim().toLowerCase();
    return email != null && adminEmails.contains(email);
  }

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
        return;
      }

      await _firebaseAuth.signInWithProvider(GoogleAuthProvider());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.code == 'user-canceled' ||
          error.code == 'web-context-undefined') {
        return;
      }
      throw error;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
