import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/widgets/app_message.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/branch_inventory_store.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/inventory_parser.dart';
import 'package:liveprice/services/staff_session.dart';
import 'package:liveprice/theme/app_colors.dart';

const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

class InventoryDetailsScreen extends StatefulWidget {
  const InventoryDetailsScreen({super.key});

  @override
  State<InventoryDetailsScreen> createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  static const _branchNames = {'b1': 'المركز الرئيسي', 'b2': 'طرطوس', 'b3': 'جديدة البحر'};

  late Future<List<ProductModel>> _productsFuture;
  late Future<_BranchInventoryData> _inventoryFuture;
  late final List<String> _allowed;
  late String _branchId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final profile = StaffSession.instance.profile;
    final own = profile?.branchId;
    final isOwner = profile?.isOwner == true;
    if (!isOwner && own != null && _branchNames.containsKey(own)) {
      _allowed = [own];
    } else {
      _allowed = _branchNames.keys.toList(growable: false);
    }
    _branchId = _allowed.first;
    _load();
  }

  void _load() {
    _productsFuture = FirestoreService().getProducts();
    _inventoryFuture = _loadBranchInventory();
  }

  Future<_BranchInventoryData> _loadBranchInventory() async {
    final branchIds = _branchNames.keys.toList(growable: false);
    final quantitiesFuture = BranchInventoryStore().loadAllQuantities();
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

  Future<void> _refresh() async {
    setState(_load);
    try {
      await Future.wait([_productsFuture, _inventoryFuture]);
    } catch (error) {
      showAppMessage('تعذر تحديث بيانات المخزون: $error');
    }
  }

  static String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  static String _formatDate(DateTime? date) {
    if (date == null) return 'غير متاح';
    final l = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  Widget _branchPicker() {
    if (_allowed.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            _branchNames[_branchId] ?? _branchId,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
        ),
      );
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final id in _allowed)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(_branchNames[id] ?? id),
                selected: _branchId == id,
                onSelected: (_) => setState(() => _branchId = id),
                showCheckmark: false,
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.surface,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: _branchId == id ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
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
          title: const Text('مخزون الفرع'),
          actions: [IconButton(tooltip: 'تحديث المخزون', onPressed: _refresh, icon: const Icon(Icons.refresh))],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  style: TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: AppColors.textFaint),
                    hintText: 'ابحث باسم المنتج أو رمزه',
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              _branchPicker(),
              Expanded(
                child: FutureBuilder<List<ProductModel>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppColors.accent));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('تعذر تحميل المنتجات أو ليس لديك صلاحية القراءة'));
                    }
                    return FutureBuilder<_BranchInventoryData>(
                      future: _inventoryFuture,
                      builder: (context, inventorySnapshot) {
                        if (inventorySnapshot.hasError) {
                          return const Center(child: Text('تعذر قراءة كميات الفروع؛ تحقق من صلاحيات الموظف'));
                        }
                        if (!inventorySnapshot.hasData) {
                          return Center(child: CircularProgressIndicator(color: AppColors.accent));
                        }
                        final inventory = inventorySnapshot.data!;
                        final branchQuantities = inventory.quantities[_branchId] ?? const <String, num>{};
                        final q = normalizeName(_query).toLowerCase();
                        final items =
                            (snapshot.data ?? const <ProductModel>[])
                                .where((p) => branchQuantities.containsKey(p.id))
                                .where(
                                  (p) =>
                                      q.isEmpty ||
                                      normalizeName(p.name).toLowerCase().contains(q) ||
                                      p.id.toLowerCase().contains(q),
                                )
                                .toList(growable: false)
                              ..sort((a, b) => a.name.compareTo(b.name));
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  '${items.length} مادة • آخر رفع: ${_formatDate(inventory.lastUploads[_branchId])}',
                                  style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                                ),
                              ),
                            ),
                            Expanded(
                              child: items.isEmpty
                                  ? Center(
                                      child: Text(
                                        'لا توجد كميات مسجلة لهذا الفرع',
                                        style: TextStyle(color: AppColors.textFaint),
                                      ),
                                    )
                                  : ListView.separated(
                                      addAutomaticKeepAlives: false,
                                      itemCount: items.length,
                                      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
                                      itemBuilder: (context, index) {
                                        final product = items[index];
                                        final qty = branchQuantities[product.id]!;
                                        final color = qty <= 0
                                            ? _kRed
                                            : qty <= 5
                                            ? _kOrange
                                            : AppColors.text;
                                        return ListTile(
                                          title: Text(product.name, style: TextStyle(color: AppColors.text)),
                                          subtitle: Text(
                                            product.id,
                                            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                                          ),
                                          trailing: Text(
                                            '${_fmt(qty)} ${product.unit}'.trim(),
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
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
