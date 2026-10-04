import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
        return;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' || error.code == 'cancelled-popup-request') return;
      throw AuthServiceException(_authErrorMessage(error.code));
    } catch (_) {
      throw const AuthServiceException('تعذر تسجيل الدخول باستخدام Google');
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      if (!kIsWeb) await _googleSignIn.signOut();
    } catch (_) {
      throw const AuthServiceException('تعذر تسجيل الخروج');
    }
  }

  String _authErrorMessage(String code) {
    return switch (code) {
      'network-request-failed' => 'تحقق من اتصال الإنترنت',
      'account-exists-with-different-credential' => 'الحساب مرتبط بطريقة دخول أخرى',
      _ => 'تعذر تسجيل الدخول باستخدام Google',
    };
  }
}

class AuthServiceException implements Exception {
  final String message;

  const AuthServiceException(this.message);
}
