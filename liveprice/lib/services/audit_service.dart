import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'staff_session.dart';

class AuditService {
  static Future<void> log(String type, {Map<String, dynamic>? details}) async {
    try {
      final session = StaffSession.instance;
      final user = session.user;
      final profile = session.profile;
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'type': type,
        'uid': user?.uid,
        'email': user?.email,
        'name': profile?.name ?? user?.displayName ?? '',
        'role': profile?.role ?? '',
        'branchId': profile?.branchId ?? '',
        'at': FieldValue.serverTimestamp(),
        'details': details,
      });
    } catch (error) {
      debugPrint('تعذر تسجيل الحركة: $error');
    }
  }
}
