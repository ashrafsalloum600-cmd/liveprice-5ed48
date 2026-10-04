import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liveprice/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Pricing extends ChangeNotifier {
  Pricing._();
  static final Pricing instance = Pricing._();

  double? usdToSyp;
  double? previousUsdToSyp;
  String displayCurrency = 'SYP'; // 'SYP' | 'USD'
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    Future<void>(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('displayCurrency');
        displayCurrency = saved == 'USD' ? 'USD' : 'SYP';
        notifyListeners();
      } catch (_) {}
    });

    FirebaseFirestore.instance.doc('settings/pricing').snapshots().listen((doc) {
      final incoming = (doc.data()?['usdToSyp'] as num?)?.toDouble();
      if (incoming != null && incoming != usdToSyp) {
        previousUsdToSyp = usdToSyp;
      }
      usdToSyp = incoming;
      notifyListeners();
    });
  }

  void setDisplay(String currency) {
    try {
      if (currency != 'USD' && currency != 'SYP') return;
      displayCurrency = currency;
      Future(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('displayCurrency', currency);
        } catch (_) {}
      });
      notifyListeners();
    } catch (_) {}
  }

  String format(ProductModel p) {
    if (p.currency == 'SYP') return '${_n(p.price)} ل.س';
    if (displayCurrency == 'SYP' && usdToSyp != null) {
      return '${_n(p.price * usdToSyp!)} ل.س';
    }
    return '\$${p.price.toStringAsFixed(2)}';
  }

  String _n(double v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
