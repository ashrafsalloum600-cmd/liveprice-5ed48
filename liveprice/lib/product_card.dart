import 'package:flutter/material.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:liveprice/widgets/currency_toggle.dart';

class ProductsGrid extends StatefulWidget {
  final String searchQuery;
  const ProductsGrid({super.key, this.searchQuery = ''});

  @override
  State<ProductsGrid> createState() => _ProductsGridState();
}

class _ProductsGridState extends State<ProductsGrid> with SingleTickerProviderStateMixin {
  static const int _staggerCount = 12;
  static const int _staggerMs = 40;
  static const int _itemMs = 320;
  static const int _totalMs = _staggerCount * _staggerMs + _itemMs;

  static List<ProductModel>? _cache;
  late final Future<List<ProductModel>> _future;
  late final AnimationController _stagger = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  late final List<Animation<double>> _anims = List.generate(
    _staggerCount,
    (i) => CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * _staggerMs / _totalMs, (i * _staggerMs + _itemMs) / _totalMs, curve: Curves.easeOut),
    ),
  );
  final Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _future = _cache != null ? Future.value(_cache!) : FirestoreService().getProducts().then((list) => _cache = list);
    _future.then((_) {
      if (mounted) _stagger.forward();
    });
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ بتحميل المنتجات'));
        }
        final q = widget.searchQuery.trim().toLowerCase();
        final all = snapshot.data ?? [];
        final products = q.isEmpty
            ? all
            : all.where((p) => p.name.toLowerCase().contains(q) || p.id.toLowerCase().contains(q)).toList();
        if (products.isEmpty) {
          return Center(child: Text(q.isEmpty ? 'لا توجد منتجات حالياً' : 'لا توجد نتائج'));
        }
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Align(alignment: Alignment.centerRight, child: CurrencyToggle()),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 24 + MediaQuery.of(context).padding.bottom),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.55,
                ),
                itemCount: products.length,
                itemBuilder: (context, i) {
                  final p = products[i];
                  Widget card = ProductCard(
                    product: p,
                    isFavorite: _favoriteIds.contains(p.id),
                    onFavoriteToggle: () => setState(() {
                      if (!_favoriteIds.remove(p.id)) _favoriteIds.add(p.id);
                    }),
                  );
                  if (i < _staggerCount) {
                    final a = _anims[i];
                    card = FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(a),
                        child: card,
                      ),
                    );
                  }
                  return card;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const ProductCard({super.key, required this.product, required this.isFavorite, required this.onFavoriteToggle});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceTop, AppColors.surface],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(_hover ? 110 : 70),
              blurRadius: _hover ? 20 : 14,
              offset: Offset(0, _hover ? 10 : 6),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.image_outlined, size: 32, color: AppColors.textFaint),
                              ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _HeartButton(isFavorite: widget.isFavorite, onTap: widget.onFavoriteToggle),
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
                          fontWeight: FontWeight.w700,
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
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.accent),
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

class _HeartButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  const _HeartButton({required this.isFavorite, required this.onTap});

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.85 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: AppColors.bg.withAlpha(200), shape: BoxShape.circle),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(widget.isFavorite),
              size: 17,
              color: widget.isFavorite ? Colors.redAccent : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}
