import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:liveprice/theme/spring.dart';
import 'package:liveprice/theme/theme_controller.dart';
import 'package:liveprice/theme/theme_icons.dart';
import 'package:liveprice/theme/theme_reveal.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final dark = ThemeController.instance.isDark;
        return Pressable(
          onTap: () {
            HapticFeedback.selectionClick();
            final box = context.findRenderObject() as RenderBox;
            final origin = box.localToGlobal(box.size.center(Offset.zero));
            ThemeReveal.revealKey.currentState?.toggle(origin);
          },
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: AppColors.surface,
              shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, a) => RotationTransition(
                turns: Tween<double>(begin: -0.25, end: 0).animate(a),
                child: ScaleTransition(scale: a, child: child),
              ),
              child: Icon(
                ThemeIcons.of(dark),
                key: ValueKey<bool>(dark),
                size: 22,
                color: dark ? AppColors.accent : const Color(0xFFFF9F0A),
              ),
            ),
          ),
        );
      },
    );
  }
}
