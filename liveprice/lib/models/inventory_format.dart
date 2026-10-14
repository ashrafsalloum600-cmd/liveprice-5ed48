import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryFormat {
  const InventoryFormat({
    this.sheetName = 'جرد',
    this.headerRows = 1,
    this.nameCol = 'B',
    this.unitCol = 'C',
    this.qtyCol = 'D',
  });

  final String sheetName;
  final int headerRows;
  final String nameCol;
  final String unitCol;
  final String qtyCol;

  static Future<InventoryFormat> load() async {
    const defaults = InventoryFormat();
    try {
      final snapshot = await FirebaseFirestore.instance.doc('settings/inventory_format').get();
      final data = snapshot.data();
      if (data == null) return defaults;
      return InventoryFormat(
        sheetName: data['sheet'] is String ? data['sheet'] as String : defaults.sheetName,
        headerRows: data['headerRows'] is num ? (data['headerRows'] as num).toInt() : defaults.headerRows,
        nameCol: data['nameCol'] is String ? data['nameCol'] as String : defaults.nameCol,
        unitCol: data['unitCol'] is String ? data['unitCol'] as String : defaults.unitCol,
        qtyCol: data['qtyCol'] is String ? data['qtyCol'] as String : defaults.qtyCol,
      );
    } catch (_) {
      return defaults;
    }
  }
}
