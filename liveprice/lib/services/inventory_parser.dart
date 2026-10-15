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
    this.sourceCode = '',
  });

  final int rowNumber;
  final String name;
  final String unit;
  final num qty;
  final String key;
  final String sourceCode;
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
      csv = _decodeWindows1256(bytes);
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
    var codeColumn = -1;

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
      codeColumn = cells.indexWhere(_isCodeHeader);
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
      final sourceCode = codeColumn < 0 ? '' : _cellAt(cells, codeColumn).trim();
      final rawQuantity = _cellAt(cells, qtyColumn);
      if (name.isEmpty && unit.isEmpty && sourceCode.isEmpty && rawQuantity.trim().isEmpty) continue;
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
      final duplicateKey = sourceCode.isEmpty ? key : 'code:$sourceCode';
      if (!seenKeys.add(duplicateKey)) {
        issues.add(InventoryIssue(rowNumber: rowNumber, type: 'duplicate', message: 'صنف مكرر، تم الاحتفاظ بأول ظهور'));
        continue;
      }
      parsedRows.add(
        InventoryRow(rowNumber: rowNumber, name: name, unit: unit, qty: quantity, key: key, sourceCode: sourceCode),
      );
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

  static String _decodeWindows1256(Uint8List bytes) {
    const codePoints = [
      0x20AC,
      0x067E,
      0x201A,
      0x0192,
      0x201E,
      0x2026,
      0x2020,
      0x2021,
      0x02C6,
      0x2030,
      0x0679,
      0x2039,
      0x0152,
      0x0686,
      0x0698,
      0x0688,
      0x06AF,
      0x2018,
      0x2019,
      0x201C,
      0x201D,
      0x2022,
      0x2013,
      0x2014,
      0x06A9,
      0x2122,
      0x0691,
      0x203A,
      0x0153,
      0x200C,
      0x200D,
      0x06BA,
      0x00A0,
      0x060C,
      0x00A2,
      0x00A3,
      0x00A4,
      0x00A5,
      0x00A6,
      0x00A7,
      0x00A8,
      0x00A9,
      0x06BE,
      0x00AB,
      0x00AC,
      0x00AD,
      0x00AE,
      0x00AF,
      0x00B0,
      0x00B1,
      0x00B2,
      0x00B3,
      0x00B4,
      0x00B5,
      0x00B6,
      0x00B7,
      0x00B8,
      0x00B9,
      0x061B,
      0x00BB,
      0x00BC,
      0x00BD,
      0x00BE,
      0x061F,
      0x06C1,
      0x0621,
      0x0622,
      0x0623,
      0x0624,
      0x0625,
      0x0626,
      0x0627,
      0x0628,
      0x0629,
      0x062A,
      0x062B,
      0x062C,
      0x062D,
      0x062E,
      0x062F,
      0x0630,
      0x0631,
      0x0632,
      0x0633,
      0x0634,
      0x0635,
      0x0636,
      0x00D7,
      0x0637,
      0x0638,
      0x0639,
      0x063A,
      0x0640,
      0x0641,
      0x0642,
      0x0643,
      0x00E0,
      0x0644,
      0x00E2,
      0x0645,
      0x0646,
      0x0647,
      0x0648,
      0x00E7,
      0x00E8,
      0x00E9,
      0x00EA,
      0x00EB,
      0x0649,
      0x064A,
      0x00EE,
      0x00EF,
      0x064B,
      0x064C,
      0x064D,
      0x064E,
      0x00F4,
      0x064F,
      0x0650,
      0x00F7,
      0x0651,
      0x00F9,
      0x0652,
      0x00FB,
      0x00FC,
      0x200E,
      0x200F,
      0x06D2,
    ];
    return String.fromCharCodes(bytes.map((byte) => byte < 0x80 ? byte : codePoints[byte - 0x80]));
  }

  static String _normalizeHeader(String value) => value
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _isCodeHeader(String value) {
    final header = _normalizeHeader(value).toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return const {
      'id',
      'code',
      'itemcode',
      'productcode',
      'sku',
      'barcode',
      'معرف',
      'المعرف',
      'رمز',
      'الرمز',
      'كود',
      'الكود',
      'رمزالصنف',
      'رمزالماده',
      'رقمالصنف',
      'رقمالماده',
      'باركود',
      'الباركود',
    }.contains(header);
  }

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
