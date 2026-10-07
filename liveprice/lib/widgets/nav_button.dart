import 'package:flutter/material.dart';

import '../models/nav_item_data.dart';
import '../theme/app_colors.dart';

class NavButton extends StatelessWidget {
  final NavItemData data;
  final bool selected;
  final double width;
  final Duration duration;
  final Curve curve;
  final VoidCallback onTap;

  const NavButton({
    super.key,
    required this.data,
    required this.selected,
    required this.width,
    required this.duration,
    required this.curve,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        width: width,
        height: 56,
        alignment: Alignment.center,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Icon(
                    key: ValueKey<bool>(selected),
                    selected ? data.activeIcon : data.icon,
                    size: 28,
                    color: AppColors.text,
                  ),
                ),
                AnimatedSize(
                  duration: duration,
                  curve: curve,
                  alignment: AlignmentDirectional.centerStart,
                  child: selected
                      ? TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 400),
                          builder: (BuildContext context, double value, Widget? child) {
                            return Opacity(opacity: value, child: child);
                          },
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(start: 10),
                            child: Text(
                              data.label,
                              maxLines: 1,
                              style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
