import 'package:cloud_firestore/cloud_firestore.dart';

class DangerZone {
  static Future<int> wipeCatalogData() async {
    final db = FirebaseFirestore.instance;
    int total = 0;
    WriteBatch batch = db.batch();
    int ops = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      total += ops;
      batch = db.batch();
      ops = 0;
    }

    Future<void> queue(DocumentReference ref) async {
      batch.delete(ref);
      ops++;
      if (ops >= 400) await flush();
    }

    final products = await db.collection('products').get(const GetOptions(source: Source.server));
    for (final d in products.docs) {
      await queue(d.reference);
      await queue(db.collection('products_public').doc(d.id));
    }

    for (final name in ['price_changes', 'branch_maps', 'branch_stock', 'inventory_meta']) {
      final snap = await db.collection(name).get(const GetOptions(source: Source.server));
      for (final d in snap.docs) {
        await queue(d.reference);
      }
    }

    await flush();
    return total;
  }
}
