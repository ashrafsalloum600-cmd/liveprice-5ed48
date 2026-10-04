import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liveprice/models/product_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'products';
  static const String _changes = 'price_changes';

  Stream<List<ProductModel>> getProductsStream() {
    return _db
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ProductModel.fromFirestore).toList());
  }

  Future<List<ProductModel>> getProducts() async {
    final snapshot = await _db.collection(_collection).get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs.map(ProductModel.fromFirestore).toList();
  }

  Future<void> uploadProductsBatch(List<Map<String, dynamic>> productsData) async {
    final existing = await _db.collection(_collection).get(const GetOptions(source: Source.server));
    final current = {for (final d in existing.docs) d.id: d.data()};

    WriteBatch batch = _db.batch();
    int ops = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    for (final data in productsData) {
      final id = data['id'] as String;
      final fields = Map<String, dynamic>.from(data)..remove('id');
      final old = current[id];

      final newPrice = (fields['price'] as num?)?.toDouble();
      final oldPrice = (old?['price'] as num?)?.toDouble();
      final oldCur = old?['currency'] as String? ?? 'SYP';
      final newCur = fields['currency'] as String? ?? oldCur;

      if (old != null) {
        final nameChanged = fields['name'] != null && fields['name'] != old['name'];
        if (oldPrice == newPrice && oldCur == newCur && !nameChanged) continue;
      }

      batch.set(_db.collection(_collection).doc(id), fields, SetOptions(merge: true));
      ops++;

      final priceChanged =
          old != null && oldPrice != null && newPrice != null && oldPrice != newPrice && oldCur == newCur;
      if (priceChanged) {
        batch.set(_db.collection(_changes).doc(), {
          'productId': id,
          'name': (fields['name'] ?? old['name'] ?? '') as String,
          'oldPrice': oldPrice,
          'newPrice': newPrice,
          'currency': newCur,
          'at': FieldValue.serverTimestamp(),
        });
        ops++;
      }

      if (ops >= 400) await flush();
    }
    await flush();
  }
}
