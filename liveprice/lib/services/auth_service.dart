import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  static const String branchesBaseEmail = 'liveprice.branches@gmail.com';

  Stream<User?> get authState => _firebaseAuth.authStateChanges();

  String branchEmail(String branchId) => branchesBaseEmail.replaceFirst('@', '+$branchId@');

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (error) {
      final message = switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'تعذر تسجيل الدخول. تحقق من تسجيل بريد هذا الفرع في Firebase ومن صحة كلمة المرور',
        'user-disabled' => 'هذا الحساب معطّل',
        'too-many-requests' => 'محاولات كثيرة، حاول لاحقاً',
        'network-request-failed' => 'تحقق من اتصال الإنترنت',
        _ => null,
      };
      if (message != null) throw Exception(message);
      rethrow;
    }
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
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
