import 'package:flutter/material.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/widgets/currency_toggle.dart';

class ProductsGrid extends StatefulWidget {
  final String searchQuery;
  const ProductsGrid({super.key, this.searchQuery = ''});

  @override
  State<ProductsGrid> createState() => _ProductsGridState();
}

class _ProductsGridState extends State<ProductsGrid> {
  static List<ProductModel>? _cache;
  late final Future<List<ProductModel>> _future;
  final Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _future = _cache != null ? Future.value(_cache!) : FirestoreService().getProducts().then((list) => _cache = list);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
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
                  return ProductCard(
                    product: p,
                    isFavorite: _favoriteIds.contains(p.id),
                    onFavoriteToggle: () => setState(() {
                      if (!_favoriteIds.remove(p.id)) _favoriteIds.add(p.id);
                    }),
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

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const ProductCard({super.key, required this.product, required this.isFavorite, required this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(24), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF2F2F2),
                    child: product.imageUrl.isEmpty
                        ? const Icon(Icons.image_outlined, size: 32, color: Colors.black26)
                        : Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined, size: 32, color: Colors.black26),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onFavoriteToggle,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: Colors.white.withAlpha(230), shape: BoxShape.circle),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            key: ValueKey(isFavorite),
                            size: 17,
                            color: isFavorite ? Colors.redAccent : Colors.black45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 32,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: AnimatedBuilder(
                      animation: Pricing.instance,
                      builder: (context, _) => Text(
                        Pricing.instance.format(product),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 14,
                    child: Text(
                      product.unit.isEmpty ? '' : '/ ${product.unit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
