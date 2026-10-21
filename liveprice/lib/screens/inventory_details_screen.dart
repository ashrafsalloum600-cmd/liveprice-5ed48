import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide SnackBar, ScaffoldMessenger;
import 'package:liveprice/widgets/app_message.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/branch_inventory_store.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/inventory_parser.dart';
import 'package:liveprice/theme/app_colors.dart';

class InventoryDetailsScreen extends StatefulWidget {
  const InventoryDetailsScreen({super.key});

  @override
  State<InventoryDetailsScreen> createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  static const _branchNames = {'b1': 'المركز الرئيسي', 'b2': 'طرطوس', 'b3': 'جديدة البحر'};

  late Future<List<ProductModel>> _productsFuture;
  late Future<_BranchInventoryData> _inventoryFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _productsFuture = FirestoreService().getProducts();
    _inventoryFuture = _loadBranchInventory();
  }

  Future<_BranchInventoryData> _loadBranchInventory() async {
    final branchIds = _branchNames.keys.toList(growable: false);
    final store = BranchInventoryStore();
    final quantitiesFuture = store.loadAllQuantities();
    final metaSnapshots = await Future.wait([
      for (final branchId in branchIds) FirebaseFirestore.instance.collection('inventory_meta').doc(branchId).get(),
    ]);
    final quantities = await quantitiesFuture;
    final lastUploads = <String, DateTime?>{};
    for (var index = 0; index < branchIds.length; index++) {
      final value = metaSnapshots[index].data()?['lastUploadAt'];
      lastUploads[branchIds[index]] = value is Timestamp ? value.toDate() : null;
    }
    return _BranchInventoryData(quantities: quantities, lastUploads: lastUploads);
  }

  static Map<String, num> _totalsByUnit(ProductModel product, _BranchInventoryData inventory) {
    final totals = <String, num>{};
    for (final branchId in _branchNames.keys) {
      final quantity = inventory.quantities[branchId]?[product.id];
      if (quantity == null) continue;
      final unit = product.unit;
      totals.update(unit, (total) => total + quantity, ifAbsent: () => quantity);
    }
    return totals;
  }

  static String _totalLabel(ProductModel product, _BranchInventoryData inventory) {
    final totals = _totalsByUnit(product, inventory);
    if (totals.isEmpty) return 'الكميات غير مسجلة';
    return totals.entries.map((entry) => 'الإجمالي: ${entry.value} ${entry.key}'.trim()).join(' • ');
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await Future.wait([_productsFuture, _inventoryFuture]);
    } catch (error) {
      if (mounted) {
        showAppMessage('تعذر تحديث بيانات المخزون: $error');
      }
    }
  }

  void _showProductDetails(ProductModel product, _BranchInventoryData inventory) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ProductInventorySheet(product: product, branchNames: _branchNames, inventory: inventory),
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
                    return FutureBuilder<_BranchInventoryData>(
                      future: _inventoryFuture,
                      builder: (context, inventorySnapshot) {
                        if (inventorySnapshot.hasError) {
                          return const Center(child: Text('تعذر قراءة كميات الفروع؛ تحقق من صلاحيات الموظف'));
                        }
                        if (!inventorySnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                        }
                        final inventory = inventorySnapshot.data!;
                        return ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return ListTile(
                              title: Text(product.name, style: const TextStyle(color: AppColors.text)),
                              subtitle: Text(
                                _totalLabel(product, inventory),
                                style: const TextStyle(color: AppColors.textDim),
                              ),
                              trailing: const Icon(Icons.chevron_left, color: AppColors.textDim),
                              onTap: () => _showProductDetails(product, inventory),
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

class _BranchInventoryData {
  const _BranchInventoryData({required this.quantities, required this.lastUploads});

  final Map<String, Map<String, num>> quantities;
  final Map<String, DateTime?> lastUploads;
}

class _ProductInventorySheet extends StatelessWidget {
  const _ProductInventorySheet({required this.product, required this.branchNames, required this.inventory});

  final ProductModel product;
  final Map<String, String> branchNames;
  final _BranchInventoryData inventory;

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
                subtitle: Text('آخر رفع: ${_formatDate(inventory.lastUploads[branch.key])}'),
                trailing: Text(
                  '${inventory.quantities[branch.key]?[product.id]?.toString() ?? 'غير مسجل'} ${product.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ),
            for (final total in _InventoryDetailsScreenState._totalsByUnit(product, inventory).entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('الإجمالي (${total.key})'),
                trailing: Text(total.value.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}
