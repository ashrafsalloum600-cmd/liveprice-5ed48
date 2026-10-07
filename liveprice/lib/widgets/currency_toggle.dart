import 'package:flutter/material.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/theme/app_colors.dart';

class CurrencyToggle extends StatelessWidget {
  const CurrencyToggle({super.key});

  static const double _cell = 64;
  static const double _h = 40;
  static const double _pad = 4;
  static const Duration _d = Duration(milliseconds: 250);

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
            onTap: () => Pricing.instance.setDisplay(usd ? 'SYP' : 'USD'),
            child: AnimatedContainer(
              duration: _d,
              curve: Curves.easeOutCubic,
              width: _cell * 2 + _pad * 2,
              height: _h,
              padding: const EdgeInsets.all(_pad),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: _d,
                    curve: Curves.easeOutCubic,
                    alignment: usd ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: _cell,
                      height: _h - _pad * 2,
                      decoration: BoxDecoration(
                        color: usd ? AppColors.accent : AppColors.surface,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                  Row(children: [_label('ل.س', !usd, usd), _label('\$ دولار', usd, usd)]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text, bool selected, bool usd) {
    return SizedBox(
      width: _cell,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: _d,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.background : AppColors.mutedText,
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
