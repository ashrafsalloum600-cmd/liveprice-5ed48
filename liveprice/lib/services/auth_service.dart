import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  static const Map<String, String> _branchEmails = {
    'b1': 'liveprice.branches+b1@gmail.com',
    'b2': 'liveprice.branches+b2@gmail.com',
    'b3': 'liveprice.branches+b3@gmail.com',
  };

  Stream<User?> get authState => _firebaseAuth.authStateChanges();

  static String branchEmail(String branchId) {
    final email = _branchEmails[branchId];
    if (email == null) {
      throw ArgumentError.value(branchId, 'branchId', 'معرّف الفرع غير معروف');
    }
    return email;
  }

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
