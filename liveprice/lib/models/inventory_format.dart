import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryFormat {
  const InventoryFormat({this.nameHeader = 'المادة', this.unitHeader = 'الواحدة', this.qtyHeader = 'الرصيد الحالي'});

  final String nameHeader;
  final String unitHeader;
  final String qtyHeader;

  static Future<InventoryFormat> load() async {
    const defaults = InventoryFormat();
    try {
      final snapshot = await FirebaseFirestore.instance.doc('settings/inventory_format').get();
      final data = snapshot.data();
      if (data == null) return defaults;
      return InventoryFormat(
        nameHeader: data['nameHeader'] is String ? data['nameHeader'] as String : defaults.nameHeader,
        unitHeader: data['unitHeader'] is String ? data['unitHeader'] as String : defaults.unitHeader,
        qtyHeader: data['qtyHeader'] is String ? data['qtyHeader'] as String : defaults.qtyHeader,
      );
    } catch (_) {
      return defaults;
    }
  }
}
