import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liveprice/models/product_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'products';

  Stream<List<ProductModel>> getProductsStream() {
    return _db
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList());
  }

  Future<void> uploadProductsBatch(List<Map<String, dynamic>> productsData) async {
    final WriteBatch batch = _db.batch();

    for (final data in productsData) {
      final String id = data['id'] as String;
      final Map<String, dynamic> fields = Map<String, dynamic>.from(data)..remove('id');
      final docRef = _db.collection(_collection).doc(id);
      batch.set(docRef, fields, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
