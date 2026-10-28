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
      final res = await http
          .get(Uri.parse('https://api.exchangerate.fun/latest?base=USD'))
          .timeout(const Duration(seconds: 10));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final rates = (json['rates'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
      if (!mounted) return;
      setState(() {
        _rates = rates;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الأسعار';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _fetchRates,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _error != null
              ? Center(
                  child: Text(_error!, style: TextStyle(color: AppColors.textFaint)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'أسعار العملات',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SyrianPoundHeader(rate: _rates!['SYP']),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _others.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
            child: Text(
              'SYP',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.text),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الليرة السورية',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDim),
                ),
                const SizedBox(height: 4),
                Text(
                  rate != null ? '${rate!.toStringAsFixed(2)} ل.س' : '—',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                Text('مقابل 1 دولار أمريكي', style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
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
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            code,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.textFaint),
          ),
          Text(
            rate != null ? rate!.toStringAsFixed(3) : '—',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
