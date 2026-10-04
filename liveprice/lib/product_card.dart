import 'package:flutter/material.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:liveprice/services/firestore_service.dart';
import 'package:liveprice/services/pricing.dart';

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
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
          itemExtent: 100,
          itemCount: products.length,
          itemBuilder: (context, i) {
            final p = products[i];
            return ProductRow(
              product: p,
              isFavorite: _favoriteIds.contains(p.id),
              onFavoriteToggle: () => setState(() {
                if (!_favoriteIds.remove(p.id)) _favoriteIds.add(p.id);
              }),
            );
          },
        );
      },
    );
  }
}

class ProductRow extends StatelessWidget {
  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const ProductRow({super.key, required this.product, required this.isFavorite, required this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(24), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 60,
                height: 60,
                color: const Color(0xFFF2F2F2),
                child: product.imageUrl.isEmpty
                    ? const Icon(Icons.image_outlined, color: Colors.black26)
                    : Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 180,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: Colors.black26),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: Pricing.instance,
                        builder: (context, _) => Text(
                          Pricing.instance.format(product),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black),
                        ),
                      ),
                      if (product.unit.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '/ ${product.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.black45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onFavoriteToggle,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(isFavorite),
                    color: isFavorite ? Colors.redAccent : Colors.black38,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
