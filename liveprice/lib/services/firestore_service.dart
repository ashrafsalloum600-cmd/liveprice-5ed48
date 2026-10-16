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

  Future<List<ProductModel>> getPublicProducts() async {
    final snapshot = await _db.collection('products_public').get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs.map(ProductModel.fromFirestore).toList();
  }

  Future<int> publishCatalog() async {
    final snapshot = await _db.collection(_collection).get(const GetOptions(source: Source.server));
    WriteBatch batch = _db.batch();
    var ops = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    for (final document in snapshot.docs) {
      final data = document.data();
      batch.set(_db.collection('products_public').doc(document.id), {
        'name': data['name'] ?? '',
        'price': data['price'] is num ? data['price'] : 0,
        'currency': data['currency'] ?? 'SYP',
        'unit': data['unit'] ?? '',
        'category': data['category'] ?? '',
        'imageUrl': data['imageUrl'] ?? '',
      }, SetOptions(merge: true));
      ops++;
      if (ops == 400) await flush();
    }
    await flush();
    return snapshot.docs.length;
  }

  Future<void> uploadProductsBatch(List<Map<String, dynamic>> productsData) async {
    final existing = await _db.collection(_collection).get(const GetOptions(source: Source.server));
    final current = {for (final d in existing.docs) d.id: d.data()};

    WriteBatch batch = _db.batch();
    int ops = 0;
    int changed = 0;

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

      if (old == null) {
        fields.putIfAbsent('name', () => '');
        fields.putIfAbsent('price', () => 0.0);
        fields.putIfAbsent('currency', () => 'SYP');
        fields.putIfAbsent('unit', () => '');
        fields.putIfAbsent('category', () => '');
        fields.putIfAbsent('imageUrl', () => '');
      }

      final newPrice = (fields['price'] as num?)?.toDouble();
      final oldPrice = (old?['price'] as num?)?.toDouble();
      final oldCur = old?['currency'] as String? ?? 'SYP';
      final newCur = fields['currency'] as String? ?? oldCur;

      if (old != null) {
        final nameChanged = fields['name'] != null && fields['name'] != old['name'];
        final catalogFieldsChanged = [
          'unit',
          'category',
          'imageUrl',
        ].any((field) => fields.containsKey(field) && fields[field] != old[field]);
        if (oldPrice == newPrice && oldCur == newCur && !nameChanged && !catalogFieldsChanged) continue;
      }

      batch.set(_db.collection(_collection).doc(id), fields, SetOptions(merge: true));
      ops++;
      changed++;

      final publicFields = <String, dynamic>{
        for (final field in ['name', 'price', 'currency', 'unit', 'category', 'imageUrl'])
          if (fields.containsKey(field))
            field: fields[field]
          else if (old != null && old.containsKey(field))
            field: old[field],
      };
      if (old == null) {
        batch.set(_db.collection('products_public').doc(id), publicFields);
        ops++;
      } else if (publicFields.isNotEmpty) {
        batch.set(_db.collection('products_public').doc(id), publicFields, SetOptions(merge: true));
        ops++;
      }

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
    if (changed > 0) {
      await _db.doc('settings/pricing').set({'pricesUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
  }
}
