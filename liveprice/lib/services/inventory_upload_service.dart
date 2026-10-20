import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/inventory_parser.dart';
import 'package:liveprice/services/branch_inventory_store.dart';
import 'package:liveprice/services/staff_session.dart';

class InventoryUploadItem {
  const InventoryUploadItem({
    required this.productId,
    required this.productName,
    required this.previousQuantity,
    required this.newQuantity,
    required this.rowCount,
    required this.publicStatus,
    required this.previousPublicStatus,
    required this.unit,
  });

  final String productId;
  final String productName;
  final num? previousQuantity;
  final num newQuantity;
  final int rowCount;
  final String publicStatus;
  final String previousPublicStatus;
  final String unit;
}

class InventoryUploadPreview {
  const InventoryUploadPreview({
    required this.branchId,
    required this.items,
    required this.unchangedCount,
    required this.unmappedCount,
    required this.missingProductCount,
    required this.invalidMappingCount,
  });

  final String branchId;
  final List<InventoryUploadItem> items;
  final int unchangedCount;
  final int unmappedCount;
  final int missingProductCount;
  final int invalidMappingCount;
}

class InventoryUploadService {
  InventoryUploadService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<InventoryUploadPreview> preview({
    required String branchId,
    required List<InventoryRow> rows,
    required List<ProductModel> existingProducts,
  }) async {
    _quantityField(branchId);
    final store = BranchInventoryStore(firestore: _db);
    final mapFuture = _db.collection('branch_maps').doc(branchId).get();
    final quantitiesFuture = store.loadAllQuantities();
    final mapSnapshot = await mapFuture;
    final mapData = mapSnapshot.data() ?? <String, dynamic>{};
    final mappings = _stringKeyedMap(mapData['m']);
    final quantitiesByBranch = await quantitiesFuture;
    final productsById = {for (final product in existingProducts) product.id: product};
    final totals = <String, num>{};
    final sourceRowsByProduct = <String, int>{};
    final unitsByProduct = <String, String>{};
    var unmappedCount = 0;
    var missingProductCount = 0;
    var invalidMappingCount = 0;

    for (final row in rows) {
      final code = row.sourceCode.trim().isEmpty ? row.key : row.sourceCode.trim();
      final rawMapping = mappings[code];
      if (rawMapping is! Map) {
        unmappedCount++;
        continue;
      }
      final productId = rawMapping['p'];
      if (productId is! String || productId.isEmpty) {
        invalidMappingCount++;
        continue;
      }
      final product = productsById[productId];
      if (product == null) {
        missingProductCount++;
        continue;
      }
      final quantity = row.qty;
      if (!quantity.isFinite) {
        invalidMappingCount++;
        continue;
      }
      totals.update(productId, (total) => total + quantity, ifAbsent: () => quantity);
      sourceRowsByProduct.update(productId, (count) => count + 1, ifAbsent: () => 1);
      final mappedUnit = rawMapping['u'];
      unitsByProduct.putIfAbsent(productId, () => mappedUnit is String ? mappedUnit : product.unit);
    }

    var unchangedCount = 0;
    final items = <InventoryUploadItem>[];
    for (final entry in totals.entries) {
      final product = productsById[entry.key]!;
      final previousQuantity = quantitiesByBranch[branchId]?[product.id];
      if (previousQuantity != null && previousQuantity == entry.value) {
        unchangedCount++;
        continue;
      }
      final projectedQuantities = <String, num>{
        for (final id in BranchInventoryStore.branchIds)
          if (quantitiesByBranch[id]!.containsKey(product.id)) id: quantitiesByBranch[id]![product.id]!,
      };
      final previousStatus = BranchInventoryStore.publicStatusFor({
        for (final id in BranchInventoryStore.branchIds) id: quantitiesByBranch[id]![product.id],
      });
      projectedQuantities[branchId] = entry.value;
      items.add(
        InventoryUploadItem(
          productId: product.id,
          productName: product.name,
          previousQuantity: previousQuantity,
          newQuantity: entry.value,
          rowCount: sourceRowsByProduct[entry.key]!,
          publicStatus: BranchInventoryStore.publicStatus(projectedQuantities),
          previousPublicStatus: previousStatus,
          unit: unitsByProduct[entry.key] ?? product.unit,
        ),
      );
    }
    items.sort((left, right) => left.productName.compareTo(right.productName));
    return InventoryUploadPreview(
      branchId: branchId,
      items: items,
      unchangedCount: unchangedCount,
      unmappedCount: unmappedCount,
      missingProductCount: missingProductCount,
      invalidMappingCount: invalidMappingCount,
    );
  }

  Future<int> apply(InventoryUploadPreview preview) async {
    if (preview.items.isEmpty) return 0;
    final session = StaffSession.instance;
    final user = session.user;
    final profile = session.profile;
    final auditChanges = preview.items
        .map((item) => {'productId': item.productId, 'oldQty': item.previousQuantity, 'newQty': item.newQuantity})
        .toList(growable: false);
    final store = BranchInventoryStore(firestore: _db);
    var batch = _db.batch();
    var ops = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    batch.set(_db.collection('inventory_meta').doc(preview.branchId), {
      'lastUploadAt': FieldValue.serverTimestamp(),
      'by': user?.uid,
      'rows': preview.items.length,
    }, SetOptions(merge: true));
    batch.set(_db.collection('audit_logs').doc(), {
      'type': 'inventory_upload',
      'uid': user?.uid,
      'email': user?.email,
      'name': profile?.name ?? user?.displayName ?? '',
      'role': profile?.role ?? '',
      'branchId': preview.branchId,
      'at': FieldValue.serverTimestamp(),
      'details': {
        'updatedProducts': preview.items.length,
        'unchangedProducts': preview.unchangedCount,
        'unmappedRows': preview.unmappedCount,
        'missingProducts': preview.missingProductCount,
        'invalidMappings': preview.invalidMappingCount,
        'changes': auditChanges,
      },
    });
    ops += 2;

    for (final item in preview.items) {
      if (ops + 2 > 400) await flush();
      batch.set(store.itemRef(preview.branchId, item.productId), {
        'quantity': item.newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_db.collection('inventory_public').doc(item.productId), {
        'status': item.publicStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ops += 2;
    }
    await flush();
    return preview.items.length;
  }

  void _quantityField(String branchId) {
    if (!const {'b1', 'b2', 'b3'}.contains(branchId)) {
      throw ArgumentError.value(branchId, 'branchId', 'معرّف الفرع غير معروف');
    }
  }

  Map<String, dynamic> _stringKeyedMap(Object? value) {
    final result = <String, dynamic>{};
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is String) result[entry.key as String] = entry.value;
      }
    }
    return result;
  }
}
