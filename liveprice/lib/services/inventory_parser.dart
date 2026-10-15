import 'dart:convert';
import 'dart:typed_data';

import 'package:liveprice/models/inventory_format.dart';

String normalizeName(String value) {
  var normalized = value
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  for (var digit = 0; digit < 10; digit++) {
    normalized = normalized.replaceAll(arabicDigits[digit], '$digit').replaceAll(persianDigits[digit], '$digit');
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

  static InventoryParseResult parse(Uint8List bytes, InventoryFormat f) {
    String csv;
    try {
      csv = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw Exception('احفظ الملف بصيغة CSV UTF-8');
    }
    if (csv.startsWith('\uFEFF')) csv = csv.substring(1);

    final delimiter = _detectDelimiter(csv);
    final sourceRows = _parseCsv(csv, delimiter);
    final headerName = _normalizeHeader(f.nameHeader);
    final headerQty = _normalizeHeader(f.qtyHeader);
    final headerUnit = _normalizeHeader(f.unitHeader);
    var headerIndex = -1;
    var nameColumn = -1;
    var qtyColumn = -1;
    var unitColumn = -1;

    for (var rowIndex = 0; rowIndex < sourceRows.length && rowIndex < 10; rowIndex++) {
      final cells = sourceRows[rowIndex];
      final foundName = cells.indexWhere((cell) => _normalizeHeader(cell).contains(headerName));
      final foundQty = cells.indexWhere((cell) => _normalizeHeader(cell).contains(headerQty));
      if (foundName < 0 || foundQty < 0) continue;
      headerIndex = rowIndex;
      nameColumn = foundName;
      qtyColumn = foundQty;
      unitColumn = cells.indexWhere((cell) {
        final normalized = _normalizeHeader(cell);
        return normalized.contains(headerUnit) || normalized.contains('الواحده') || normalized.contains('الوحده');
      });
      break;
    }
    if (headerIndex < 0) throw Exception('لم أجد أعمدة المادة والرصيد الحالي');

    final parsedRows = <InventoryRow>[];
    final issues = <InventoryIssue>[];
    final seenKeys = <String>{};
    for (var rowIndex = headerIndex + 1; rowIndex < sourceRows.length; rowIndex++) {
      final cells = sourceRows[rowIndex];
      final name = _cellAt(cells, nameColumn).trim();
      final unit = unitColumn < 0 ? '' : _cellAt(cells, unitColumn).trim();
      final rawQuantity = _cellAt(cells, qtyColumn);
      if (name.isEmpty && unit.isEmpty && rawQuantity.trim().isEmpty) continue;
      final rowNumber = rowIndex + 1;
      if (name.isEmpty) {
        issues.add(InventoryIssue(rowNumber: rowNumber, type: 'name', message: 'لا يوجد اسم للصنف'));
        continue;
      }

      final quantityText = _normalizeQuantity(rawQuantity);
      final quantity = num.tryParse(quantityText);
      if (quantity == null) {
        issues.add(InventoryIssue(rowNumber: rowNumber, type: 'qty', message: 'الكمية ليست رقماً صالحاً'));
        continue;
      }

      final key = '${normalizeName(name)}|$unit';
      if (!seenKeys.add(key)) {
        issues.add(InventoryIssue(rowNumber: rowNumber, type: 'duplicate', message: 'صنف مكرر، تم الاحتفاظ بأول ظهور'));
        continue;
      }
      parsedRows.add(InventoryRow(rowNumber: rowNumber, name: name, unit: unit, qty: quantity, key: key));
    }
    return InventoryParseResult(rows: parsedRows, issues: issues);
  }

  static String _normalizeDigits(String value) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    var normalized = value;
    for (var digit = 0; digit < 10; digit++) {
      normalized = normalized.replaceAll(arabicDigits[digit], '$digit').replaceAll(persianDigits[digit], '$digit');
    }
    return normalized;
  }

  static String _normalizeHeader(String value) => value
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _normalizeQuantity(String value) {
    final normalized = _normalizeDigits(value).replaceAll(RegExp(r'\s+'), '');
    if (normalized.contains('.')) return normalized.replaceAll(',', '');
    final commaCount = ','.allMatches(normalized).length;
    if (commaCount == 1) {
      final decimalComma = RegExp(r',\d{1,2}$').hasMatch(normalized);
      if (decimalComma) return normalized.replaceFirst(',', '.');
    }
    return normalized.replaceAll(',', '');
  }

  static String _cellAt(List<String> cells, int column) => column < cells.length ? cells[column] : '';

  static String _detectDelimiter(String csv) {
    final counts = {',': 0, ';': 0, '\t': 0};
    var lines = 0;
    var quoted = false;
    for (var index = 0; index < csv.length && lines < 5; index++) {
      final character = csv[index];
      if (character == '"') {
        if (quoted && index + 1 < csv.length && csv[index + 1] == '"') {
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && counts.containsKey(character)) {
        counts[character] = counts[character]! + 1;
      } else if (!quoted && (character == '\n' || character == '\r')) {
        final start = csv.lastIndexOf('\n', index - 1) + 1;
        if (csv.substring(start, index).trim().isNotEmpty) lines++;
        if (character == '\r' && index + 1 < csv.length && csv[index + 1] == '\n') index++;
      }
    }
    final start = csv.lastIndexOf('\n') + 1;
    if (lines < 5 && csv.substring(start).trim().isNotEmpty) lines++;
    var selected = ',';
    for (final candidate in [';', '\t']) {
      if (counts[candidate]! > counts[selected]!) selected = candidate;
    }
    return selected;
  }

  static List<List<String>> _parseCsv(String csv, String delimiter) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < csv.length; index++) {
      final character = csv[index];
      if (character == '"') {
        if (quoted && index + 1 < csv.length && csv[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && character == delimiter) {
        row.add(field.toString());
        field.clear();
      } else if (!quoted && (character == '\n' || character == '\r')) {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
        if (character == '\r' && index + 1 < csv.length && csv[index + 1] == '\n') index++;
      } else {
        field.write(character);
      }
    }
    if (field.length > 0 || row.isNotEmpty || csv.isEmpty || !csv.endsWith('\n')) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
