import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxReader {
  static Map<int, Map<String, String>> readSheet(Uint8List bytes, String sheetName) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw Exception('الملف ليس بصيغة xlsx، احفظه باسم xlsx');
    }

    final files = {for (final file in archive.files) file.name: file};
    String? readText(String path) {
      final content = files[path]?.content;
      if (content == null) return null;
      return utf8.decode(content as List<int>, allowMalformed: true);
    }

    final workbookText = readText('xl/workbook.xml');
    final relationshipsText = readText('xl/_rels/workbook.xml.rels');
    if (workbookText == null || relationshipsText == null) {
      throw Exception('الملف ليس بصيغة xlsx، احفظه باسم xlsx');
    }

    final workbook = XmlDocument.parse(workbookText);
    final relationships = XmlDocument.parse(relationshipsText);
    final targets = <String, String>{};
    for (final relationship in relationships.descendantElements.where(
      (element) => element.name.local == 'Relationship',
    )) {
      final id = relationship.getAttribute('Id');
      final target = relationship.getAttribute('Target');
      if (id != null && target != null) targets[id] = target;
    }

    final sheets = workbook.descendantElements.where((element) => element.name.local == 'sheet').toList();
    if (sheets.isEmpty) return {};
    final selected = sheets.firstWhere((sheet) => sheet.getAttribute('name') == sheetName, orElse: () => sheets.first);
    final relationshipId = selected.attributes
        .where((attribute) => attribute.name.local == 'id')
        .map((attribute) => attribute.value)
        .firstOrNull;
    final target = relationshipId == null ? null : targets[relationshipId];
    if (target == null) return {};

    final sheetPath = target.startsWith('/') ? target.substring(1) : Uri.parse('xl/').resolve(target).path;
    final sheetText = readText(_normalizeZipPath(sheetPath));
    if (sheetText == null) return {};

    final sharedStrings = <String>[];
    final sharedText = readText('xl/sharedStrings.xml');
    if (sharedText != null) {
      final sharedDocument = XmlDocument.parse(sharedText);
      for (final item in sharedDocument.descendantElements.where((element) => element.name.local == 'si')) {
        sharedStrings.add(
          item.descendantElements
              .where((element) => element.name.local == 't')
              .map((element) => element.innerText)
              .join(),
        );
      }
    }

    final rows = <int, Map<String, String>>{};
    final document = XmlDocument.parse(sheetText);
    for (final row in document.descendantElements.where((element) => element.name.local == 'row')) {
      final rowNumber = int.tryParse(row.getAttribute('r') ?? '');
      if (rowNumber == null) continue;
      final cells = <String, String>{};
      for (final cell in row.childElements.where((element) => element.name.local == 'c')) {
        final column = RegExp(r'^[A-Za-z]+').firstMatch(cell.getAttribute('r') ?? '')?.group(0)?.toUpperCase();
        if (column == null) continue;
        final type = cell.getAttribute('t');
        String value;
        if (type == 'inlineStr') {
          value = cell.descendantElements
              .where((element) => element.name.local == 't')
              .map((element) => element.innerText)
              .join();
        } else {
          final rawValue =
              cell.childElements
                  .where((element) => element.name.local == 'v')
                  .map((element) => element.innerText)
                  .firstOrNull ??
              '';
          if (type == 's') {
            final index = int.tryParse(rawValue);
            value = index != null && index >= 0 && index < sharedStrings.length ? sharedStrings[index] : '';
          } else {
            value = rawValue;
          }
        }
        if (value.isNotEmpty) cells[column] = value;
      }
      if (cells.isNotEmpty) rows[rowNumber] = cells;
    }
    return rows;
  }

  static String _normalizeZipPath(String path) {
    final segments = <String>[];
    for (final segment in path.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else {
        segments.add(segment);
      }
    }
    return segments.join('/');
  }
}
