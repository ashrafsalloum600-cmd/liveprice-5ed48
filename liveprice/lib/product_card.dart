import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:liveprice/theme/spring.dart';
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
  static const _kFavorites = 'favorite_ids';
  final Set<String> _favoriteIds = {};

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kFavorites);
      if (saved != null && mounted) {
        setState(() {
          _favoriteIds.addAll(saved);
        });
      }
    } catch (_) {}
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favoriteIds.remove(id)) _favoriteIds.add(id);
    });
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setStringList(_kFavorites, _favoriteIds.toList()))
        .catchError((_) => false);
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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
      if (mounted) {
        setState(() {
          _future = Future.value(data);
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshProducts() async {
    setState(() => _refreshing = true);
    try {
      _cache = null;
      final data = await _fetchCatalog();
      if (mounted) {
        setState(() {
          _future = Future.value(data);
        });
      }
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
      initialData: _cache,
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const _SkeletonGrid();
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
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            CupertinoSliverRefreshControl(
              refreshTriggerPullDistance: 90,
              refreshIndicatorExtent: 56,
              onRefresh: _refreshProducts,
              builder: (context, mode, pulled, trigger, extent) {
                final text = switch (mode) {
                  RefreshIndicatorMode.armed => 'اترك للتحديث',
                  RefreshIndicatorMode.refresh => 'جارٍ تحديث الأسعار...',
                  RefreshIndicatorMode.done => 'تم التحديث',
                  _ => 'اسحب للأسفل لتحديث الأسعار',
                };
                return ClipRect(
                  child: Opacity(
                    opacity: (pulled / trigger).clamp(0.0, 1.0),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mode == RefreshIndicatorMode.refresh)
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            )
                          else
                            Icon(
                              mode == RefreshIndicatorMode.armed
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 16,
                              color: AppColors.textFaint,
                            ),
                          const SizedBox(width: 8),
                          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textFaint)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
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
                    onFavoriteToggle: () => _toggleFavorite(p.id),
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
      child: Pressable(
        scale: 0.97,
        onTap: () => _openProduct(context, p, isFavorite, onFavoriteToggle),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: ShapeDecoration(
            color: AppColors.surface,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: const BorderSide(color: AppColors.border, width: 0.5),
            ),
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
                        Hero(
                          tag: 'product-image-${p.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
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
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
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
      ),
    );
  }
}

class _HeartButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  const _HeartButton({required this.isFavorite, required this.onTap});

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton> {
  bool _down = false;
  bool _pop = false;

  void _tap() {
    HapticFeedback.selectionClick();
    widget.onTap();
    setState(() => _pop = true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _pop = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: _tap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedScale(
          scale: _down ? 0.85 : (_pop ? 1.25 : 1),
          duration: Duration(milliseconds: _down ? 60 : 170),
          curve: Curves.easeOutBack,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: AppColors.bg.withAlpha(200), shape: BoxShape.circle),
            child: Icon(
              widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 17,
              color: widget.isFavorite ? _kRed : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

// هيكل تحميل ثابت (بدون حركة) يطابق شكل الشبكة والبطاقات
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 56),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.55,
            ),
            itemCount: 12,
            itemBuilder: (_, _) => const _SkeletonCard(),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  static Widget _bar(double factor, double height) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: factor,
    child: Container(
      height: height,
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(5)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: ShapeDecoration(
          color: AppColors.surface,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: const BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            _bar(0.85, 10),
            const SizedBox(height: 6),
            _bar(0.55, 10),
            const SizedBox(height: 8),
            _bar(0.45, 14),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String? _stockLabelOf(String? s) => switch (s) {
  'out' => 'نفد',
  'limited' => 'كمية محدودة',
  'available' => 'متوفر',
  'incomplete' => 'بيانات جزئية',
  _ => null,
};

Color _stockColorOf(String? s) => switch (s) {
  'out' => _kRed,
  'limited' => _kOrange,
  'available' => _kGreen,
  _ => _kGray,
};

void _openProduct(BuildContext context, ProductModel p, bool isFavorite, VoidCallback onToggle) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => ProductDetailsPage(product: p, isFavorite: isFavorite, onFavoriteToggle: onToggle),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late bool _fav = widget.isFavorite;

  void _toggle() {
    HapticFeedback.selectionClick();
    widget.onFavoriteToggle();
    setState(() => _fav = !_fav);
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {Color? color}) => Pressable(
    onTap: onTap,
    scale: 0.88,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: AppColors.surface.withAlpha(235), shape: BoxShape.circle),
      child: Icon(icon, size: 22, color: color ?? AppColors.text),
    ),
  );

  Widget _infoRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textFaint)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.text),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final label = _stockLabelOf(p.stock);
    final color = _stockColorOf(p.stock);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: [
                Hero(
                  tag: 'product-image-${p.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                      child: Container(
                        height: 340 + top * 0.5,
                        width: double.infinity,
                        color: AppColors.surfaceHigh,
                        alignment: Alignment.center,
                        child: p.imageUrl.isEmpty
                            ? const Icon(Icons.image_outlined, size: 64, color: AppColors.textFaint)
                            : Image.network(
                                p.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                cacheWidth: 900,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.image_outlined, size: 64, color: AppColors.textFaint),
                              ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AnimatedBuilder(
                            animation: Pricing.instance,
                            builder: (context, _) => Text(
                              Pricing.instance.format(p),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (p.unit.isNotEmpty)
                            Text('/ ${p.unit}', style: const TextStyle(fontSize: 15, color: AppColors.textFaint)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (label != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: ShapeDecoration(
                              color: color.withAlpha(30),
                              shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: ShapeDecoration(
                          color: AppColors.surface,
                          shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: Column(
                          children: [
                            _infoRow('رمز المادة', p.id),
                            const Divider(),
                            _infoRow('الواحدة', p.unit.isEmpty ? '—' : p.unit),
                            const Divider(),
                            _infoRow('التوفر', label ?? '—', valueColor: label == null ? null : color),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'السعر يتغير تلقائياً حسب سعر الصرف المعتمد.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: top + 8,
              right: 14,
              child: _circleButton(Icons.arrow_forward_rounded, () => Navigator.of(context).maybePop()),
            ),
            Positioned(
              top: top + 8,
              left: 14,
              child: _circleButton(
                _fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                _toggle,
                color: _fav ? _kRed : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
