import 'dart:async';

import 'package:flutter/material.dart' hide SnackBar, ScaffoldMessenger;
import 'package:liveprice/services/fcm_service.dart';
import 'package:liveprice/theme/app_colors.dart';

OverlayEntry? _toast;
Timer? _toastTimer;

void _hideToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _toast?.remove();
  _toast = null;
}

bool _looksLikeError(String text) {
  final s = text.toLowerCase();
  return s.contains('تعذر') || s.contains('فشل') || s.contains('خطأ') || s.contains('error');
}

/// رسالة موحّدة بدون الحاجة لـ context.
/// خطأ: نافذة بالوسط بزر "موافق". غير ذلك: بطاقة علوية تختفي بالضغط أو بعد 3 ثوان.
void showAppMessage(Object? message, {bool? important}) {
  final text = '$message';
  final nav = navigatorKey.currentState;
  final context = navigatorKey.currentContext;
  if (nav == null || context == null) return;

  if (important ?? _looksLikeError(text)) {
    _hideToast();
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text(text, style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.4)),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('موافق'))],
        ),
      ),
    );
    return;
  }

  final overlay = nav.overlay;
  if (overlay == null) return;
  _hideToast();
  _toast = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.of(ctx).padding.top + 12,
      left: 16,
      right: 16,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _hideToast,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(text, style: const TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.3)),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(_toast!);
  _toastTimer = Timer(const Duration(seconds: 3), _hideToast);
}

// ---- بدائل خفيفة: أي SnackBar / ScaffoldMessenger قديم يتحوّل تلقائياً إلى showAppMessage ----

class SnackBar {
  const SnackBar({
    required this.content,
    this.duration,
    this.backgroundColor,
    this.action,
    this.behavior,
    this.margin,
    this.padding,
    this.shape,
    this.elevation,
    this.width,
    this.dismissDirection,
    this.onVisible,
    this.clipBehavior,
    this.showCloseIcon,
    this.closeIconColor,
  });

  final Widget content;
  final Object? duration,
      backgroundColor,
      action,
      behavior,
      margin,
      padding,
      shape,
      elevation,
      width,
      dismissDirection,
      onVisible,
      clipBehavior,
      showCloseIcon,
      closeIconColor;
}

class ScaffoldMessenger {
  static _AppMessenger of(BuildContext context) => const _AppMessenger();
  static _AppMessenger? maybeOf(BuildContext context) => const _AppMessenger();
}

class _AppMessenger {
  const _AppMessenger();

  void showSnackBar(SnackBar bar) {
    final c = bar.content;
    final text = c is Text ? (c.data ?? c.textSpan?.toPlainText() ?? '') : '';
    if (text.isNotEmpty) showAppMessage(text);
  }

  void hideCurrentSnackBar() {}
  void removeCurrentSnackBar() {}
  void clearSnackBars() {}
}
