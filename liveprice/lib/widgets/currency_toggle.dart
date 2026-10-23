import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/theme/app_colors.dart';

class CurrencyToggle extends StatelessWidget {
  const CurrencyToggle({super.key});

  static const double _cell = 56;
  static const double _h = 36;
  static const double _pad = 3;
  static const Duration _d = Duration(milliseconds: 220);

  void _set(bool usd) {
    final target = usd ? 'USD' : 'SYP';
    if (Pricing.instance.displayCurrency == target) return;
    HapticFeedback.selectionClick();
    Pricing.instance.setDisplay(target);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedBuilder(
        animation: Pricing.instance,
        builder: (context, _) {
          final usd = Pricing.instance.displayCurrency == 'USD';
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _set(!usd),
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx > 1.5) _set(true);
              if (d.delta.dx < -1.5) _set(false);
            },
            child: Container(
              width: _cell * 2 + _pad * 2,
              height: _h,
              padding: const EdgeInsets.all(_pad),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: _d,
                    curve: Curves.easeOutCubic,
                    alignment: usd ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: _cell,
                      height: _h - _pad * 2,
                      decoration: BoxDecoration(color: const Color(0xFF636366), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _label('ل.س', !usd)),
                      Expanded(child: _label('\$ دولار', usd)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text, bool selected) {
    return Center(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.text : AppColors.textFaint,
        ),
      ),
    );
  }
}
