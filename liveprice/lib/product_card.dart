import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:liveprice/widgets/app_message.dart';
import 'package:liveprice/widgets/currency_toggle.dart';

const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kGreen = Color(0xFF30D158);
const _kGray = Color(0xFF8E8E93);

class ProductsGrid extends StatefulWidget {
  final String searchQuery;
  const ProductsGrid({super.key, this.searchQuery = ''});

  @override
  State<ProductsGrid> createState() => _ProductsGridState();
}

class _ProductsGridState extends State<ProductsGrid> {
  static const _kFetchedAt = 'catalog_fetched_at';
  static const _kPricesAt = 'catalog_prices_at';

  static _CatalogData? _cache;
  late Future<_CatalogData> _future;
  bool _refreshing = false;
  final Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _future = _cache != null ? Future.value(_cache!) : _load();
  }

  // يعرض الكاش المحلي فوراً، ثم يحدّث بالخلفية عند الحاجة
  Future<_CatalogData> _load() async {
    final cached = await FirestoreService().getPublicProductsFromCache();
    if (cached.isNotEmpty) {
      final data = _CatalogData(cached);
      _cache = data;
      unawaited(_syncIfStale());
      return data;
    }
    return _fetchCatalog();
  }

  Future<_CatalogData> _fetchCatalog() async {
    final service = FirestoreService();
    final data = _CatalogData(await service.getPublicProductsFromServer());
    _cache = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kFetchedAt, DateTime.now().millisecondsSinceEpoch);
      final at = await service.getPricesUpdatedAtMs();
      if (at != null) await prefs.setInt(_kPricesAt, at);
    } catch (_) {}
    return data;
  }

  Future<void> _syncIfStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final age = DateTime.now().millisecondsSinceEpoch - (prefs.getInt(_kFetchedAt) ?? 0);
      final serverAt = await FirestoreService().getPricesUpdatedAtMs();
      final changed = serverAt != null && serverAt != prefs.getInt(_kPricesAt);
      if (age < 15 * 60 * 1000 && !changed) return;
      final data = await _fetchCatalog();
      if (mounted) setState(() => _future = Future.value(data));
    } catch (_) {}
  }

  Future<void> _refreshProducts() async {
    setState(() => _refreshing = true);
    try {
      _cache = null;
      final data = await _fetchCatalog();
      if (mounted) setState(() => _future = Future.value(data));
    } catch (error) {
      showAppMessage('تعذر تحديث المخزون: $error');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CatalogData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ بتحميل المنتجات'));
        }
        final q = widget.searchQuery.trim().toLowerCase();
        final all = snapshot.data!.products;
        final products = q.isEmpty
            ? all
            : all.where((p) => p.name.toLowerCase().contains(q) || p.id.toLowerCase().contains(q)).toList();
        if (products.isEmpty) {
          return Center(child: Text(q.isEmpty ? 'لا توجد منتجات حالياً' : 'لا توجد نتائج'));
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    const CurrencyToggle(),
                    const Spacer(),
                    IconButton(
                      tooltip: 'تحديث الأسعار والمخزون',
                      onPressed: _refreshing ? null : _refreshProducts,
                      icon: _refreshing
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 24 + MediaQuery.of(context).padding.bottom),
              sliver: SliverGrid.builder(
                addAutomaticKeepAlives: false,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.55,
                ),
                itemCount: products.length,
                itemBuilder: (context, i) {
                  final p = products[i];
                  return ProductCard(
                    key: ValueKey(p.id),
                    product: p,
                    isFavorite: _favoriteIds.contains(p.id),
                    onFavoriteToggle: () {
                      setState(() {
                        if (!_favoriteIds.remove(p.id)) _favoriteIds.add(p.id);
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CatalogData {
  const _CatalogData(this.products);

  final List<ProductModel> products;
}

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const ProductCard({super.key, required this.product, required this.isFavorite, required this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final stockLabel = switch (p.stock) {
      'out' => 'نفد',
      'limited' => 'كمية محدودة',
      'available' => 'متوفر',
      'incomplete' => 'بيانات جزئية',
      _ => null,
    };
    final stockColor = switch (p.stock) {
      'out' => _kRed,
      'limited' => _kOrange,
      'available' => _kGreen,
      'incomplete' => _kGray,
      _ => null,
    };
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: AppColors.surfaceHigh,
                        child: p.imageUrl.isEmpty
                            ? const Icon(Icons.image_outlined, size: 32, color: AppColors.textFaint)
                            : Image.network(
                                p.imageUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 300,
                                gaplessPlayback: true,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                    ),
                                  );
                                },
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.image_outlined, size: 32, color: AppColors.textFaint),
                              ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _HeartButton(isFavorite: isFavorite, onTap: onFavoriteToggle),
                      ),
                      if (stockLabel != null && stockColor != null)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 112, minHeight: 22),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.bg.withAlpha(220),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stockLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: stockColor, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 30,
                      child: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: AnimatedBuilder(
                        animation: Pricing.instance,
                        builder: (context, _) => Text(
                          Pricing.instance.format(p),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 13,
                      child: Text(
                        p.unit.isEmpty ? '' : '/ ${p.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textFaint),
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

class _HeartButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  const _HeartButton({required this.isFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: AppColors.bg.withAlpha(200), shape: BoxShape.circle),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 17,
          color: isFavorite ? _kRed : AppColors.textDim,
        ),
      ),
    );
  }
}
