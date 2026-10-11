import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liveprice/services/pricing.dart';

class CurrencyToggle extends StatefulWidget {
  const CurrencyToggle({super.key});

  @override
  State<CurrencyToggle> createState() => _CurrencyToggleState();
}

class _CurrencyToggleState extends State<CurrencyToggle> {
  static const double _cell = 64;
  static const double _h = 40;
  static const double _pad = 4;
  static const Duration _d = Duration(milliseconds: 380);
  static const Curve _spring = Cubic(0.2, 0.9, 0.25, 1.06);
  static const Color _green = Color(0xFF34C759);

  bool _pressed = false;

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
          final sypSelected = !usd;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () => _set(!usd),
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx > 1.5) _set(true);
              if (d.delta.dx < -1.5) _set(false);
            },
            onHorizontalDragEnd: (_) => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: _d,
              curve: Curves.easeOutCubic,
              width: _cell * 2 + _pad * 2,
              height: _h,
              padding: const EdgeInsets.all(_pad),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: usd
                      ? const [Color(0xFF4FD36C), Color(0xFF2FB84F)]
                      : const [Color(0xFFFFFFFF), Color(0xFFE9EDF4)],
                ),
                border: Border.all(color: Colors.white.withAlpha(usd ? 90 : 160)),
                boxShadow: [
                  BoxShadow(
                    color: usd ? _green.withAlpha(110) : Colors.black.withAlpha(60),
                    blurRadius: usd ? 18 : 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.55],
                  colors: [Colors.white.withAlpha(60), Colors.white.withAlpha(0)],
                ),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: _d,
                    curve: _spring,
                    alignment: usd ? Alignment.centerRight : Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      width: _cell + (_pressed ? 10 : 0),
                      height: _h - _pad * 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0xFFF1F3F8)],
                        ),
                        border: Border.all(color: Colors.black.withAlpha(25), width: 0.6),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                    ),
                  ),
                  Row(children: [_label('ل.س', sypSelected), _label('\$ دولار', usd)]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text, bool selected) {
    final color = selected ? const Color(0xFF1B1F2A) : const Color(0xFF7C8598);
    return SizedBox(
      width: _cell,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          child: Text(text),
        ),
      ),
    );
  }
}
