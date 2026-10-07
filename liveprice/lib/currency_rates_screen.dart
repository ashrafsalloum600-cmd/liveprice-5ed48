import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:http/http.dart' as http;

class CurrencyRatesScreen extends StatefulWidget {
  const CurrencyRatesScreen({super.key});

  @override
  State<CurrencyRatesScreen> createState() => _CurrencyRatesScreenState();
}

class _CurrencyMeta {
  final String code;
  final String label;
  const _CurrencyMeta(this.code, this.label);
}

class _CurrencyRatesScreenState extends State<CurrencyRatesScreen> {
  Map<String, double>? _rates;
  bool _loading = true;
  String? _error;

  static const List<_CurrencyMeta> _others = [
    _CurrencyMeta('USD', 'دولار أمريكي'),
    _CurrencyMeta('EUR', 'يورو'),
    _CurrencyMeta('TRY', 'ليرة تركية'),
    _CurrencyMeta('SAR', 'ريال سعودي'),
    _CurrencyMeta('AED', 'درهم إماراتي'),
    _CurrencyMeta('JOD', 'دينار أردني'),
    _CurrencyMeta('EGP', 'جنيه مصري'),
    _CurrencyMeta('GBP', 'جنيه إسترليني'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse('https://api.exchangerate.fun/latest?base=USD'));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final rates = (json['rates'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
      setState(() {
        _rates = rates;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'تعذر تحميل الأسعار';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchRates,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.text))
              : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: AppColors.mutedText)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'أسعار العملات',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SyrianPoundHeader(rate: _rates!['SYP']),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _others.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, i) {
                        final c = _others[i];
                        return _CurrencySquare(code: c.code, label: c.label, rate: _rates![c.code]);
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SyrianPoundHeader extends StatelessWidget {
  final double? rate;
  const _SyrianPoundHeader({required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(18)),
            child: const Text('SYP', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الليرة السورية',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.mutedText),
                ),
                const SizedBox(height: 4),
                Text(
                  rate != null ? '${rate!.toStringAsFixed(2)} ل.س' : '—',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const Text('مقابل 1 دولار أمريكي', style: TextStyle(fontSize: 12, color: AppColors.mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencySquare extends StatelessWidget {
  final String code;
  final String label;
  final double? rate;

  const _CurrencySquare({required this.code, required this.label, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            code,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
          ),
          Text(
            rate != null ? rate!.toStringAsFixed(3) : '—',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
