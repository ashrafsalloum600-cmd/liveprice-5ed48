import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:liveprice/services/firestore_service.dart';

class AdminPriceUploadScreen extends StatefulWidget {
  const AdminPriceUploadScreen({super.key});

  @override
  State<AdminPriceUploadScreen> createState() => _AdminPriceUploadScreenState();
}

class _AdminPriceUploadScreenState extends State<AdminPriceUploadScreen> {
  static const String _pin = '8888';
  bool _authorized = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPin());
  }

  Future<void> _askPin() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('رمز الدخول'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(hintText: '****'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text == _pin), child: const Text('دخول')),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _authorized = true);
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickAndUpload() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
    );
    if (files.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final PlatformFile file = files.first;
      final Uint8List bytes = await file.readAsBytes();
      final String content = utf8.decode(bytes);
      final String? ext = file.extension?.toLowerCase();

      final List<Map<String, dynamic>> items = ext == 'json' ? _parseJson(content) : _parseCsv(content);

      await FirestoreService().uploadProductsBatch(items);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم رفع ${items.length} عنصر بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  List<Map<String, dynamic>> _parseJson(String content) {
    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _parseCsv(String content) {
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = lines.first.split(',').map((h) => h.trim()).toList();
    final rows = <Map<String, dynamic>>[];

    for (final line in lines.skip(1)) {
      final cells = line.split(',');
      final row = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < cells.length; i++) {
        final value = cells[i].trim();
        row[headers[i]] = headers[i] == 'price' ? double.tryParse(value) ?? 0.0 : value;
      }
      rows.add(row);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Scaffold(backgroundColor: Color(0xFFE4E4E4), body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE4E4E4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE4E4E4),
        elevation: 0,
        title: const Text('رفع الأسعار', style: TextStyle(color: Colors.black)),
      ),
      body: Center(
        child: _uploading
            ? const CircularProgressIndicator(color: Colors.black)
            : GestureDetector(
                onTap: _pickAndUpload,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file_rounded, color: Colors.black),
                      SizedBox(width: 10),
                      Text(
                        'اختر ملف CSV / JSON',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
