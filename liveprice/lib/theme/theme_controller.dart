import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// يحفظ اختيار الثيم. أول تشغيل: يتبع نظام الجهاز.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();
  static const _key = 'theme_dark';

  bool _dark = true;
  bool get isDark => _dark;

  Future<void> init() async {
    var dark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    try {
      final saved = (await SharedPreferences.getInstance()).getBool(_key);
      if (saved != null) dark = saved;
    } catch (_) {}
    _apply(dark);
  }

  void _apply(bool dark) {
    _dark = dark;
    AppColors.current = dark ? AppPalette.dark : AppPalette.light;
  }

  Future<void> toggle() async {
    _apply(!_dark);
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool(_key, _dark);
    } catch (_) {}
  }
}

/// يعيد بناء الشاشة بالكامل عند تغيير الثيم حتى لا تبقى ألوان قديمة.
class ThemeScope extends StatelessWidget {
  const ThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ThemeController.instance,
    builder: (context, _) => KeyedSubtree(key: ValueKey<bool>(ThemeController.instance.isDark), child: child),
  );
}
