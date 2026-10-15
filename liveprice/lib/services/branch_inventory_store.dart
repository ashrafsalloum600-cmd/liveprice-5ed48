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

  CollectionReference<Map<String, dynamic>> _branchItems(String branchId) =>
      _db.collection('branch_inventory').doc(branchId).collection('items');

  Future<Map<String, Map<String, num>>> loadAllQuantities() async {
    final snapshots = await Future.wait(branchIds.map((branchId) => _branchItems(branchId).get()));
    final result = <String, Map<String, num>>{};
    for (var index = 0; index < branchIds.length; index++) {
      final quantities = <String, num>{};
      for (final document in snapshots[index].docs) {
        final quantity = document.data()['quantity'];
        if (quantity is num && quantity.isFinite) quantities[document.id] = quantity;
      }
      result[branchIds[index]] = quantities;
    }
    return result;
  }

  Future<Map<String, String>> loadPublicStatuses() async {
    final snapshot = await _db.collection('inventory_public').get();
    final result = <String, String>{};
    for (final document in snapshot.docs) {
      final status = document.data()['status'];
      if (status is String && const {'incomplete', 'out', 'limited', 'available'}.contains(status)) {
        result[document.id] = status;
      }
    }
    return result;
  }

  Future<LegacyInventoryMigrationResult> migrateLegacyProductQuantities() async {
    if (StaffSession.instance.profile?.isOwner != true || StaffSession.instance.profile?.active != true) {
      throw StateError('ترحيل الكميات القديمة متاح للمالك النشط فقط');
    }

    final productSnapshot = await _db.collection('products').get(const GetOptions(source: Source.server));
    final branchSnapshots = await Future.wait(branchIds.map((branchId) => _branchItems(branchId).get()));
    final current = <String, Map<String, Map<String, dynamic>>>{};
    for (var index = 0; index < branchIds.length; index++) {
      current[branchIds[index]] = {for (final document in branchSnapshots[index].docs) document.id: document.data()};
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
            final stockData = <String, dynamic>{
              'quantity': legacyQuantity,
              'updatedAt': legacyTime is Timestamp ? legacyTime : FieldValue.serverTimestamp(),
            };
            productWrites.add(MapEntry(_branchItems(branchId).doc(productDocument.id), stockData));
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

      final publicFields = <String, dynamic>{
        for (final field in ['name', 'price', 'currency', 'unit', 'category', 'imageUrl'])
          field:
              productData[field] ??
              switch (field) {
                'name' || 'unit' || 'category' || 'imageUrl' => '',
                'price' => 0,
                'currency' => 'SYP',
                _ => null,
              },
      };
      batch.set(_db.collection('products_public').doc(productDocument.id), publicFields);
      batchOperations++;

      final hasConflictForProduct = conflicts.any((conflict) => conflict.startsWith('${productDocument.id}:'));
      final status = hasConflictForProduct ? 'incomplete' : publicStatusFor(postMigrationQuantities);
      batch.set(_db.collection('inventory_public').doc(productDocument.id), {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batchOperations++;
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
