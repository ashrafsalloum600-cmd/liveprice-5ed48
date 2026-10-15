import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/models/inventory_format.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/inventory_matcher.dart';
import 'package:liveprice/services/inventory_mapping_service.dart';
import 'package:liveprice/services/inventory_parser.dart';
import 'package:liveprice/services/inventory_upload_service.dart';
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
  List<ProductModel>? _products;
  final Map<int, ProductModel> _matches = {};
  final Set<int> _expandedRows = {};
  bool _loading = false;
  bool _savingMappings = false;
  bool _previewingInventory = false;
  bool _applyingInventory = false;

  Future<void> _pickInventory() async {
    setState(() => _loading = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['csv']);
      if (files.isEmpty) return;
      final file = files.first;
      final Uint8List bytes = await file.readAsBytes();
      final format = await InventoryFormat.load();
      final result = InventoryParseResult.parse(bytes, format);
      var products = _products;
      if (products == null) {
        products = await FirestoreService().getProducts();
        _products = products;
      }
      if (mounted) {
        setState(() {
          _result = result;
          _matches.clear();
          _expandedRows.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _acceptConfidentMatches(List<InventoryRow> rows) {
    final products = _products;
    if (products == null) return;
    final accepted = <int, ProductModel>{};
    for (final row in rows) {
      if (_matches.containsKey(row.rowNumber)) continue;
      final suggestions = InventoryMatcher.suggestionsFor(row, products);
      if (suggestions.isEmpty || suggestions.first.score < 95) continue;
      if (suggestions.length > 1 && suggestions.first.score - suggestions[1].score < 5) continue;
      accepted[row.rowNumber] = suggestions.first.product;
    }
    setState(() => _matches.addAll(accepted));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('تم قبول ${accepted.length} مطابقة مؤكدة للمراجعة')));
  }

  Future<void> _chooseManually(InventoryRow row) async {
    final products = _products;
    if (products == null) return;
    final selected = await showDialog<ProductModel>(
      context: context,
      builder: (context) => _ProductSearchDialog(products: products),
    );
    if (selected != null && mounted) setState(() => _matches[row.rowNumber] = selected);
  }

  Future<void> _saveMappings() async {
    final result = _result;
    if (result == null) return;
    setState(() => _savingMappings = true);
    try {
      final saved = await InventoryMappingService().saveBranchMappings(
        branchId: widget.branchId,
        rows: result.rows,
        matches: _matches,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ ${saved.mappedCount} ربط، وتُرك ${saved.unmatchedCount} رمزاً غير مربوط دون حفظ، '
              'وتجاوز ${saved.skippedWithoutCode} صفوف بلا رمز',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingMappings = false);
    }
  }

  Future<void> _reviewAndApplyInventory() async {
    final result = _result;
    final products = _products;
    if (result == null || products == null) return;
    setState(() => _previewingInventory = true);
    try {
      final service = InventoryUploadService();
      final preview = await service.preview(branchId: widget.branchId, rows: result.rows, existingProducts: products);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _InventoryPreviewDialog(preview: preview),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _applyingInventory = true);
      final updatedCount = await service.apply(preview);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم تحديث كميات $updatedCount منتج موجود. لم تُصفّر المواد الغائبة.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _previewingInventory = false;
          _applyingInventory = false;
        });
      }
    }
  }

  Widget _buildMatchRow(InventoryRow row) {
    final products = _products ?? const <ProductModel>[];
    final selected = _matches[row.rowNumber];
    final suggestions = _expandedRows.contains(row.rowNumber)
        ? InventoryMatcher.suggestionsFor(row, products)
        : const <InventoryMatchSuggestion>[];
    return ExpansionTile(
      key: ValueKey('inventory-row-${row.rowNumber}'),
      onExpansionChanged: (expanded) {
        setState(() {
          if (expanded) {
            _expandedRows.add(row.rowNumber);
          } else {
            _expandedRows.remove(row.rowNumber);
          }
        });
      },
      title: Text(row.name, style: const TextStyle(color: AppColors.text)),
      subtitle: Text(
        'الرمز: ${row.sourceCode.isEmpty ? 'غير موجود' : row.sourceCode} | الكمية: ${row.qty}',
        style: const TextStyle(color: AppColors.textDim),
      ),
      trailing: selected == null
          ? const Icon(Icons.link, color: AppColors.textDim)
          : const Icon(Icons.link, color: AppColors.accent),
      children: [
        if (selected != null)
          ListTile(
            dense: true,
            title: Text('الربط المؤقت: ${selected.name}', style: const TextStyle(color: AppColors.text)),
            subtitle: Text(selected.id, style: const TextStyle(color: AppColors.textDim)),
            trailing: IconButton(
              tooltip: 'إزالة الربط',
              onPressed: () => setState(() => _matches.remove(row.rowNumber)),
              icon: const Icon(Icons.link_off),
            ),
          ),
        for (final suggestion in suggestions)
          ListTile(
            dense: true,
            title: Text(suggestion.product.name, style: const TextStyle(color: AppColors.text)),
            subtitle: Text(
              '${suggestion.score}% تشابه | ${suggestion.product.id}',
              style: const TextStyle(color: AppColors.textDim),
            ),
            trailing: IconButton(
              tooltip: 'ربط بهذا المنتج',
              onPressed: () => setState(() => _matches[row.rowNumber] = suggestion.product),
              icon: const Icon(Icons.link),
            ),
          ),
        TextButton.icon(
          onPressed: () => _chooseManually(row),
          icon: const Icon(Icons.search),
          label: const Text('بحث واختيار يدوي'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final rows = result?.rows ?? const <InventoryRow>[];
    final issues = result?.issues ?? const <InventoryIssue>[];
    final matchedCount = rows.where((row) => _matches.containsKey(row.rowNumber)).length;
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: result == null ? 1 : rows.length + 3,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Align(
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
                      );
                    }
                    if (result == null) return const SizedBox.shrink();
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الصفوف الصالحة: ${rows.length}', style: const TextStyle(color: AppColors.text)),
                            Text(
                              'المربوط: $matchedCount | بانتظار الربط: ${rows.length - matchedCount}',
                              style: const TextStyle(color: AppColors.text),
                            ),
                            Text(
                              'الأصفار: ${rows.where((row) => row.qty == 0).length}',
                              style: const TextStyle(color: AppColors.text),
                            ),
                            Text(
                              'الكميات السالبة: ${rows.where((row) => row.qty < 0).length}',
                              style: const TextStyle(color: AppColors.text),
                            ),
                            Text(
                              'المشاكل: أسماء ${issueCounts['name']}، كميات ${issueCounts['qty']}، تكرار ${issueCounts['duplicate']}',
                              style: const TextStyle(color: AppColors.text),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _products == null ? null : () => _acceptConfidentMatches(rows),
                                icon: const Icon(Icons.done_all),
                                label: const Text('قبول المطابقات المؤكدة'),
                              ),
                            ),
                            Text(
                              'مطابقة المنتجات',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                            ),
                          ],
                        ),
                      );
                    }
                    if (index < rows.length + 2) return _buildMatchRow(rows[index - 2]);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'أول 20 مشكلة',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
                        ),
                        if (issues.isEmpty)
                          const Text('لا توجد مشاكل', style: TextStyle(color: AppColors.textDim))
                        else
                          for (final issue in issues.take(20))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'صف ${issue.rowNumber}: ${issue.message}',
                                style: const TextStyle(color: AppColors.text),
                              ),
                              trailing: Text(issue.type, style: const TextStyle(color: AppColors.textDim)),
                            ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: result == null || _savingMappings || _applyingInventory ? null : _saveMappings,
                        icon: _savingMappings
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(_savingMappings ? 'جارٍ حفظ خريطة الربط...' : 'حفظ خريطة الربط'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: result == null || _previewingInventory || _applyingInventory
                            ? null
                            : _reviewAndApplyInventory,
                        icon: _previewingInventory || _applyingInventory
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.fact_check),
                        label: Text(
                          _previewingInventory
                              ? 'جارٍ إعداد المعاينة...'
                              : _applyingInventory
                              ? 'جارٍ تطبيق الكميات...'
                              : 'معاينة وتأكيد رفع الكميات',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSearchDialog extends StatefulWidget {
  const _ProductSearchDialog({required this.products});

  final List<ProductModel> products;

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = normalizeName(_query).toLowerCase();
    final results = widget.products
        .where((product) {
          return normalizedQuery.isEmpty ||
              normalizeName(product.name).toLowerCase().contains(normalizedQuery) ||
              product.id.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
    return AlertDialog(
      title: const Text('اختيار منتج رئيسي'),
      content: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم أو الرمز'),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final product = results[index];
                  return ListTile(
                    dense: true,
                    title: Text(product.name),
                    subtitle: Text('${product.id} | ${product.unit}'),
                    onTap: () => Navigator.of(context).pop(product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء'))],
    );
  }
}

class _InventoryPreviewDialog extends StatelessWidget {
  const _InventoryPreviewDialog({required this.preview});

  final InventoryUploadPreview preview;

  @override
  Widget build(BuildContext context) {
    final skippedCount = preview.unmappedCount + preview.missingProductCount + preview.invalidMappingCount;
    return AlertDialog(
      title: const Text('معاينة تحديث الجرد'),
      content: SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('منتجات موجودة ستتغير: ${preview.items.length}'),
            Text('كمياتها لم تتغير: ${preview.unchangedCount}'),
            Text('صفوف مستبعدة دون رفع: $skippedCount'),
            const SizedBox(height: 8),
            if (skippedCount > 0)
              Text(
                'غير مربوط: ${preview.unmappedCount} | المنتج غير موجود: ${preview.missingProductCount} | ربط غير صالح: ${preview.invalidMappingCount}',
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: preview.items.isEmpty
                  ? const Center(child: Text('لا توجد كميات متحققة للتطبيق'))
                  : ListView.builder(
                      itemCount: preview.items.length,
                      itemBuilder: (context, index) {
                        final item = preview.items[index];
                        final previous = item.previousQuantity?.toString() ?? 'غير مسجلة';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName),
                          subtitle: Text(
                            'السابق: $previous | الجديد: ${item.newQuantity} | صفوف المصدر: ${item.rowCount}',
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            const Text('لن تُنشأ منتجات، ولن تُصفّر المواد غير الموجودة في الملف.'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
        FilledButton(
          onPressed: preview.items.isEmpty ? null : () => Navigator.of(context).pop(true),
          child: const Text('تطبيق الكميات المعروضة'),
        ),
      ],
    );
  }
}
