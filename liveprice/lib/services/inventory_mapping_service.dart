import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/inventory_parser.dart';
import 'package:liveprice/services/staff_session.dart';

class InventoryMappingSaveResult {
  const InventoryMappingSaveResult({
    required this.mappedCount,
    required this.unmatchedCount,
    required this.skippedWithoutCode,
  });

  final int mappedCount;
  final int unmatchedCount;
  final int skippedWithoutCode;
}

class InventoryMappingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<InventoryMappingSaveResult> saveBranchMappings({
    required String branchId,
    required List<InventoryRow> rows,
    required Map<int, ProductModel> matches,
  }) async {
    if (branchId.trim().isEmpty) throw ArgumentError('معرّف الفرع غير موجود');

    final skippedWithoutCode = rows.where((row) => row.sourceCode.trim().isEmpty).length;
    if (rows.isEmpty) {
      return InventoryMappingSaveResult(mappedCount: 0, unmatchedCount: 0, skippedWithoutCode: skippedWithoutCode);
    }

    final reference = _db.collection('branch_maps').doc(branchId);
    final auditReference = _db.collection('audit_logs').doc();
    final session = StaffSession.instance;
    final user = session.user;
    final profile = session.profile;
    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? <String, dynamic>{};
      final mappings = _stringKeyedMap(data['m']);
      var mappedCount = 0;
      var unmatchedCount = 0;
      final mappingChanges = <Map<String, String>>[];

      for (final row in rows) {
        final code = row.sourceCode.trim().isEmpty ? row.key : row.sourceCode.trim();
        final product = matches[row.rowNumber];
        if (product != null) {
          mappings[code] = {'p': product.id, 'n': row.name, 'u': row.unit};
          mappedCount++;
          mappingChanges.add({'code': code, 'productId': product.id, 'name': row.name});
        } else {
          unmatchedCount++;
        }
      }

      if (mappedCount > 0) {
        transaction.set(reference, {'m': mappings}, SetOptions(merge: true));
        transaction.set(auditReference, {
          'type': 'inventory_mapping_update',
          'uid': user?.uid,
          'email': user?.email,
          'name': profile?.name ?? user?.displayName ?? '',
          'role': profile?.role ?? '',
          'branchId': branchId,
          'at': FieldValue.serverTimestamp(),
          'details': {
            'mappedCount': mappedCount,
            'unmatchedCount': unmatchedCount,
            'skippedWithoutCode': skippedWithoutCode,
            'mappings': mappingChanges,
          },
        });
      }

      return InventoryMappingSaveResult(
        mappedCount: mappedCount,
        unmatchedCount: unmatchedCount,
        skippedWithoutCode: skippedWithoutCode,
      );
    });
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
