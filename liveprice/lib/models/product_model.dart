import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final double price;
  final String unit;
  final String category;
  final String imageUrl;
  final String currency;
  final String stock;
  final double? prevPrice;
  final DateTime? priceChangedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.category,
    required this.imageUrl,
    required this.currency,
    this.stock = '',
    this.prevPrice,
    this.priceChangedAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawCurrency = (data['currency'] as String?)?.trim().toUpperCase();
    final currency = rawCurrency == 'USD' || rawCurrency == 'SYP' ? rawCurrency! : 'SYP';
    final rawPriceChangedAt = data['priceChangedAt'];
    return ProductModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] as String? ?? '',
      category: data['category'] as String? ?? '',
      imageUrl: _readImageUrl(data),
      currency: currency,
      stock: _readStock(data),
      prevPrice: (data['prevPrice'] as num?)?.toDouble(),
      priceChangedAt: rawPriceChangedAt is Timestamp
          ? rawPriceChangedAt.toDate()
          : rawPriceChangedAt is DateTime
          ? rawPriceChangedAt
          : null,
    );
  }

  ProductModel copyWith({double? price, String? stock, String? imageUrl}) {
    return ProductModel(
      id: id,
      name: name,
      price: price ?? this.price,
      unit: unit,
      category: category,
      imageUrl: imageUrl ?? this.imageUrl,
      currency: currency,
      stock: stock ?? this.stock,
      prevPrice: prevPrice,
      priceChangedAt: priceChangedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'unit': unit,
      'category': category,
      'imageUrl': imageUrl,
      'currency': currency,
      if (prevPrice != null) 'prevPrice': prevPrice,
      if (priceChangedAt != null) 'priceChangedAt': Timestamp.fromDate(priceChangedAt!),
    };
  }

  static String _readImageUrl(Map<String, dynamic> data) {
    for (final key in ['imageUrl', 'image', 'photoUrl', 'photo']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String _readStock(Map<String, dynamic> data) {
    final value = data['stock'] ?? data['status'];
    return value is String ? value : '';
  }
}
