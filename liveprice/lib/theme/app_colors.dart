import 'package:flutter/material.dart';

/// لوحة ألوان كاملة (ليلي أو نهاري). غيّر القيم من هنا فقط.
class AppPalette {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceTop,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.accent,
  });

  final Color bg, surface, surfaceTop, surfaceHigh, border, text, textDim, textFaint, accent;

  static const dark = AppPalette(
    bg: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceTop: Color(0xFF1C1C1E),
    surfaceHigh: Color(0xFF2C2C2E),
    border: Color(0xFF38383A),
    text: Color(0xFFFFFFFF),
    textDim: Color(0xFFAEAEB2),
    textFaint: Color(0xFF8E8E93),
    accent: Color(0xFF0A84FF),
  );

  static const light = AppPalette(
    bg: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceTop: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE5E5EA),
    border: Color(0xFFD1D1D6),
    text: Color(0xFF000000),
    textDim: Color(0xFF6C6C70),
    textFaint: Color(0xFF8E8E93),
    accent: Color(0xFF007AFF),
  );
}

/// نفس الأسماء القديمة، لكن قيمها تتبع الثيم الحالي (يضبطها ThemeController).
class AppColors {
  static AppPalette current = AppPalette.dark;

  static Color get bg => current.bg;
  static Color get surface => current.surface;
  static Color get surfaceTop => current.surfaceTop;
  static Color get surfaceHigh => current.surfaceHigh;
  static Color get border => current.border;
  static Color get text => current.text;
  static Color get textDim => current.textDim;
  static Color get textFaint => current.textFaint;
  static Color get accent => current.accent;
}
