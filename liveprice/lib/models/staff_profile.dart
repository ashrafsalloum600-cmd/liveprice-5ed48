import 'package:cloud_firestore/cloud_firestore.dart';

class StaffProfile {
  const StaffProfile({
    required this.uid,
    required this.role,
    required this.branchId,
    required this.name,
    required this.active,
  });

  final String uid;
  final String role;
  final String branchId;
  final String name;
  final bool active;

  factory StaffProfile.fromDoc(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>? ?? {};
    return StaffProfile(
      uid: document.id,
      role: data['role'] is String ? data['role'] as String : '',
      branchId: data['branchId'] is String ? data['branchId'] as String : '',
      name: data['name'] is String ? data['name'] as String : '',
      active: data['active'] is bool ? data['active'] as bool : false,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager';
  bool get isValid => active && (isOwner || (isManager && branchId.isNotEmpty));

  String? get invalidReason {
    if (isValid) return null;
    if (!active) return 'الحساب غير فعّال (تأكد أن active من نوع boolean)';
    if (!isOwner && !isManager) return 'الدور غير صحيح';
    if (isManager && branchId.isEmpty) return 'branchId فارغ';
    return null;
  }
}
