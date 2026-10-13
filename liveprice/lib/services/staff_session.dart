import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/staff_profile.dart';

class StaffSession extends ChangeNotifier {
  StaffSession._();

  static final StaffSession instance = StaffSession._();

  User? user;
  StaffProfile? profile;
  bool loading = false;
  bool initialized = false;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;

  void start() {
    if (_authSubscription != null) return;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
      onError: (Object _) {
        user = null;
        profile = null;
        loading = false;
        initialized = true;
        notifyListeners();
      },
    );
  }

  Future<void> _handleAuthChange(User? currentUser) async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    user = currentUser;
    initialized = true;

    if (currentUser == null) {
      profile = null;
      loading = false;
      notifyListeners();
      return;
    }

    profile = null;
    loading = true;
    notifyListeners();

    _profileSubscription = FirebaseFirestore.instance
        .collection('staff')
        .doc(currentUser.uid)
        .snapshots()
        .listen(
          (document) {
            profile = document.exists ? StaffProfile.fromDoc(document) : null;
            loading = false;
            notifyListeners();
          },
          onError: (Object _) {
            profile = null;
            loading = false;
            notifyListeners();
          },
        );
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
