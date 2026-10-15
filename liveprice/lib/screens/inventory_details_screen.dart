import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/inventory_parser.dart';
import 'package:liveprice/services/branch_inventory_store.dart';
import 'package:liveprice/theme/app_colors.dart';

class InventoryDetailsScreen extends StatefulWidget {
  const InventoryDetailsScreen({super.key});

  @override
  State<InventoryDetailsScreen> createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  static const _branchNames = {'b1': 'المركز الرئيسي', 'b2': 'طرطوس', 'b3': 'جديدة البحر'};

  late Future<List<ProductModel>> _productsFuture;
  late Future<Map<String, Map<String, num>>> _quantitiesFuture;
  late Future<Map<String, DateTime?>> _lastUploadsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _productsFuture = FirestoreService().getProducts();
    _quantitiesFuture = BranchInventoryStore().loadAllQuantities();
    _lastUploadsFuture = _loadLastUploads();
  }

  Future<Map<String, DateTime?>> _loadLastUploads() async {
    final result = <String, DateTime?>{};
    for (final branchId in _branchNames.keys) {
      try {
        final snapshot = await FirebaseFirestore.instance.collection('inventory_meta').doc(branchId).get();
        final value = snapshot.data()?['lastUploadAt'];
        result[branchId] = value is Timestamp ? value.toDate() : null;
      } catch (_) {
        result[branchId] = null;
      }
    }
    return result;
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await Future.wait([_productsFuture, _quantitiesFuture, _lastUploadsFuture]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث بيانات المخزون: $error')));
      }
    }
  }

  void _showProductDetails(ProductModel product, Map<String, num> quantities, Map<String, DateTime?> lastUploads) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ProductInventorySheet(
        product: product,
        branchNames: _branchNames,
        quantities: quantities,
        lastUploads: lastUploads,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('تفاصيل مخزون الفروع'),
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.text,
          actions: [IconButton(tooltip: 'تحديث المخزون', onPressed: _refresh, icon: const Icon(Icons.refresh))],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'ابحث باسم المنتج أو رمزه',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ProductModel>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('تعذر تحميل المنتجات أو ليس لديك صلاحية القراءة'));
                    }
                    final normalizedQuery = normalizeName(_query).toLowerCase();
                    final products = (snapshot.data ?? const <ProductModel>[])
                        .where((product) {
                          return normalizedQuery.isEmpty ||
                              normalizeName(product.name).toLowerCase().contains(normalizedQuery) ||
                              product.id.toLowerCase().contains(normalizedQuery);
                        })
                        .toList(growable: false);
                    if (products.isEmpty) return const Center(child: Text('لا توجد منتجات مطابقة'));
                    return FutureBuilder<Map<String, Map<String, num>>>(
                      future: _quantitiesFuture,
                      builder: (context, quantitySnapshot) {
                        if (quantitySnapshot.hasError) {
                          return const Center(child: Text('تعذر قراءة كميات الفروع؛ تحقق من صلاحيات الموظف'));
                        }
                        if (!quantitySnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                        }
                        final branchQuantities = quantitySnapshot.data!;
                        return FutureBuilder<Map<String, DateTime?>>(
                          future: _lastUploadsFuture,
                          builder: (context, uploadSnapshot) {
                            final lastUploads = uploadSnapshot.data ?? const <String, DateTime?>{};
                            return ListView.separated(
                              itemCount: products.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                              itemBuilder: (context, index) {
                                final product = products[index];
                                final quantities = <String, num>{
                                  for (final branchId in _branchNames.keys)
                                    if (branchQuantities[branchId]!.containsKey(product.id))
                                      branchId: branchQuantities[branchId]![product.id]!,
                                };
                                final total = quantities.length == _branchNames.length
                                    ? quantities.values.fold<num>(0, (sum, value) => sum + value)
                                    : null;
                                return ListTile(
                                  title: Text(product.name, style: const TextStyle(color: AppColors.text)),
                                  subtitle: Text(
                                    total == null ? 'إجمالي المخزون غير مكتمل' : 'الإجمالي المسجل: $total',
                                    style: const TextStyle(color: AppColors.textDim),
                                  ),
                                  trailing: const Icon(Icons.chevron_left, color: AppColors.textDim),
                                  onTap: () => _showProductDetails(product, quantities, lastUploads),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductInventorySheet extends StatelessWidget {
  const _ProductInventorySheet({
    required this.product,
    required this.branchNames,
    required this.quantities,
    required this.lastUploads,
  });

  final ProductModel product;
  final Map<String, String> branchNames;
  final Map<String, num> quantities;
  final Map<String, DateTime?> lastUploads;

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير مسجل أو غير متاح';
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(product.name, style: Theme.of(context).textTheme.titleLarge),
            Text('رمز المنتج: ${product.id}', style: const TextStyle(color: AppColors.textDim)),
            const SizedBox(height: 16),
            for (final branch in branchNames.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(branch.value),
                subtitle: Text('آخر جرد: ${_formatDate(lastUploads[branch.key])}'),
                trailing: Text(
                  quantities[branch.key]?.toString() ?? 'غير مسجل',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
