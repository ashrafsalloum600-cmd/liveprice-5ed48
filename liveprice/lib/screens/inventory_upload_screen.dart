import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/models/inventory_format.dart';
import 'package:liveprice/services/inventory_parser.dart';
import 'package:liveprice/theme/app_colors.dart';

class InventoryUploadScreen extends StatefulWidget {
  const InventoryUploadScreen({super.key, required this.branchId, required this.branchName});

  final String branchId;
  final String branchName;

  @override
  State<InventoryUploadScreen> createState() => _InventoryUploadScreenState();
}

class _InventoryUploadScreenState extends State<InventoryUploadScreen> {
  InventoryParseResult? _result;
  bool _loading = false;

  Future<void> _pickInventory() async {
    setState(() => _loading = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['csv']);
      if (files.isEmpty) return;
      final file = files.first;
      final Uint8List bytes = await file.readAsBytes();
      final format = await InventoryFormat.load();
      final result = InventoryParseResult.parse(bytes, format);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final rows = result?.rows ?? const <InventoryRow>[];
    final issues = result?.issues ?? const <InventoryIssue>[];
    final issueCounts = {
      'name': issues.where((issue) => issue.type == 'name').length,
      'qty': issues.where((issue) => issue.type == 'qty').length,
      'duplicate': issues.where((issue) => issue.type == 'duplicate').length,
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text('معاينة الجرد - ${widget.branchName}'),
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.text,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _pickInventory,
                        icon: _loading
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file),
                        label: const Text('اختيار ملف الجرد (CSV)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 20),
                      Text('الصفوف الصالحة: ${rows.length}', style: const TextStyle(color: AppColors.text)),
                      Text(
                        'الأصفار: ${rows.where((row) => row.qty == 0).length}',
                        style: const TextStyle(color: AppColors.text),
                      ),
                      Text(
                        'الكميات السالبة: ${rows.where((row) => row.qty < 0).length}',
                        style: const TextStyle(color: AppColors.text),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'المشاكل: أسماء ${issueCounts['name']}، كميات ${issueCounts['qty']}، تكرار ${issueCounts['duplicate']}',
                        style: const TextStyle(color: AppColors.text),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'أول 10 صفوف',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                      ),
                      for (final row in rows.take(10))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(row.name, style: const TextStyle(color: AppColors.text)),
                          subtitle: Text(
                            'الوحدة: ${row.unit} | الكمية: ${row.qty}',
                            style: const TextStyle(color: AppColors.textDim),
                          ),
                          trailing: Text('${row.rowNumber}', style: const TextStyle(color: AppColors.textDim)),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'أول 20 مشكلة',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                      ),
                      if (issues.isEmpty)
                        const Text('لا توجد مشاكل', style: TextStyle(color: AppColors.textDim))
                      else
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            itemCount: issues.length.clamp(0, 20),
                            itemBuilder: (context, index) {
                              final issue = issues[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'صف ${issue.rowNumber}: ${issue.message}',
                                  style: const TextStyle(color: AppColors.text),
                                ),
                                trailing: Text(issue.type, style: const TextStyle(color: AppColors.textDim)),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: null, child: const Text('تأكيد الرفع (الخطوة التالية)')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
