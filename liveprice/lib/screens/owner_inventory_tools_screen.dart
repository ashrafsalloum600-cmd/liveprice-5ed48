import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/audit_service.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/branch_inventory_store.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:liveprice/widgets/wipe_data_button.dart';

class OwnerInventoryToolsScreen extends StatefulWidget {
  const OwnerInventoryToolsScreen({super.key});

  @override
  State<OwnerInventoryToolsScreen> createState() => _OwnerInventoryToolsScreenState();
}

class _OwnerInventoryToolsScreenState extends State<OwnerInventoryToolsScreen> {
  late Future<List<ProductModel>> _productsFuture;
  late Future<Map<String, Map<String, num>>> _quantitiesFuture;
  late Future<List<Map<String, dynamic>>> _auditFuture;
  bool _migrating = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _productsFuture = FirestoreService().getProducts();
    _quantitiesFuture = BranchInventoryStore().loadAllQuantities();
    _auditFuture = _loadAudit();
  }

  Future<List<Map<String, dynamic>>> _loadAudit() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('audit_logs')
        .orderBy('at', descending: true)
        .limit(100)
        .get();
    return snapshot.docs.map((document) => {'id': document.id, ...document.data()}).toList(growable: false);
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await Future.wait([_productsFuture, _quantitiesFuture, _auditFuture]);
    } catch (_) {
      // Each tab displays its own read error and required collection.
    }
  }

  String _readError(String collection) => 'تعذرت قراءة $collection. تحقق من صلاحيات المالك في قواعد Firestore.';

  Future<void> _publishCatalog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نشر الكتالوج العام'),
        content: const Text(
          'سيقرأ النظام المنتجات مرة واحدة من الخادم، ثم يكتب بيانات الكتالوج العام مرة واحدة لكل منتج.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('نشر')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishing = true);
    try {
      final count = await FirestoreService().publishCatalog();
      await AuditService.log('publish_catalog', details: {'count': count});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('نُشر الكتالوج العام: $count منتج')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل نشر الكتالوج العام: $error')));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _migrateLegacyInventory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نقل كميات المخزون القديمة'),
        content: const Text(
          'سينسخ النظام قيم q_b1 وq_b2 وq_b3 كما هي إلى مخزن خاص، ثم يزيل الحقول القديمة من المنتجات بعد التحقق. '
          'القيم المتعارضة ستُترك دون تغيير للمراجعة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('بدء النقل')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _migrating = true);
    try {
      final result = await BranchInventoryStore().migrateLegacyProductQuantities();
      if (!mounted) return;
      setState(_reload);
      final conflictSummary = result.conflicts.take(3).join('، ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'نُقلت ${result.migratedQuantities} كمية. التعارضات: ${result.conflicts.length}'
            '${conflictSummary.isEmpty ? '' : ' ($conflictSummary)'}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل نقل الكميات: $error')));
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          bottomNavigationBar: const SafeArea(
            child: Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: WipeDataButton()),
          ),
          appBar: AppBar(
            title: const Text('أدوات المالك'),
            backgroundColor: AppColors.bg,
            foregroundColor: AppColors.text,
            actions: [
              TextButton.icon(
                onPressed: _publishing ? null : _publishCatalog,
                icon: _publishing
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.public),
                label: const Text('نشر الكتالوج العام'),
              ),
              IconButton(
                tooltip: 'نقل الكميات القديمة إلى المخزن الخاص',
                onPressed: _migrating ? null : _migrateLegacyInventory,
                icon: _migrating
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.move_down),
              ),
              IconButton(tooltip: 'تحديث', onPressed: _refresh, icon: const Icon(Icons.refresh)),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.inventory_2_outlined), text: 'تقرير المخزون'),
                Tab(icon: Icon(Icons.history), text: 'سجل الحركات'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              FutureBuilder<List<ProductModel>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                  }
                  if (snapshot.hasError) return Center(child: Text(_readError('products')));
                  return FutureBuilder<Map<String, Map<String, num>>>(
                    future: _quantitiesFuture,
                    builder: (context, quantitySnapshot) {
                      if (quantitySnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                      }
                      if (quantitySnapshot.hasError) return Center(child: Text(_readError('branch_stock')));
                      return _InventoryReport(
                        products: snapshot.data ?? const [],
                        quantities: quantitySnapshot.data ?? const {},
                      );
                    },
                  );
                },
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _auditFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                  }
                  if (snapshot.hasError) return Center(child: Text(_readError('audit_logs')));
                  final events = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (events.isEmpty) return const Center(child: Text('لا توجد حركات مسجلة'));
                  return ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) => _AuditEventTile(event: events[index]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryReport extends StatelessWidget {
  const _InventoryReport({required this.products, required this.quantities});

  final List<ProductModel> products;
  final Map<String, Map<String, num>> quantities;
  static const _branches = {'b1': 'المركز الرئيسي', 'b2': 'طرطوس', 'b3': 'جديدة البحر'};

  @override
  Widget build(BuildContext context) {
    final totals = <String, num>{for (final branchId in _branches.keys) branchId: 0};
    final knownCounts = <String, int>{for (final branchId in _branches.keys) branchId: 0};
    for (final product in products) {
      for (final branchId in _branches.keys) {
        final quantity = quantities[branchId]?[product.id];
        if (quantity == null) continue;
        totals[branchId] = totals[branchId]! + quantity;
        knownCounts[branchId] = knownCounts[branchId]! + 1;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('المنتجات الموجودة: ${products.length}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('الإجمالي أدناه يجمع الكميات المسجلة فقط؛ القيم الناقصة غير مقدرة.'),
        const SizedBox(height: 12),
        for (final branch in _branches.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(branch.value),
            subtitle: Text('كميات مسجلة لـ ${knownCounts[branch.key]} من ${products.length} منتج'),
            trailing: Text(totals[branch.key].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 8),
        Text('أقل من أو يساوي 5 في فرع واحد على الأقل', style: Theme.of(context).textTheme.titleSmall),
        for (final product in products.where((product) {
          return _branches.keys.any((branchId) => (quantities[branchId]?[product.id] ?? 6) <= 5);
        }))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(product.name),
            subtitle: Text(
              _branches.entries
                  .where((branch) => (quantities[branch.key]?[product.id] ?? 6) <= 5)
                  .map((branch) => '${branch.value}: ${quantities[branch.key]?[product.id]}')
                  .join(' | '),
            ),
          ),
      ],
    );
  }
}

class _AuditEventTile extends StatelessWidget {
  const _AuditEventTile({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final timestamp = event['at'];
    final date = timestamp is Timestamp ? timestamp.toDate().toLocal().toString() : 'وقت غير متاح';
    final details = event['details'];
    final detailsText = details is Map
        ? details.entries.map((entry) => '${entry.key}: ${entry.value}').join(' | ')
        : '';
    final actor = (event['name'] as String?)?.trim().isNotEmpty == true
        ? event['name'] as String
        : (event['email'] as String? ?? 'مستخدم غير معروف');
    return ListTile(
      title: Text('${event['type'] ?? 'حركة'} • $actor'),
      subtitle: Text(
        [date, 'الفرع: ${event['branchId'] ?? 'غير محدد'}', detailsText].where((text) => text.isNotEmpty).join('\n'),
      ),
      isThreeLine: detailsText.isNotEmpty,
    );
  }
}
