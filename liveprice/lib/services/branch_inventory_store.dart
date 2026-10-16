import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liveprice/services/staff_session.dart';

class LegacyInventoryMigrationResult {
  const LegacyInventoryMigrationResult({required this.migratedQuantities, required this.conflicts});

  final int migratedQuantities;
  final List<String> conflicts;
}

class BranchInventoryStore {
  BranchInventoryStore({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  static const branchIds = ['b1', 'b2', 'b3'];
  final FirebaseFirestore _db;

  Future<Map<String, Map<String, num>>> loadAllQuantities() async {
    final snapshots = await Future.wait(
      branchIds.map((branchId) => _db.collection('branch_stock').doc(branchId).get()),
    );
    final result = <String, Map<String, num>>{};
    for (var index = 0; index < branchIds.length; index++) {
      final quantities = <String, num>{};
      final data = snapshots[index].data() ?? <String, dynamic>{};
      final rawQuantities = data['q'];
      if (rawQuantities is Map) {
        for (final entry in rawQuantities.entries) {
          final quantity = entry.value;
          if (entry.key is String && quantity is num && quantity.isFinite) quantities[entry.key as String] = quantity;
        }
      }
      result[branchIds[index]] = quantities;
    }
    return result;
  }

  Future<LegacyInventoryMigrationResult> migrateLegacyProductQuantities() async {
    if (StaffSession.instance.profile?.isOwner != true || StaffSession.instance.profile?.active != true) {
      throw StateError('ترحيل الكميات القديمة متاح للمالك النشط فقط');
    }

    final productSnapshot = await _db.collection('products').get(const GetOptions(source: Source.server));
    final branchSnapshots = await Future.wait(
      branchIds.map((branchId) => _db.collection('branch_stock').doc(branchId).get()),
    );
    final current = <String, Map<String, Map<String, dynamic>>>{};
    for (var index = 0; index < branchIds.length; index++) {
      final data = branchSnapshots[index].data() ?? <String, dynamic>{};
      final quantities = data['q'];
      current[branchIds[index]] = {
        if (quantities is Map)
          for (final entry in quantities.entries)
            if (entry.key is String) entry.key as String: {'quantity': entry.value},
      };
    }

    final conflicts = <String>[];
    var migratedQuantities = 0;
    var batch = _db.batch();
    var batchOperations = 0;
    var batchMigratedCount = 0;
    var batchProductCount = 0;

    Future<void> commitBatch() async {
      if (batchOperations == 0) return;
      batch.set(_db.collection('audit_logs').doc(), {
        'type': 'inventory_storage_migration',
        'uid': StaffSession.instance.user?.uid,
        'email': StaffSession.instance.user?.email,
        'name': StaffSession.instance.profile?.name ?? StaffSession.instance.user?.displayName ?? '',
        'role': 'owner',
        'branchId': '',
        'at': FieldValue.serverTimestamp(),
        'details': {'migratedQuantities': batchMigratedCount, 'products': batchProductCount},
      });
      await batch.commit();
      batch = _db.batch();
      batchOperations = 0;
      batchMigratedCount = 0;
      batchProductCount = 0;
    }

    for (final productDocument in productSnapshot.docs) {
      final productData = productDocument.data();
      final deletes = <String, Object>{};
      final postMigrationQuantities = <String, num?>{};
      final productWrites = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>>[];

      for (final branchId in branchIds) {
        final quantityField = 'q_$branchId';
        final timeField = '${quantityField}_at';
        final legacyQuantity = productData[quantityField];
        final existing = current[branchId]![productDocument.id];
        final existingQuantity = existing?['quantity'];
        var effectiveQuantity = existingQuantity is num ? existingQuantity : null;

        if (legacyQuantity != null) {
          if (legacyQuantity is! num || !legacyQuantity.isFinite) {
            conflicts.add('${productDocument.id}:$quantityField غير رقمي');
            continue;
          }
          if (effectiveQuantity != null && effectiveQuantity != legacyQuantity) {
            conflicts.add('${productDocument.id}:$branchId قيمة قديمة تختلف عن المخزن الجديد');
            continue;
          }
          if (effectiveQuantity == null) {
            final legacyTime = productData[timeField];
            final unit = productData['unit'];
            final stockData = <String, dynamic>{
              'q': {productDocument.id: legacyQuantity},
              'u': {productDocument.id: unit is String ? unit : ''},
              'updatedAt': legacyTime is Timestamp ? legacyTime : FieldValue.serverTimestamp(),
            };
            productWrites.add(MapEntry(_db.collection('branch_stock').doc(branchId), stockData));
            effectiveQuantity = legacyQuantity;
            migratedQuantities++;
          }
          deletes[quantityField] = FieldValue.delete();
          if (productData.containsKey(timeField)) deletes[timeField] = FieldValue.delete();
        }
        postMigrationQuantities[branchId] = effectiveQuantity;
      }

      if (batchOperations + productWrites.length + 8 > 440) await commitBatch();
      for (final write in productWrites) {
        batch.set(write.key, write.value, SetOptions(merge: true));
        batchOperations++;
      }
      if (deletes.isNotEmpty) {
        batch.update(productDocument.reference, deletes);
        batchOperations++;
      }

      batchMigratedCount += productWrites.length;
      batchProductCount++;
    }

    await commitBatch();
    return LegacyInventoryMigrationResult(migratedQuantities: migratedQuantities, conflicts: conflicts);
  }

  static String publicStatus(Map<String, num> quantitiesByBranch) {
    if (!branchIds.every(quantitiesByBranch.containsKey)) return 'incomplete';
    final total = branchIds.fold<num>(0, (sum, branchId) => sum + quantitiesByBranch[branchId]!);
    if (total <= 0) return 'out';
    if (total <= 5) return 'limited';
    return 'available';
  }

  static String publicStatusFor(Map<String, num?> quantitiesByBranch) {
    if (!branchIds.every((branchId) => quantitiesByBranch[branchId] != null)) return 'incomplete';
    return publicStatus({for (final branchId in branchIds) branchId: quantitiesByBranch[branchId]!});
  }
}
