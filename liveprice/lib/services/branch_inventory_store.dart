import 'package:cloud_firestore/cloud_firestore.dart';

class LegacyInventoryMigrationResult {
  const LegacyInventoryMigrationResult({required this.migratedQuantities, required this.conflicts});

  final int migratedQuantities;
  final List<String> conflicts;
}

class BranchInventoryStore {
  BranchInventoryStore({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  static const branchIds = ['b1', 'b2', 'b3'];
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> itemsRef(String branchId) {
    return _db.collection('branch_inventory').doc(branchId).collection('items');
  }

  DocumentReference<Map<String, dynamic>> itemRef(String branchId, String productId) {
    return itemsRef(branchId).doc(productId);
  }

  // المصدر المعتمد: branch_stock/{b}.q فقط
  Future<Map<String, Map<String, num>>> loadAllQuantities() async {
    final snapshots = await Future.wait(
      branchIds.map((branchId) => _db.collection('branch_stock').doc(branchId).get()),
    );
    final result = <String, Map<String, num>>{};
    for (var index = 0; index < branchIds.length; index++) {
      final quantities = <String, num>{};
      final rawQuantities = snapshots[index].data()?['q'];
      if (rawQuantities is Map) {
        for (final entry in rawQuantities.entries) {
          final quantity = entry.value;
          if (entry.key is String && quantity is num && quantity.isFinite) {
            quantities[entry.key as String] = quantity;
          }
        }
      }
      result[branchIds[index]] = quantities;
    }
    return result;
  }

  // غير مستخدمة: inventory_public ممنوعة بالقواعد
  Future<Map<String, String>> loadPublicStatuses() async {
    return <String, String>{};
  }

  // لا تستخدمها: تكتب بمجموعات ممنوعة بالقواعد
  Future<LegacyInventoryMigrationResult> migrateLegacyProductQuantities() async {
    throw StateError('الترحيل معطّل: التخزين المعتمد هو branch_stock');
  }

  // الحالة تُحسب من الفروع المرفوعة فقط
  static String publicStatus(Map<String, num> quantitiesByBranch) {
    final uploaded = branchIds.where(quantitiesByBranch.containsKey).toList();
    if (uploaded.isEmpty) return 'incomplete';
    final total = uploaded.fold<num>(0, (sum, branchId) => sum + quantitiesByBranch[branchId]!);
    if (total <= 0) return 'out';
    if (total <= 5) return 'limited';
    return 'available';
  }

  static String publicStatusFor(Map<String, num?> quantitiesByBranch) {
    return publicStatus({
      for (final branchId in branchIds)
        if (quantitiesByBranch[branchId] != null) branchId: quantitiesByBranch[branchId]!,
    });
  }
}
