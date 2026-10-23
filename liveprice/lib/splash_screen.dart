import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:liveprice/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final Widget next;

  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _maxWait = Duration(milliseconds: 1200);
  bool _went = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    // احتياط: إذا تأخر تحميل الأنيميشن أو فشل، ندخل التطبيق خلال 1.5 ثانية
    _fallback = Timer(const Duration(milliseconds: 1500), _go);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  void _go() {
    if (_went || !mounted) return;
    _went = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Lottie.asset(
          'assets/images/welcompic/welcompic1.json',
          width: 200,
          fit: BoxFit.contain,
          repeat: false,
          onLoaded: (composition) {
            final wait = composition.duration < _maxWait ? composition.duration : _maxWait;
            Timer(wait, _go);
          },
          errorBuilder: (_, _, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _go());
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
