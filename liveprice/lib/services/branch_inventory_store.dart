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

  CollectionReference<Map<String, dynamic>> itemsRef(String branchId) {
    return _db.collection('branch_inventory').doc(branchId).collection('items');
  }

  DocumentReference<Map<String, dynamic>> itemRef(String branchId, String productId) {
    return itemsRef(branchId).doc(productId);
  }

  Future<Map<String, Map<String, num>>> loadAllQuantities() async {
    final fromItems = await _loadFromItems();
    final fromLegacy = await _loadFromLegacyStockDocs();
    return {
      for (final branchId in branchIds) branchId: {...?fromLegacy[branchId], ...?fromItems[branchId]},
    };
  }

  Future<Map<String, Map<String, num>>> _loadFromItems() async {
    final snapshots = await Future.wait(branchIds.map((branchId) => itemsRef(branchId).get()));
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

  Future<Map<String, Map<String, num>>> _loadFromLegacyStockDocs() async {
    try {
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
    } catch (_) {
      return {for (final branchId in branchIds) branchId: <String, num>{}};
    }
  }

  Future<Map<String, String>> loadPublicStatuses() async {
    final snapshot = await _db.collection('inventory_public').get(const GetOptions(source: Source.serverAndCache));
    final statuses = <String, String>{};
    for (final document in snapshot.docs) {
      final status = document.data()['status'];
      if (status is String && status.isNotEmpty) statuses[document.id] = status;
    }
    return statuses;
  }

  Future<LegacyInventoryMigrationResult> migrateLegacyProductQuantities() async {
    if (StaffSession.instance.profile?.isOwner != true || StaffSession.instance.profile?.active != true) {
      throw StateError('ترحيل الكميات القديمة متاح للمالك النشط فقط');
    }

    final productSnapshot = await _db.collection('products').get(const GetOptions(source: Source.server));
    final current = await loadAllQuantities();

    final conflicts = <String>[];
    var migratedQuantities = 0;
    var batch = _db.batch();
    var batchOperations = 0;
    var batchMigratedCount = 0;
    var batchProductCount = 0;
    final publicStatuses = <String, String>{};

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

      for (final branchId in branchIds) {
        final quantityField = 'q_$branchId';
        final timeField = '${quantityField}_at';
        final legacyQuantity = productData[quantityField];
        final existingQuantity = current[branchId]![productDocument.id];
        var effectiveQuantity = existingQuantity;

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
            if (batchOperations + 8 > 440) await commitBatch();
            batch.set(itemRef(branchId, productDocument.id), {
              'quantity': legacyQuantity,
              'updatedAt': legacyTime is Timestamp ? legacyTime : FieldValue.serverTimestamp(),
            });
            batchOperations++;
            current[branchId]![productDocument.id] = legacyQuantity;
            effectiveQuantity = legacyQuantity;
            migratedQuantities++;
            batchMigratedCount++;
          }
          deletes[quantityField] = FieldValue.delete();
          if (productData.containsKey(timeField)) deletes[timeField] = FieldValue.delete();
        }
        postMigrationQuantities[branchId] = effectiveQuantity;
      }

      if (deletes.isNotEmpty) {
        if (batchOperations + 8 > 440) await commitBatch();
        batch.update(productDocument.reference, deletes);
        batchOperations++;
      }

      publicStatuses[productDocument.id] = publicStatusFor(postMigrationQuantities);
      batchProductCount++;
    }

    await commitBatch();

    for (final entry in publicStatuses.entries) {
      if (batchOperations >= 400) await commitBatch();
      batch.set(_db.collection('inventory_public').doc(entry.key), {
        'status': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batchOperations++;
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
