import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final double price;
  final String unit;
  final String category;
  final String imageUrl;
  final String currency;
  final Map<String, num?> branchQuantities;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.category,
    required this.imageUrl,
    required this.currency,
    this.branchQuantities = const {},
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawCurrency = (data['currency'] as String?)?.trim().toUpperCase();
    final currency = rawCurrency == 'USD' || rawCurrency == 'SYP' ? rawCurrency! : 'SYP';
    final branchQuantities = <String, num?>{};
    for (final branchId in const ['b1', 'b2', 'b3']) {
      final quantity = data['q_$branchId'];
      if (quantity is num) branchQuantities[branchId] = quantity;
    }

    return ProductModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] as String? ?? '',
      category: data['category'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      currency: currency,
      branchQuantities: branchQuantities,
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
    };
  }
}
