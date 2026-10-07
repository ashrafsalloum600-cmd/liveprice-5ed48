import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/services/auth_service.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/widgets/admin_notification_widget.dart';
import 'package:liveprice/widgets/admin_rate_widget.dart';

class AdminPriceUploadScreen extends StatefulWidget {
  const AdminPriceUploadScreen({super.key});

  @override
  State<AdminPriceUploadScreen> createState() => _AdminPriceUploadScreenState();
}

class _AdminPriceUploadScreenState extends State<AdminPriceUploadScreen> {
  final AuthService _authService = AuthService();
  bool _uploading = false;
  String? _selectedCurrency;
  bool _fileHasValidCurrency = false;

  bool get _canUpload => _selectedCurrency != null || _fileHasValidCurrency;

  String? _normalizeCurrencyInput(Object? value) {
    final raw = (value as String?)?.trim();
    if (raw == null) return null;
    final upper = raw.toUpperCase();
    return upper == 'USD' || upper == 'SYP' ? upper : null;
  }

  List<String> _splitCsvLine(String line) {
    final items = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        items.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    items.add(buffer.toString());
    return items;
  }

  String _cleanPrice(String value) => value.replaceAll(RegExp(r'[\s,\$]'), '');

  Future<void> _pickAndUpload() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
    );
    if (files.isEmpty) return;

    final PlatformFile file = files.first;
    final Uint8List bytes = await file.readAsBytes();
    final String content = utf8.decode(bytes);
    final String? ext = file.extension?.toLowerCase();

    final List<Map<String, dynamic>> items = ext == 'json' ? _parseJson(content) : _parseCsv(content);
    final hasValidCurrencyColumn =
        items.isNotEmpty && items.every((row) => _normalizeCurrencyInput(row['currency']) != null);
    setState(() => _fileHasValidCurrency = hasValidCurrencyColumn);

    if (_selectedCurrency == null && !_fileHasValidCurrency) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('اختر العملة أولاً أو تأكد من وجود عمود currency صالح في الملف')));
      }
      return;
    }

    final confirmed = await _confirmUpload(items);
    if (confirmed != true) return;

    setState(() => _uploading = true);
    try {
      final normalized = items.map((row) {
        final resolvedCurrency = _normalizeCurrencyInput(row['currency']) ?? _selectedCurrency ?? 'SYP';
        final map = Map<String, dynamic>.from(row);
        map['currency'] = resolvedCurrency;
        return map;
      }).toList();

      await FirestoreService().uploadProductsBatch(normalized);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم رفع ${normalized.length} عنصر بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<bool?> _confirmUpload(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return false;

    final first = items.first;
    final detailCurrency = _normalizeCurrencyInput(first['currency']) ?? _selectedCurrency ?? 'SYP';
    final detail = {'id': first['id'] ?? '', 'name': first['name'] ?? '', 'price': first['price'] ?? ''};

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الرفع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('العملة: $detailCurrency'),
            const SizedBox(height: 8),
            Text('عدد الصفوف: ${items.length}'),
            const SizedBox(height: 8),
            Text('أول صف: id=${detail['id']}, name=${detail['name']}, price=${detail['price']}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('تأكيد')),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _parseJson(String content) {
    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _parseCsv(String content) {
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headers = _splitCsvLine(lines.first).map((h) => h.trim()).toList();
    final rows = <Map<String, dynamic>>[];

    for (final line in lines.skip(1)) {
      final cells = _splitCsvLine(line);
      final row = <String, dynamic>{};
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i];
        final value = i < cells.length ? cells[i].trim() : '';

        if (header.toLowerCase() == 'price') {
          row[header] = double.tryParse(_cleanPrice(value)) ?? 0.0;
        } else {
          row[header] = value;
        }
      }
      rows.add(row);
    }
    return rows;
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message ?? 'تعذر تسجيل الدخول باستخدام Google')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFE4E4E4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 64, color: AppColors.text),
                const SizedBox(height: 16),
                const Text(
                  'تسجيل الدخول للإدارة',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 220,
                  child: ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('تسجيل الدخول بحساب Google'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthorizedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFE4E4E4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'هذا الحساب غير مصرّح له بالإدارة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _authService.signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminContent() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('رفع الأسعار', style: TextStyle(color: AppColors.text)),
        actions: [
          TextButton.icon(
            onPressed: _authService.signOut,
            icon: const Icon(Icons.logout_rounded, color: AppColors.text),
            label: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.text)),
          ),
        ],
      ),
      body: Center(
        child: _uploading
            ? const CircularProgressIndicator(color: AppColors.text)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCurrency,
                        decoration: const InputDecoration(labelText: 'عملة الملف', border: InputBorder.none),
                        hint: const Text('اختر العملة'),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('دولار')),
                          DropdownMenuItem(value: 'SYP', child: Text('سوري')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCurrency = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: _canUpload ? _pickAndUpload : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upload_file_rounded, color: AppColors.text),
                              SizedBox(width: 10),
                              Text(
                                'اختر ملف CSV / JSON',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const AdminRateWidget(),
                    const SizedBox(height: 24),
                    const AdminNotificationWidget(),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authState,
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null) {
          return _buildLoginScreen();
        }

        if (!_authService.isAdmin(user)) {
          return _buildUnauthorizedScreen();
        }

        return _buildAdminContent();
      },
    );
  }
}
