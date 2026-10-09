import 'dart:async';

import 'package:flutter/material.dart';

class FlippingHeaderBar extends StatefulWidget {
  final double exchangeRate;
  final String lastUpdatedText;
  final bool isOnline;

  const FlippingHeaderBar({Key? key, required this.exchangeRate, required this.lastUpdatedText, this.isOnline = true})
    : super(key: key);

  @override
  State<FlippingHeaderBar> createState() => _FlippingHeaderBarState();
}

class _FlippingHeaderBarState extends State<FlippingHeaderBar> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    // إظهار سعر الصرف لمدة 5 ثوانٍ، والتحديث لمدة 3 ثوانٍ
    final duration = _currentIndex == 0 ? const Duration(seconds: 5) : const Duration(seconds: 3);

    _timer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _currentIndex = _currentIndex == 0 ? 1 : 0;
        });
        _startTimer(); // إعادة تشغيل المؤقت بالتناوب
      }
    });
  }

  void _toggleManually() {
    setState(() {
      _currentIndex = _currentIndex == 0 ? 1 : 0;
    });
    _startTimer(); // إعادة ضبط التوقيت عند النقر اليدوي
  }

  @override
  void dispose() {
    _timer?.cancel(); // إغلاق المؤقت لمنع تسريب الذاكرة
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleManually,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50), // رمادي فحمي راقي
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            // حركة الانزلاق العمودي مع الاختفاء والظهور الناعم
            final inAnimation = Tween<Offset>(begin: const Offset(0.0, 0.6), end: Offset.zero).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: inAnimation, child: child),
            );
          },
          child: _currentIndex == 0 ? _buildExchangeRateCard() : _buildSyncStatusCard(),
        ),
      ),
    );
  }

  // الوجه الأول: سعر الصرف
  Widget _buildExchangeRateCard() {
    return Row(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(
              Icons.currency_exchange_rounded,
              color: Color(0xFFD4AF37), // ذهبي هادئ
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              "سعر الصرف المعتمد:",
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          "${widget.exchangeRate.toStringAsFixed(0)} ل.س / \$",
          style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // الوجه الثاني: حالة الاتصال وآخر تحديث
  Widget _buildSyncStatusCard() {
    return Row(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              widget.isOnline ? Icons.check_circle_outline_rounded : Icons.cloud_off_rounded,
              color: widget.isOnline
                  ? const Color(0xFF4ADE80) // أخضر هادئ
                  : const Color(0xFFF87171), // أحمر
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              "آخر تحديث للأسعار:",
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          widget.lastUpdatedText,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}
