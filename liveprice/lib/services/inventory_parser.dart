import 'dart:typed_data';

import 'package:liveprice/models/inventory_format.dart';
import 'package:liveprice/services/xlsx_reader.dart';

String normalizeName(String value) {
  var normalized = value
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  for (var index = 0; index < 10; index++) {
    normalized = normalized.replaceAll(arabicDigits[index], '$index').replaceAll(persianDigits[index], '$index');
  }
  return normalized.toLowerCase().replaceAll(RegExp(r'\s*\*\s*'), '*').replaceAll(RegExp(r'\s+'), ' ').trim();
}

class InventoryRow {
  const InventoryRow({
    required this.rowNumber,
    required this.name,
    required this.unit,
    required this.qty,
    required this.key,
  });

  final int rowNumber;
  final String name;
  final String unit;
  final num qty;
  final String key;
}

class InventoryIssue {
  const InventoryIssue({required this.rowNumber, required this.type, required this.message});

  final int rowNumber;
  final String type;
  final String message;
}

class InventoryParseResult {
  const InventoryParseResult({required this.rows, required this.issues});

  final List<InventoryRow> rows;
  final List<InventoryIssue> issues;

  static InventoryParseResult parse(Uint8List bytes, InventoryFormat format) {
    final sheet = XlsxReader.readSheet(bytes, format.sheetName);
    final rows = <InventoryRow>[];
    final issues = <InventoryIssue>[];
    final seen = <String>{};
    final sortedNumbers = sheet.keys.toList()..sort();
    for (final rowNumber in sortedNumbers) {
      if (rowNumber <= format.headerRows) continue;
      final cells = sheet[rowNumber]!;
      if (cells.values.every((value) => value.trim().isEmpty)) continue;
      final name = (cells[format.nameCol.toUpperCase()] ?? '').trim();
      final unit = (cells[format.unitCol.toUpperCase()] ?? '').trim();
      if (name.isEmpty) {
        issues.add(InventoryIssue(rowNumber: rowNumber, type: 'name', message: 'لا يوجد اسم للصنف'));
        continue;
      }
      final rawQuantity = cells[format.qtyCol.toUpperCase()] ?? '';
      final quantityText = _normalizeDigits(rawQuantity).replaceAll(RegExp(r'[,\s]'), '');
      final quantity = num.tryParse(quantityText);
      if (quantity == null) {
        issues.add(InventoryIssue(rowNumber: rowNumber, type: 'qty', message: 'الكمية ليست رقماً صالحاً'));
        continue;
      }
      final key = '${normalizeName(name)}|$unit';
      if (!seen.add(key)) {
        issues.add(InventoryIssue(rowNumber: rowNumber, type: 'duplicate', message: 'صنف مكرر، تم الاحتفاظ بأول ظهور'));
        continue;
      }
      rows.add(InventoryRow(rowNumber: rowNumber, name: name, unit: unit, qty: quantity, key: key));
    }
    return InventoryParseResult(rows: rows, issues: issues);
  }

  static String _normalizeDigits(String value) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var index = 0; index < 10; index++) {
      result = result.replaceAll(arabicDigits[index], '$index').replaceAll(persianDigits[index], '$index');
    }
    return result;
  }
}
