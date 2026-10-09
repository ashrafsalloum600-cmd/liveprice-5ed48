import 'package:flutter/material.dart';

import '../models/nav_item_data.dart';
import '../theme/app_colors.dart';

class PillNavBar extends StatelessWidget {
  final List<NavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Set<int> badgeIndices;

  const PillNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.badgeIndices = const {},
  });

  static const Duration _duration = Duration(milliseconds: 350);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double labelSpacing = constraints.maxWidth < 520 ? 4 : 10;

          return Stack(
            children: [
              Row(
                children: [
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      flex: i == currentIndex ? 4 : 1,
                      child: _NavButton(
                        data: items[i],
                        selected: i == currentIndex,
                        labelSpacing: labelSpacing,
                        duration: _duration,
                        curve: _curve,
                        showBadge: badgeIndices.contains(i),
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItemData data;
  final bool selected;
  final double labelSpacing;
  final Duration duration;
  final Curve curve;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavButton({
    required this.data,
    required this.selected,
    required this.labelSpacing,
    required this.duration,
    required this.curve,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Center(
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            padding: selected ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : EdgeInsets.zero,
            decoration: selected
                ? BoxDecoration(
                    color: AppColors.surfaceHigh,
                    border: Border.all(color: AppColors.border, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        selected ? data.activeIcon : data.icon,
                        key: ValueKey<bool>(selected),
                        size: 28,
                        color: AppColors.text,
                      ),
                    ),
                    if (showBadge)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: selected ? labelSpacing : 0),
                AnimatedSize(
                  duration: duration,
                  curve: curve,
                  alignment: AlignmentDirectional.centerStart,
                  child: selected
                      ? TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 400),
                          builder: (context, value, child) => Opacity(opacity: value, child: child),
                          child: Text(
                            data.label,
                            maxLines: 1,
                            style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600),
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
